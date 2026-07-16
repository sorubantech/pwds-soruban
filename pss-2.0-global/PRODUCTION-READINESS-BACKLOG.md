# PSS 2.0 — Production-Readiness Backlog & Gap Analysis

> **Generated:** 2026-07-14 · **Method:** multi-agent enterprise audit (PM · Architect · Full-Stack · UI/UX · QA · BA lenses) with adversarial verification. Every finding below was confirmed by an agent that read the cited source file(s).

> **Scope reviewed:** ~137 screens / ~18 modules across the .NET 8 (CQRS + GraphQL + EF Core) backend and Next.js/React frontend. **This document does not trust existing "Completed" status** — screens marked done were re-reviewed from a production perspective per the review mandate.

## Overall Verdict

### NO-GO for production

This system cannot ship until several classes of blocker are eliminated. First, cross-tenant data exposure is pervasive and reaches decrypted payment secrets and donor financial PII (#76, #43, #34, #79) with no framework-level defense (#57). Second, authentication is compromisable from the client and default-open on the server (#283, #68, #2, #86), while all cryptographic keys and DB credentials are committed to source control (#73, #70). Third, money paths contain fake-success placeholders and unverified financial inputs (#41, #39, #17, #52) that would corrupt the donation and refund ledger of an organization whose entire trust model depends on accurate donor accounting. Fourth, the absence of any backend test suite and any deploy-gating test step (#59, #58) means there is no regression safety net for the fixes these findings demand. Any one of the first three classes is independently release-blocking; together they make production deployment untenable.

## Executive Summary

**PSS 2.0 is an AI-built, multi-tenant NGO/nonprofit SaaS platform currently in developer testing, and this audit was conducted precisely because its "Completed" screen status could not be trusted.** A multi-agent review read the actual .NET 8 / GraphQL / EF Core backend and Next.js frontend source and adversarially verified every claim. The result is 335 confirmed findings — 87 Critical, 103 High, 111 Medium, 34 Low — concentrated in exactly the areas where a nonprofit handling donor money and donor PII cannot afford to fail: tenant isolation, authentication, secrets management, and financial integrity.

**The single most alarming pattern is systemic multi-tenant isolation failure.** Roughly forty findings show handlers that omit any `CompanyId` predicate, and there is no EF Core global query filter or any automated test as a safety net (#57). Any authenticated staffer in one tenant can read another tenant's donor financial PII and certificates (#43, #55), global donation records (#34), volunteer hour logs (#84), and — worst — retrieve another tenant's fully-decrypted payment-gateway API keys and webhook secrets by guessing an id (#76). Some list screens leak *all* tenants' data with no id-guessing at all (#79 organization bank accounts; #31 ambassador cash-collection totals). Public donor-facing pages resolve to whichever company sorts "first active" when the hostname isn't recognized (#46, #153–#155, #272).

**Authentication and session security are broken at the foundation.** The CQRS authorization pipeline is default-open: any request type lacking a `[CustomAuthorize]` attribute executes with zero auth checks (#68), and several sensitive operations have that attribute commented out (#35, #66, #285). Role assignment accepts an arbitrary `RoleId` — including SUPERADMIN — and arbitrary `CompanyId` with no server-side validation, a direct privilege-escalation and tenant-hijack primitive (#2). The frontend `authorize()` callback trusts client-supplied `userData` unconditionally, letting any browser mint a valid session (#283); the Member Portal "auth" is just a localStorage check (#86); brute-force lockout is written but never enforced (#177); and 2FA exists only as unwired fields (#6). Compounding this, all master keys, the JWT RSA private key, and live DB credentials are committed to source control in plaintext (#70, #73), and CORS is wildcard-origin with credentials enabled (#71).

**Financial integrity is undermined by fake-success placeholders in live money paths.** The refund flow never calls the gateway's `RefundAsync` — refunds are born "complete," bypass the entire approval chain, and mutate the donation ledger with no money actually moving (#41, #53, #264). The recurring-donation "Retry" action fabricates a successful charge (increments counts, stamps SUCCESS) without contacting any processor (#39). Manual donation entry trusts client-supplied exchange rate and base-currency amount with no server verification (#17), FX conversions are silently recorded at 1:1 on a rate miss (#36, #114), payment-webhook dedup has no unique index (making replay possible, #52), and public payment endpoints have no real reCAPTCHA or CSRF (#33). Alongside these, whole features present as working but are hollow: Scheduled Reports has no execution engine (#10, #63), the Custom Report Builder fabricates all output (#61), the main dashboard renders hardcoded numbers (#64), and accounting/social integrations mint fake tokens and stats (#181, #185).

Underneath the Criticals sits a broad substrate of lifecycle/state-machine gaps, missing concurrency tokens (last-write-wins everywhere, #117, #166), unbatched in-request exports, inconsistent error contracts, and — critically for a system whose status could not be trusted — essentially zero automated test coverage: no backend unit/integration tests at all (#59), ~1% Playwright coverage (#56), and no test step gating the deploy (#58).

## Findings at a Glance

**Total findings: 335**

| Priority | Count |
|---|---|
| Critical | 87 |
| High | 103 |
| Medium | 111 |
| Low | 34 |

### By module

| Module | Total | Critical | High | Medium | Low |
|---|---|---|---|---|---|
| Security & Access Control | 22 | 9 | 5 | 6 | 2 |
| Fundraising · Donations & Receipts | 21 | 9 | 9 | 3 | 0 |
| Administration / System Configuration | 22 | 6 | 5 | 8 | 3 |
| Settings & Configuration | 14 | 6 | 5 | 3 | 0 |
| Deployment · Config · Ops Readiness | 14 | 5 | 4 | 3 | 2 |
| QA & Testing Gaps | 11 | 5 | 5 | 1 | 0 |
| Organization · Events & Staff | 10 | 5 | 2 | 2 | 1 |
| Volunteer & Membership | 14 | 4 | 3 | 6 | 1 |
| Multi-Tenancy Isolation | 10 | 4 | 5 | 1 | 0 |
| Field Collection · Ambassador | 14 | 3 | 6 | 4 | 1 |
| Communication | 13 | 3 | 5 | 5 | 0 |
| UI/UX & Design-System Compliance | 12 | 3 | 2 | 3 | 4 |
| Error Handling · Logging · Monitoring | 11 | 3 | 6 | 2 | 0 |
| Data Consistency & Concurrency | 9 | 3 | 4 | 2 | 0 |
| Reports | 9 | 3 | 2 | 4 | 0 |
| Contacts / CRM | 15 | 2 | 5 | 4 | 4 |
| Background Services & Scheduled Jobs | 12 | 2 | 2 | 5 | 3 |
| Fundraising · Campaigns & Intake | 12 | 2 | 4 | 6 | 0 |
| Payments & Reconciliation | 12 | 2 | 4 | 6 | 0 |
| Root · Auth · Layout · Dashboards | 12 | 2 | 3 | 5 | 2 |
| API / GraphQL Contract | 8 | 2 | 3 | 2 | 1 |
| Currency / FX / Decimal / Timezone | 15 | 1 | 5 | 7 | 2 |
| Case Management | 12 | 1 | 2 | 7 | 2 |
| Prayer · Certificate · General Masters | 10 | 1 | 3 | 5 | 1 |
| Performance & Scalability | 8 | 1 | 1 | 4 | 2 |
| Grants | 9 | 0 | 3 | 4 | 2 |
| Payments & Financial Integrity | 4 | 0 | 0 | 3 | 1 |

## Production Blockers (must fix before release)

| # | ID | Blocker |
|---|---|---|
| 1 | #73 | JWT RSA private key, live Postgres credentials, and all master encryption keys are committed to source control in plaintext, enabling total system and data compromise. |
| 2 | #2 | User-role assignment accepts an arbitrary RoleId (including SUPERADMIN) and arbitrary CompanyId with no server-side validation — direct privilege escalation and tenant hijack. |
| 3 | #68 | The CQRS authorization pipeline is default-open: any request lacking a [CustomAuthorize] attribute runs with zero authentication or authorization. |
| 4 | #283 | The NextAuth authorize() callback trusts client-supplied userData unconditionally, letting any browser mint a fully valid authenticated session. |
| 5 | #76 | Any authenticated user can read, overwrite, or steal another tenant's fully-decrypted payment-gateway API keys and webhook secrets by enumerating an id. |
| 6 | #66 | GetUserRefreshTokens has its authorization attribute commented out and takes a raw userId, disclosing any user's session/refresh tokens for account takeover. |
| 7 | #71 | CORS is configured with SetIsOriginAllowed(_ => true).AllowCredentials(), allowing every origin to make credentialed requests to the API. |
| 8 | #72 | POST /api/media/upload is reachable with zero authentication and writes directly to a publicly readable blob container (SVG script injection possible). |
| 9 | #86 | The Member Portal has no real authentication — its login guard only checks the client's own localStorage write. |
| 10 | #34 | Global Donation detail-by-id has no CompanyId predicate, exposing any tenant's donor and financial data via id enumeration. |
| 11 | #43 | Contact Certificate print/preview is a cross-tenant IDOR leaking another tenant's donor PII and donation amounts to any staffer with Read. |
| 12 | #15 | The Contacts grid applies no CompanyId restriction at any layer, returning every tenant's contact records. |
| 13 | #79 | The Organization Bank Accounts list screen discloses all tenants' bank accounts with no id-guessing required. |
| 14 | #41 | The refund flow never calls the gateway RefundAsync — refunds are recorded as processed and mutate the donation ledger with no money actually moving. |
| 15 | #53 | CreateRefund sets refunds born-complete (REF) and bypasses the entire Approve/Process/Complete approval chain, so any create-permission holder finalizes refunds instantly. |
| 16 | #39 | The recurring-donation Retry action is a placeholder that fabricates a successful charge (stamps SUCCESS, increments counts) without contacting any payment processor. |
| 17 | #17 | Manual donation entry accepts client-supplied ExchangeRate and BaseCurrencyAmount with no server-side verification against the authoritative FX table. |
| 18 | #52 | Payment webhooks have no unique index on GatewayEventId, so the dedup check races and replayed webhook events can double-post charges. |
| 19 | #12 | The email delivery-status webhook is [AllowAnonymous] with signature validation commented out, processing attacker-supplied JSON with no verification. |
| 20 | #33 | All three public, anonymous payment-initiation mutations have no real reCAPTCHA verification and no CSRF protection. |
| 21 | #9 | The recurring-charge engine's candidate query is mis-scoped, so due schedules are silently skipped and donors are never charged as agreed. |
| 22 | #49 | Public event-ticketing checkout never checks per-ticket-type QuantityAvailable, allowing a specific tier to be oversold indefinitely. |
| 23 | #5 | Login unconditionally clears the lockout flag before checking it and never checks AccountExpiresAt, defeating brute-force lockout and account expiry. |
| 24 | #85 | Member enrollment Create bypasses the approval gate entirely, never consulting the org-level approval-mode setting. |
| 25 | #29 | Ambassador Collection records are persisted with CompanyId = 0 instead of the authenticated tenant, corrupting tenant ownership of cash-collection data. |
| 26 | #57 | No EF Core global CompanyId query filter exists as a defense-in-depth net, and no automated test asserts any handler is tenant-scoped. |
| 27 | #10 | Scheduled Reports has no execution engine at all — cron is never wired to Hangfire and runs are stuck permanently RUNNING. |
| 28 | #61 | The Custom Report Builder's Preview, Run, and Export never execute the user's definition against real data — all output is fabricated or no-op. |

## Cross-Cutting Themes

### Multi-tenant isolation & IDOR (42)

Handlers across the app omit any CompanyId predicate, and there is no EF global query filter or automated test as a backstop. This lets authenticated users read other tenants' donor PII, financial records, and even decrypted payment secrets, while some list screens leak all tenants' data with no id-guessing at all.

### Financial integrity, FX & currency correctness (34)

Money paths trust client-supplied exchange rates and base amounts, record cross-currency conversions at 1:1 on rate misses, and sum mixed-currency totals as if identical. Currency.DecimalPlaces is never consulted when rounding, and several ledger-affecting flows (refund, recurring charge) commit financial state without verified real-world money movement.

### Authentication, session & public-endpoint security (30)

The server authorization pipeline is default-open and several sensitive operations have auth attributes commented out, while the client can mint sessions from forged userData and the Member Portal has no real auth. Brute-force lockout and 2FA are written but unenforced, and anonymous webhooks and public payment endpoints lack signature, CSRF, and bot protection.

### Secrets, config & deployment ops readiness (26)

The JWT private key, DB credentials, and all encryption keys are committed to source control in plaintext, third-party integration secrets are stored unencrypted in the DB, and CORS is wildcard-with-credentials. Environment config is a single committed appsettings.json with hardcoded localhost URLs, no per-environment overrides, no migration-apply path, and a broken health check.

### Business-rule, lifecycle & state-machine gaps (38)

Entities transition through money- and status-changing lifecycles with missing or bypassable guards: refunds skip approval, grant stages allow illegal jumps, prayer/certificate/receipt-book statuses move arbitrarily, and enrollments bypass approval modes. Referential and duplicate-detection guards are frequently dead code or never invoked.

### Mocked, placeholder & dead features presented as working (22)

Multiple features render success while doing nothing real: Scheduled Reports and the Custom Report Builder have no execution engine, the main dashboard shows hardcoded figures, WhatsApp dispatch and Update-Rates are TODO stubs, and accounting/social integrations fabricate tokens and stats. These would silently mislead operators and donors.

### Background jobs & scheduling (15)

The Hangfire dashboard is dev-only so production job failures are invisible, several recurring jobs run with AutomaticRetry(0), and the FX-sync timer bypasses Hangfire with no distributed lock (double-runs when scaled). Some scheduled work — renewals, retention/purge, scheduled reports — has no automated trigger at all.

### Concurrency, transactions & data consistency (22)

No entity carries a concurrency token, so concurrent edits silently last-write-win, and key flows (recurring setup, reconciliation, auction bidding, receipt-book inventory, event registration) do read-then-act without locks or transactions. Multi-step writes are frequently non-atomic, leaving orphaned rows on partial failure.

### Observability, error-handling & audit (16)

Error handling is inconsistent across three incompatible response shapes, the registered exception handler and custom GraphQL error filter are dead configuration, and exception objects are logged without stack traces. Audit is best-effort with silent drop-on-overflow, several security actions produce no audit entry, and there is no APM/Sentry/OpenTelemetry anywhere.

### API contract & validation (13)

GraphQL wraps every exception into a 200-OK error envelope, has no query depth/cost limiting, disabled strict validation, and never disables introspection. Pagination has no upper clamp (or returns fully unpaginated on pageSize<=0), and raw driver/DB exception text is forwarded to clients, leaking schema and PII details.

### UI/UX, design-system & accessibility (15)

Focus indicators are removed app-wide with no replacement, icon-only actions rely on tooltips with no accessible name, and error states use raw non-token colors duplicated across variants. Currency formatters diverge across public pages, required-field markers use the wrong semantic color, and mobile safe-area handling is absent.

### Performance & scalability (13)

Grids sorting on dynamic JSONB fields and report/export handlers materialize entire result sets in-memory with no row ceiling, read-only queries run with change-tracking on, and core transactional tables lack the composite indexes their grid filters need. Exports run synchronously inline instead of via the existing background-job infrastructure.

### QA & testing coverage (12)

There are zero backend unit/integration tests, ~1% Playwright coverage, and no test step gating the CI/CD deploy, so a functionally-broken build ships as soon as it compiles. No test exercises a non-admin role, tenant scoping, or any money-workflow state-machine guard.

## Coverage & Method

This is a static source-code audit conducted by a multi-agent review that partitioned the system along both module dimensions (all ~18 modules / ~137 screens) and cross-cutting dimensions (multi-tenancy, currency/FX, security/auth, deployment/ops, error-handling, data-consistency, performance, QA). Each candidate finding was adversarially re-verified against the actual backend and frontend source — reading the specific handlers, configurations, and migrations named in each finding — and recorded as CONFIRMED or ADJUSTED (several originally-stated findings were narrowed or downgraded where the code partially mitigated the claim, e.g. #75, #116, #183). Two units (grants and security-auth) were re-run after transient stalls to ensure full coverage. Findings cite concrete source files, line ranges, and grep results as evidence. Because this is a static audit, dynamic runtime testing, load testing, and a dedicated penetration test are still required before release — particularly to exercise the tenant-isolation, session-forgery, webhook-replay, and payment-ledger paths under real conditions.

---

## Full Backlog

## Security & Access Control

### #66 · Auth — GetUserRefreshTokens (session/refresh-token disclosure) — Refresh token disclosure / session hijack  — `Critical`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** GetUserRefreshTokensQuery has its [CustomAuthorize] attribute commented out and accepts a raw caller-supplied userId with no ownership check, exposed via the GetUserRefreshTokens(userId) GraphQL query.
- **Gap identified:** GetUserRefreshTokensQuery has its [CustomAuthorize] attribute commented out and takes a raw int userId from the caller with no ownership check. Exposed via GraphQL GetUserRefreshTokens(userId), this lets an unauthenticated or any authenticated caller retrieve any user's active refresh token values (RefreshTokenName), which can then be redeemed via the RefreshToken mutation to mint a fresh access token — a full session-hijack path.
- **Why it's a problem:** Any unauthenticated or authenticated caller can request another user's active refresh token values and redeem them via the RefreshToken mutation to mint a valid access token, achieving full session hijack of any user.
- **Recommended solution:** Re-enable [CustomAuthorize] on the query, derive userId from the authenticated caller's own claims rather than accepting it as input, and add an explicit ownership check comparing the requested userId to the current principal.
- **Production impact:** This is an actively exploitable authentication bypass reachable today via a single GraphQL query in production.
- **Business impact:** Complete account takeover of any user (including admins) is possible, exposing all donor, financial, and PII data behind that account.
- **Technical impact:** A commented-out authorization attribute combined with unchecked user-supplied IDs is a critical, directly exploitable vulnerability requiring immediate remediation.
- **Evidence:** Base.Application/Business/AuthBusiness/RefreshTokens/Queries/GetUserRefreshTokens.cs:8-9; Base.API/EndPoints/Auth/Mutations/AuthendicationMutations.cs:376-390

### #67 · Contacts / Data Import (bulk Excel import) — Unauthorized bulk data import pipeline  — `Critical`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** UploadImportFile.cs (and the ImportController actions that invoke the parse/execute pipeline writing rows into staging and production tables) carry no [CustomAuthorize] attribute, and AuthorizationBehavior.cs explicitly skips authorization when the attribute is absent, unlike CreateImportSession which does have it.
- **Gap identified:** The actual file-upload/parse/execute pipeline that writes rows into staging and ultimately production tables has no authorization check at either the controller or CQRS layer, and the pipeline behavior is proven to skip auth entirely when the attribute is absent.
- **Why it's a problem:** The most destructive step of the import feature — actually writing bulk rows into the database — is left completely open while an adjacent, less consequential step is protected, so any authenticated (or in combination with gid 45's findings, potentially unauthenticated) caller can bulk-write arbitrary contact/donation data.
- **Recommended solution:** Add [CustomAuthorize] with the appropriate permission to UploadImportFile.cs and every ImportController action, and add an AuthorizationBehavior fail-closed default so missing attributes deny rather than skip authorization for any handler that mutates data.
- **Production impact:** Uncontrolled bulk-write endpoint can be used to mass-inject or corrupt production data with no audit gate.
- **Business impact:** Bulk unauthorized data injection risks corrupting donor/contact records at scale, undermining data integrity relied on for reporting and compliance.
- **Technical impact:** AuthorizationBehavior's fail-open ('skip if attribute missing') design is a systemic risk beyond this one handler — any future command that forgets the attribute is silently unprotected.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ImportBusiness/Sessions/Commands/UploadImportFile.cs:1-16 (no [CustomAuthorize]); ImportBusiness/ImportSessions/Commands/CreateImportSession.cs:6 (contrast, has [CustomAuthorize]); Base.API/Controller/ImportController.cs full file (no [Authorize]); Base.Application/Security/AuthorizationBehavior.cs:24-33 ('If the attribute is not found, skip authorization').

### #68 · CQRS AuthorizationBehavior pipeline — default-open — CQRS authorization pipeline default-open behavior  — `Critical`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** AuthorizationBehavior only enforces access control when a request carries [CustomAuthorize]; otherwise it calls return await next() with no check, and GraphQL registration only calls .AddAuthorization() (middleware wiring, not a global required-authorization policy).
- **Gap identified:** AuthorizationBehavior only enforces access control when the request type carries a [CustomAuthorize] attribute; if absent, return await next() executes with zero authentication/authorization check. Combined with GraphQL registration only calling .AddAuthorization() (middleware only, no global RequireAuthorization/default policy), any Command/Query missing the attribute is fully callable by anonymous network clients.
- **Why it's a problem:** Any Command/Query handler that a developer forgets to annotate with [CustomAuthorize] is fully callable by anonymous clients with zero authentication or authorization enforcement.
- **Recommended solution:** Invert the default to deny-by-default (require [CustomAuthorize] or an explicit [AllowAnonymous] opt-out) and add a GraphQL global RequireAuthorization()/default policy plus a build-time or startup audit that fails if any request type lacks an explicit authorization decision.
- **Production impact:** Any newly added or unannotated endpoint is immediately and silently exposed to unauthenticated access in production.
- **Business impact:** Sensitive NGO/donor/financial data across all tenants can be read or mutated by anonymous attackers via any un-annotated operation.
- **Technical impact:** Fail-open authorization architecture means a single missed attribute anywhere in the codebase is a full security hole, with no compensating control.
- **Evidence:** Base.Application/Security/AuthorizationBehavior.cs:29-33; Base.API/Extensions/GraphQLRegistrationExtensions.cs:55

### #69 · Global / All GraphQL mutations & queries (single /graphql endpoint) — GraphQL request/response PII logging  — `Critical`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** HttpRequestLoggingMiddleware logs the full request body (including GraphQL variables) at LogInformation for every path including /graphql, and the default log level in appsettings.json is Information, so this logging is always active in production.
- **Gap identified:** Because ALL GraphQL traffic (every mutation/query for the whole app) goes through the single /graphql path and the default logging level is Information (appsettings.json:17 Default: Information), this middleware writes every donor's PII and every credential-rotation payload (raw TwilioAuthToken/BirdApiKey/VonageApiSecret etc. — confirmed these fields flow in plaintext into SaveSmsConnectionSettings.cs, see related finding) into plaintext application logs on every request.
- **Why it's a problem:** Every donor PII field and every credential-rotation payload (e.g. raw TwilioAuthToken/BirdApiKey/VonageApiSecret) submitted through mutations is written to plaintext application logs on every single request, turning routine log storage/shipping into a PII and secrets leak.
- **Recommended solution:** Add a redaction layer in HttpRequestLoggingMiddleware that masks known secret/PII field names before logging, exclude /graphql request bodies from LogInformation (log at Debug/Trace only, gated per-environment), and raise the default Serilog/Microsoft log level to Warning in production appsettings.
- **Production impact:** Centralized/aggregated logs become a standing repository of donor PII and live third-party API credentials, accessible to anyone with log access.
- **Business impact:** Direct violation of data-protection obligations (GDPR/PII handling) to donors and exposes third-party vendor credentials to internal log readers or a log-store breach.
- **Technical impact:** Secrets and PII persist indefinitely in log sinks outside the application's own access-control boundary, defeating any in-app encryption or masking efforts.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Middleware/HttpRequestLoggingMiddleware.cs:18-22 (path list includes /graphql), :57-60 and :116-159 (LogRequestBody logs full body at LogInformation, line 143); registration confirmed unconditional at Base.API/DependencyInjection.cs:370 (no env check on lines 356-380); default log level confirmed at appsettings.json:17.

### #70 · Global / Backend Configuration (Base.API/appsettings.json) — Secrets committed to source control in plaintext  — `Critical`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** appsettings.json in Base.API contains plaintext master keys (PrivateKey, Security.EncryptionKey, CredentialEncryptionKey, SendGrid.WebhookVerificationKey) and DB passwords, all tracked in git with active edit history.
- **Gap identified:** All master keys and DB credentials are committed to source control in plaintext with no secret-manager/Key Vault indirection.
- **Why it's a problem:** Any master encryption/signing key or DB credential committed to source control is permanently exposed to anyone with repo access (current and historical), and cannot be considered secret going forward since git history retains it even if rotated in the file.
- **Recommended solution:** Move all keys and credentials to a secret manager (Azure Key Vault, AWS Secrets Manager, or environment-injected secrets), rotate every currently-committed key/credential, purge them from git history, and add a pre-commit/secret-scanning guard to prevent recurrence.
- **Production impact:** Any compromise of source control access (contractor offboarding, leaked repo clone, CI misconfiguration) directly yields production encryption keys and DB credentials.
- **Business impact:** A single repo-access breach could expose all encrypted donor/financial data across every tenant, a severe compliance and reputational failure for the platform.
- **Technical impact:** Encryption keys committed to version control invalidate the security guarantee of anything encrypted with them, since key confidentiality cannot be retroactively restored without full rotation.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/appsettings.json:5 (PrivateKey), :12-13 (DB passwords), :25 (Security.EncryptionKey), :29 (CredentialEncryptionKey), :32 (SendGrid.WebhookVerificationKey); confirmed tracked with active edit history via `git log --oneline -- PeopleServe/Services/Base/Base.API/appsettings.json` inside the PSS_2.0_Backend repo.

### #71 · Global CORS policy — Global CORS credential policy  — `Critical`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** The API's CORS policy uses .SetIsOriginAllowed(_ => true).AllowCredentials(), accepting credentialed requests from any origin.
- **Gap identified:** CORS is configured with .SetIsOriginAllowed(_ => true).AllowCredentials() in Base.API/DependencyInjection.cs (UseApiServices), which allows every origin to make credentialed requests (cookies/auth headers) to the API — functionally equivalent to AllowAnyOrigin+AllowCredentials, enabling cross-site credential theft/CSRF from any attacker-controlled site.
- **Why it's a problem:** This is functionally equivalent to AllowAnyOrigin+AllowCredentials, letting any attacker-controlled website make authenticated cross-site requests using a victim's cookies/auth headers.
- **Recommended solution:** Replace with an explicit allow-list of known frontend origins (per-tenant/environment config) and only call AllowCredentials() for those, rejecting all other origins by default.
- **Production impact:** Any deployed environment is immediately exposed to cross-site credential theft and CSRF from arbitrary websites.
- **Business impact:** A successful exploit could exfiltrate donor/financial data or perform unauthorized actions across all tenant organizations, a severe breach and compliance failure.
- **Technical impact:** The entire API's session/credential model is exposed to any origin, negating same-origin protections platform-wide.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/DependencyInjection.cs:361-367

### #72 · Media / Image Upload (used by logo, banner, profile-photo uploads across the app) — Unauthenticated public media upload  — `Critical`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** MediaController's upload action has no [Authorize] attribute, AddAuthorization() is registered with no default policy, and uploaded files are written to a blob container configured with PublicAccessType.Blob, trusting the client-supplied ContentType.
- **Gap identified:** POST /api/media/upload is reachable with zero authentication and uploads directly to a publicly readable blob container.
- **Why it's a problem:** Anyone on the internet can POST to this endpoint, filling org storage with arbitrary attacker content served back with a client-chosen Content-Type from a publicly-readable container — an unauthenticated file-hosting and content-spoofing primitive.
- **Recommended solution:** Add [Authorize] (or a scoped upload policy) to MediaController, switch the container's public access to private with SAS-token/CDN-mediated reads, and derive Content-Type server-side from validated file content rather than the client header.
- **Production impact:** Open, unauthenticated write access to production blob storage risks storage-cost abuse, defacement, and hosting of malicious content under the org's own domain.
- **Business impact:** Reputational and legal exposure if the org's storage is used to host illegal/abusive content, plus uncontrolled storage billing.
- **Technical impact:** No audit trail of who uploaded what; public-write/public-read storage removes any tenant isolation or access control on media assets.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/Controller/MediaController.cs:12-38 (class/action, no [Authorize]), :79-80 (PublicAccessType.Blob), :86 (client ContentType trusted); Base.API/DependencyInjection.cs:169 (AddAuthorization() no args), :171 (AddControllers() no filter); confirmed via grep of all Controller/*.cs that none carry [Authorize] except explicit [AllowAnonymous] on 3 webhook controllers.

### #73 · Secrets in source-controlled appsettings.json — Secrets committed to source control  — `Critical`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** Base.API/appsettings.json contains the JWT RSA private key, a live Postgres connection string with plaintext credentials, the encryption keys, and the SendGrid webhook verification key all checked into the repository in cleartext.
- **Gap identified:** Base.API/appsettings.json commits the JWT RSA private key (JwtSettings:PrivateKey), a live Postgres connection string with plaintext username/password, the Security:EncryptionKey, PaymentGateway:CredentialEncryptionKey, and SendGrid:WebhookVerificationKey in cleartext in the repo.
- **Why it's a problem:** Anyone with repo read access (including past contributors, CI logs, or a future breach of the git host) obtains full cryptographic and database compromise material, not just a config leak.
- **Recommended solution:** Rotate every listed secret immediately, remove them from appsettings.json and git history (BFG/filter-repo), and move them to a secrets manager (Azure Key Vault / AWS Secrets Manager / environment variables injected at deploy time) with appsettings.json holding only placeholders.
- **Production impact:** A single leaked repo clone gives an attacker the means to forge JWTs, decrypt payment credentials, and directly access the production database.
- **Business impact:** This is a critical, potentially reportable data-breach precondition affecting donor PII and payment data, with direct regulatory and trust consequences.
- **Technical impact:** Total compromise of authentication (RSA key), data-at-rest encryption, and payment gateway credentials in one exposure — no defense in depth remains once the repo is read.
- **Evidence:** Base.API/appsettings.json:2-34

### #74 · Settings / SMS Setup, WhatsApp Setup, Accounting Integrations — Plaintext third-party integration credentials  — `Critical`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** SmsSetting, WhatsAppSetting, and AccountingIntegration entities store TwilioAuthToken/BirdApiKey/VonageApiSecret and accounting credentials as plain string fields, and SaveSmsConnectionSettings.cs writes them directly with no encryption call, unlike the payment-gateway save path which does encrypt.
- **Gap identified:** Every third-party messaging/accounting integration credential is stored in the database in plaintext, in direct contrast to the payment-gateway path.
- **Why it's a problem:** A single database read (backup, replica, SQL injection, or insider access) exposes live credentials for SMS, WhatsApp, and accounting integrations, letting an attacker impersonate the org's messaging/accounting channels or pivot into those third-party accounts.
- **Recommended solution:** Apply the same encryption-at-rest pattern already used in UpdateCompanyPaymentGateway.cs (e.g. field-level encryption via a shared ISecretProtector) to SaveSmsConnectionSettings and the AccountingIntegration save path, and add a migration to re-encrypt existing plaintext rows.
- **Production impact:** A database-level compromise immediately yields usable third-party credentials with no additional cracking effort.
- **Business impact:** Credential leakage could let attackers send fraudulent SMS/WhatsApp messages or manipulate accounting sync under the org's identity, with vendor-contract and reputational fallout.
- **Technical impact:** Inconsistent secret-handling pattern across the codebase increases the chance new integrations copy the insecure path rather than the proven encrypted one.
- **Evidence:** Base.Domain/Models/NotifyModels/SmsSetting.cs:23,29,35,42-43,51; Base.Domain/Models/NotifyModels/WhatsAppSetting.cs:17-18,26; Base.Domain/Models/IntegrationModels/AccountingIntegration.cs:22-26,31-32; Base.Application/Business/NotifyBusiness/SmsSettings/SaveConnectionCommand/SaveSmsConnectionSettings.cs:66-124 (no encryption call, direct field writes); contrast Base.Application/Business/DonationBusiness/CompanyPaymentGateways/Commands/UpdateCompanyPaymentGateway.cs:46-49 (verified correct pattern).

### #176 · Global / All GraphQL operations — GraphQL query depth/cost limiting  — `High`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** ADJUSTED
- **Current implementation:** GraphQLRegistrationExtensions.cs defines no query-depth or cost-limit validation rule, and StrictValidation is disabled (deliberately, per an in-code comment, to support Dictionary<string,object> input types).
- **Gap identified:** The GraphQL endpoint has no server-level query depth, complexity, or cost limiting, and StrictValidation is turned off — though a code comment (lines 56-57) documents a specific reason for the latter (supporting Dictionary<string,object> input types), so it is not an unexplained oversight the way the missing depth/cost limiting is.
- **Why it's a problem:** Without depth/cost limits, a single authenticated (or, combined with other findings, potentially anonymous) client can submit a deeply nested or highly-repetitive query that fans out into an expensive query plan, exhausting database/CPU resources.
- **Recommended solution:** Add HotChocolate's MaxExecutionDepthRule and a cost-analysis/complexity rule sized to the schema's real usage, keeping StrictValidation disabled only for the documented Dictionary input-type reason.
- **Production impact:** A single malicious or malformed query can degrade or take down the shared GraphQL endpoint for all tenants.
- **Business impact:** Denial-of-service risk against a multi-tenant SaaS shared endpoint impacts every customer simultaneously, threatening SLA commitments.
- **Technical impact:** No resource ceiling on query complexity leaves the API surface vulnerable to both accidental (bad client query) and deliberate abuse.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/Extensions/GraphQLRegistrationExtensions.cs:55-61 (no depth/cost rule; StrictValidation=false with an in-code justification comment at lines 56-57); repo-wide grep for depth/cost/introspection rules returned no matches.
- **Reviewer note:** Core gap (no query depth/cost limiting, no introspection gating) is confirmed and real. However the recommendation to unconditionally 're-enable StrictValidation' overstates the issue — the code has a documented, apparently deliberate reason for disabling it (Dictionary<string,object> support), so that specific sub-claim should be softened to 'scope the relaxation narrowly' rather than framed as an unexplained oversight.

### #177 · Login brute-force lockout — written but never enforced — Login lockout enforcement  — `High`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** The Login handler increments FailedLoginCount and sets IsLocked=true after 5 failed attempts, but never checks the user's IsLocked flag before running VerifyPassword on later login attempts.
- **Gap identified:** The Login mutation increments FailedLoginCount and sets IsLocked=true after 5 failures, but the Login handler never checks result.user.IsLocked before calling VerifyPassword on subsequent attempts. The lockout flag is written but never read/enforced in the login path, so account lockout provides no actual brute-force protection.
- **Why it's a problem:** A lockout flag that is written but never read provides zero actual protection, so the system is effectively wide open to unlimited password-guessing against any account.
- **Recommended solution:** In the Login command handler, load the user first and short-circuit with an AuthenticationFailure (generic message, no user enumeration) if IsLocked is true; add a lockout expiry/unlock policy (time-based or admin-reset) and cover it with a unit test asserting login is rejected once locked.
- **Production impact:** Brute-force credential-stuffing attacks can run unthrottled against production accounts with no automatic circuit breaker.
- **Business impact:** Account takeover of donor/staff accounts exposes PII and financial data, risking compliance violations and reputational damage to the NGO.
- **Technical impact:** Security control drift between data model and enforcement logic — the schema implies protection that the code silently does not provide.
- **Evidence:** Base.API/EndPoints/Auth/Mutations/AuthendicationMutations.cs:45-182 (no IsLocked check anywhere in Login)

### #178 · Media / Image Upload — Unsanitized SVG upload (stored XSS vector)  — `High`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** MediaController allows .svg uploads based only on file extension, trusts the client-supplied Content-Type, and (per gid 45) serves files from a publicly readable blob container — with no content sanitization of the SVG's embedded script/markup.
- **Gap identified:** SVG is a script-capable format accepted with no content sanitization; combined with the public blob container and client-controlled Content-Type, an uploaded SVG can be served back and rendered inline from a trusted org-owned storage URL.
- **Why it's a problem:** SVG is a script-capable format; an uploaded malicious SVG can be linked or embedded and executed in a victim's browser under the trust of the org's own storage domain, unlike the Excel import path which already validates via magic bytes.
- **Recommended solution:** Sanitize SVG content server-side (strip <script>, event handlers, foreignObject) before storage, verify uploads via magic-byte/content inspection (matching the pattern already used in UploadImportFile.cs for Excel), and serve images with a Content-Disposition/CSP that prevents inline script execution.
- **Production impact:** Publicly hosted attacker-controlled SVGs enable stored XSS served from a trusted org domain, bypassing typical third-party-script defenses.
- **Business impact:** Successful XSS against staff or donor-facing pages could hijack sessions or deface branded pages, damaging donor trust.
- **Technical impact:** Extension-only validation is inconsistent with the magic-byte pattern already proven elsewhere in the codebase, indicating an uneven security baseline across upload paths.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/Controller/MediaController.cs:19 (.svg in allow-list), :43-46 (extension-only check), :86 (client ContentType trusted); contrast Base.Application/Business/ImportBusiness/Sessions/Commands/UploadImportFile.cs:24-26 (magic-byte constants present and used for Excel).

### #179 · Password reset token single-use enforcement — Password reset token replay prevention  — `High`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** ResetPasswordsCommandHandler checks only the token's decrypted 24-hour expiry and sets PasswordReset.IsUsed=true after a successful reset, but never checks IsUsed before allowing the reset to proceed.
- **Gap identified:** ResetPasswordsCommandHandler validates the token's decrypted expiry (24h) but never checks PasswordReset.IsUsed before performing the password change — it only sets IsUsed=true after the reset succeeds. A previously-used reset link remains valid for the full 24-hour window and can be replayed to reset the password again (e.g. by anyone who intercepted the original reset email).
- **Why it's a problem:** The single-use guarantee of the reset token is not enforced, so the same token can be replayed to change the password repeatedly for the full 24-hour validity window.
- **Recommended solution:** Add an explicit IsUsed check at the start of the handler that rejects already-used tokens with a generic error, and wrap the used-check + password update + IsUsed=true write in a single transaction to close the race window.
- **Production impact:** An intercepted or previously-processed reset link remains a live attack vector for up to 24 hours after first use.
- **Business impact:** Enables account takeover via a stale reset email (e.g., forwarded, cached, or intercepted in transit), undermining donor and staff trust in account security.
- **Technical impact:** Missing idempotency/replay control on a security-critical state transition, and a possible race condition if the check is added without transactional protection.
- **Evidence:** Base.Application/Business/AuthBusiness/ResetPasswords/Commands/ResetPasswords.cs:27-93 (IsUsed only set, never checked)

### #180 · SendGrid webhook — debug raw endpoint (unauthenticated) — SendGrid webhook signature validation  — `High`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** The /api/webhooks/sendgrid/events-raw endpoint is marked [AllowAnonymous] with its [ValidateSendGridWebhook] signature filter commented out, so it deserializes and processes any posted JSON as email delivery events with no authentication or signature verification.
- **Gap identified:** /api/webhooks/sendgrid/events-raw is [AllowAnonymous] with its [ValidateSendGridWebhook] signature-validation filter commented out, and directly deserializes and processes attacker-supplied JSON into the email-status pipeline (delivered/bounced/opened events) with no authentication or signature check at all.
- **Why it's a problem:** Without signature validation, anyone on the internet can POST fabricated delivery/bounce/open events directly into the email-status pipeline, corrupting data or triggering downstream logic keyed off those statuses.
- **Recommended solution:** Re-enable the [ValidateSendGridWebhook] filter (or remove the debug endpoint entirely from production routing) and gate the raw endpoint behind an environment flag so it can never be reachable outside local debugging.
- **Production impact:** An unauthenticated, unvalidated endpoint accepting arbitrary payloads is a direct injection point into production email-tracking data.
- **Business impact:** Falsified bounce/delivery statuses can suppress legitimate donor communications or falsely mark real emails as failed, harming donor engagement and reporting accuracy.
- **Technical impact:** No input trust boundary on a public endpoint that writes into the email-status data model, expanding the attack surface with no compensating control.
- **Evidence:** Base.API/EndPoints/Notify/Controllers/WebhookController.cs:88-91

### #284 · Contacts / Contact Update — Client-settable LastDonationDate on Contact  — `Medium`

- **Module:** Security & Access Control  |  **Category:** Mass Assignment / Over-posting  |  **Verification:** CONFIRMED
- **Current implementation:** ContactRequestDto includes LastDonationDate as a freely client-settable field, and UpdateContact.cs maps it straight through Adapt() onto the entity with no server-side recomputation or cross-check against actual donation records.
- **Gap identified:** ContactRequestDto exposes LastDonationDate as a freely client-settable field that flows straight through the Adapt() call with no server-side recomputation or validation against real donation records.
- **Why it's a problem:** A field that should be a derived/computed value from real donation transactions can instead be overwritten by any caller with update rights, letting the displayed donation history diverge from ground truth.
- **Recommended solution:** Remove LastDonationDate from ContactRequestDto (or mark it ignored in the mapping profile) and recompute it server-side from the GlobalDonation table whenever donation-affecting events occur, never accepting it as client input.
- **Production impact:** Contact records can silently show incorrect donation recency, affecting any workflow (segmentation, reporting, lapsed-donor outreach) that relies on it.
- **Business impact:** Inaccurate donor-engagement data undermines fundraising/reporting decisions and could misrepresent donor activity to stakeholders or auditors.
- **Technical impact:** A mass-assignment/over-posting gap where a derived field is treated as raw input, breaking the invariant that LastDonationDate reflects actual transaction history.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/ContactSchemas/ContactSchemas.cs:58 (LastDonationDate on request DTO); PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/Contacts/Commands/UpdateContact.cs:85,88.
- **Reviewer note:** not adversarially verified (Medium/Low)

### #285 · CreateRefreshToken command authorization — Refresh token creation authorization  — `Medium`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** CreateRefreshTokenCommand has its [CustomAuthorize] attribute commented out, so the GraphQL create-refresh-token mutation runs with no server-side authorization check and accepts an arbitrary UserId in the payload.
- **Gap identified:** CreateRefreshTokenCommand's [CustomAuthorize] attribute is commented out, so the GraphQL-exposed create-refresh-token operation has no server-side authorization gate; it accepts an arbitrary UserId in RefreshTokenDto with no verification the caller owns that identity.
- **Why it's a problem:** Without an authorization gate, the operation cannot verify the caller is the identity they claim to be, opening the door to minting refresh tokens for other users' accounts.
- **Recommended solution:** Restore the [CustomAuthorize] attribute and additionally validate server-side that the UserId in the DTO matches the authenticated principal's own user ID before issuing the token.
- **Production impact:** An authenticated caller could obtain long-lived session credentials for a different user account without further checks.
- **Business impact:** Cross-account impersonation risk undermines the integrity of every downstream action performed 'as' the impersonated user, including financial and donor data access.
- **Technical impact:** A GraphQL mutation with no authorization boundary and unvalidated identity input is a direct privilege-escalation vector.
- **Evidence:** Base.Application/Business/AuthBusiness/RefreshTokens/Commands/CreateRefreshToken.cs:1-4

### #286 · Frontend route protection (Next.js middleware) — Frontend edge route protection  — `Medium`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** PSS_2.0_Frontend/middleware.ts only performs locale-prefix redirection inside its auth() wrapper; it contains no session/authentication check or login redirect for protected routes.
- **Gap identified:** middleware.ts only performs locale-prefix redirection via auth((req) => {...}); it contains no session/authentication check or redirect-to-login logic for protected routes, meaning route-level access control is not centrally enforced at the edge and depends entirely on per-page/component-level checks plus backend GraphQL authorization.
- **Why it's a problem:** Route-level access control is not centrally enforced at the edge, so protection depends entirely on inconsistent per-page/component checks plus backend GraphQL authorization, leaving room for pages that forget the check.
- **Recommended solution:** Extend the middleware to inspect the session/auth token on protected route matchers and redirect unauthenticated requests to the login page before any page code executes, keeping backend GraphQL authorization as defense in depth rather than the sole gate.
- **Production impact:** A newly added or misconfigured page that omits its own client-side auth check would render (at least briefly) for unauthenticated users before any backend call fails.
- **Business impact:** Inconsistent UI-level access control increases the chance of accidental data exposure to unauthenticated visitors, harming trust and potentially exposing donor-facing screens.
- **Technical impact:** No single, auditable enforcement point for route protection increases maintenance risk as new routes/pages are added without a shared safety net.
- **Evidence:** PSS_2.0_Frontend/middleware.ts:17-48

### #287 · Global / All GraphQL error responses — Raw exception leakage in GraphQL errors  — `Medium`

- **Module:** Security & Access Control  |  **Category:** PII / Internal-Detail Exposure in Responses  |  **Verification:** CONFIRMED
- **Current implementation:** CustomErrorFilter.cs forwards raw database/driver exception messages unmodified to GraphQL clients, and UpdateContact.cs's error path is one confirmed example where this surfaces literal DB detail.
- **Gap identified:** Raw database/driver exception messages (which can include table/column/constraint names and, depending on Npgsql 'Include Error Detail' settings, literal offending values such as duplicate email/phone) are forwarded unmodified to API clients via GraphQL errors.
- **Why it's a problem:** Depending on Npgsql's 'Include Error Detail' setting, these messages can include table/column/constraint names and even the literal offending value (e.g. a duplicate email/phone), disclosing internal schema and other users' PII to any client that triggers an error.
- **Recommended solution:** In CustomErrorFilter.cs, map known exception types (DbUpdateException, constraint violations) to sanitized, generic client-facing messages and log the raw exception server-side only; explicitly disable Npgsql 'Include Error Detail' in production configuration.
- **Production impact:** Error responses become an unintended internal-schema and cross-tenant-data disclosure channel triggerable by normal user actions (e.g. duplicate entry).
- **Business impact:** Leaking another donor's email/phone via a duplicate-constraint error is a PII exposure incident, not just an information-disclosure nuisance.
- **Technical impact:** Exposes internal table/column/constraint naming to clients, aiding further attack reconnaissance against the schema.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/Exceptions/CustomErrorFilter.cs:34-40; PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/Contacts/Commands/UpdateContact.cs:534-541.
- **Reviewer note:** not adversarially verified (Medium/Low)

### #288 · JWT access token lifetime vs. reported expiry — JWT access token lifetime disclosure mismatch  — `Medium`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** CreateToken sets the actual signed JWT Expires claim to DateTime.UtcNow.AddDays(1) (24-hour validity), while TokenResponseDto.ExpiresIn is separately computed as a fixed 900 seconds (15 minutes), so the client is told a different expiry than what the token actually carries.
- **Gap identified:** CreateToken sets the actual JWT Expires = DateTime.UtcNow.AddDays(1) (24-hour token validity) while TokenResponseDto.ExpiresIn is computed as (DateTime.UtcNow.AddMinutes(15) - DateTime.UtcNow).TotalSeconds (900s) — the client is told the token expires in 15 minutes but the signed JWT itself remains valid for a full day, so a leaked/stolen access token stays usable far longer than the client (or any short-lived-token assumption) expects.
- **Why it's a problem:** Client-side logic (e.g. proactive silent refresh, short-lived-token security assumptions) relies on the reported 15-minute expiry, but the token remains cryptographically valid for 24 hours regardless, so a stolen/leaked token stays exploitable far longer than assumed.
- **Recommended solution:** Make ExpiresIn derive from the same value used to set the JWT's Expires claim (single source of truth for token lifetime), and reassess whether 24-hour access tokens are appropriate at all — consider shortening to match the intended 15-minute policy with refresh-token-driven renewal.
- **Production impact:** Any incident response assuming access tokens self-expire in 15 minutes will underestimate the actual exposure window by nearly 24x.
- **Business impact:** Extended token validity increases the blast radius and dwell time of any credential leak affecting donor or staff accounts.
- **Technical impact:** Divergent source-of-truth for token lifetime between the signing code and the response DTO is a maintainability and security-audit hazard.
- **Evidence:** Base.Application/Extensions/AuthExtensions.cs:89, 105-111

### #289 · RevokeRefreshToken / SwitchCompany target-user parameter — Refresh token revocation scope check  — `Medium`

- **Module:** Security & Access Control  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** RevokeRefreshTokenCommand is authorized only by a coarse RBAC capability (DecoratorAuthModules.RefreshToken, Permissions.Delete) and accepts an arbitrary target userId argument with no check that it matches the caller or falls within the caller's scoped authority.
- **Gap identified:** RevokeRefreshTokenCommand is gated only by a coarse RBAC capability check (DecoratorAuthModules.RefreshToken, Permissions.Delete) and accepts an arbitrary userId argument from the caller with no verification that the target equals the authenticated caller or that the caller has scoped authority over that specific user — any principal holding that one capability can force-logout any other user in the system.
- **Why it's a problem:** Any principal holding the generic Delete-refresh-token capability can revoke sessions for any other user in the system, not just their own, since there is no per-target ownership or scope validation.
- **Recommended solution:** Add a server-side check that the target userId equals the authenticated caller's ID unless the caller also holds an elevated 'manage other users' sessions' capability, and log/audit any cross-user revocation for traceability.
- **Production impact:** A low-privileged but capability-holding account could force-logout arbitrary users, causing unplanned session disruptions in production.
- **Business impact:** Enables a denial-of-service style abuse against specific staff or donor accounts (repeatedly forcing logout), disrupting operations and support workflows.
- **Technical impact:** Coarse capability-based authorization without object-level scoping is a recurring privilege-escalation pattern that needs a consistent ownership-check convention across all user-targeted commands.
- **Evidence:** Base.Application/Business/AuthBusiness/RefreshTokens/Commands/RevokeRefreshToken.cs:4-6, 20-27

### #329 · Data Import / Staging pipeline — Potential SQL-identifier injection via import field names  — `Low`

- **Module:** Security & Access Control  |  **Category:** Input Validation / Injection (tentative)  |  **Verification:** CONFIRMED
- **Current implementation:** StagingTableService.cs interpolates FieldName unescaped into quoted SQL identifiers when building/querying staging tables, while the adjacent table-name path has an explicit guard that FieldName lacks.
- **Gap identified:** If FieldName can ever contain a double-quote or other SQL-identifier metacharacter (its upstream source — likely the uploaded Excel header row via ImportController, which as noted above has no authorization — was not fully traced to a hard allow-list), this becomes a SQL-identifier injection point.
- **Why it's a problem:** If FieldName (sourced from the uploaded Excel header row via the same import pipeline flagged in gid 46 as unauthorized) can ever contain a double-quote or other identifier metacharacter, it becomes a SQL-identifier injection point into dynamically built staging-table DDL/DML.
- **Recommended solution:** Apply the same allow-list/escaping guard already used for table names to FieldName before interpolation (e.g. validate against a strict alphanumeric/underscore pattern, or escape embedded quotes), consistent across StagingTableService.cs lines 105 and 160.
- **Production impact:** An unvalidated header value could corrupt or manipulate dynamically generated SQL against the staging schema.
- **Business impact:** Low likelihood but high-severity if exploited, since it touches the same pipeline that writes into production tables during import.
- **Technical impact:** Inconsistent identifier-escaping discipline within the same service (present for table names, absent for field names) signals the guard was simply missed rather than deemed unnecessary.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Services/Import/StagingTableService.cs:105,160 (unescaped FieldName interpolated into quoted identifiers), contrast with :97-98,154-155 (table-name guard present but no equivalent for field names).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #330 · Named CORS policy mismatch — CORS policy configuration mismatch  — `Low`

- **Module:** Security & Access Control  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** UseApiServices() invokes app.UseCors("CorsPolicy") after an anonymous, unnamed global UseCors(opt => ...) call, but services.AddCors() never registers a named policy called CorsPolicy anywhere in DependencyInjection.cs.
- **Gap identified:** UseApiServices() calls app.UseCors("CorsPolicy") after the anonymous global app.UseCors(opt => ...), but services.AddCors() is registered with no named policies configured anywhere in DependencyInjection.cs — the referenced CorsPolicy policy does not exist, making this call either a silent no-op or a latent runtime error depending on ASP.NET Core CORS resolution behavior.
- **Why it's a problem:** Referencing a named CORS policy that was never registered is either a dead no-op (masking intended restrictions) or a startup/runtime error, so the actual effective CORS behavior in production is unverified and unpredictable.
- **Recommended solution:** Register an explicit named policy (e.g. services.AddCors(o => o.AddPolicy("CorsPolicy", p => p.WithOrigins(...))) matching the intended allowed origins, and remove the redundant anonymous UseCors call so there is a single, auditable CORS configuration path.
- **Production impact:** Ambiguous/duplicate CORS wiring risks either an unintentionally permissive global policy going live or a startup exception if ASP.NET Core rejects the unregistered policy name.
- **Business impact:** Incorrect CORS exposure could allow unauthorized origins to call the API, or an outage could occur if the misconfiguration surfaces as a runtime fault.
- **Technical impact:** Dead/duplicate configuration reduces confidence in what security boundary is actually enforced, complicating future audits and changes.
- **Evidence:** Base.API/DependencyInjection.cs:39 (AddCors, no named policy), 363-368 (global CORS), 388 (UseCors("CorsPolicy"))

## Fundraising · Donations & Receipts

### #34 · Donation (Global) — Detail/View by ID — Cross-tenant donation record disclosure  — `Critical`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** GetGlobalDonationByIdHandler retrieves a donation by GlobalDonationId and IsDeleted only; no CompanyId filter exists in the query, and AuthorizationBehavior only checks role/menu capability, never the target entity's tenant ownership.
- **Gap identified:** GetGlobalDonationByIdHandler filters only by GlobalDonationId (and IsDeleted); no CompanyId predicate anywhere in the query, validator, or AuthorizationBehavior — confirmed by reading GetGlobalDonationById.cs in full and AuthorizationBehavior.cs in full.
- **Why it's a problem:** Any authenticated user who guesses or enumerates a valid GlobalDonationId can view another company's donor PII, amounts, and receipt data, a direct multi-tenant isolation breach.
- **Recommended solution:** Add a mandatory CompanyId predicate to the query (o.GlobalDonationId == id && o.CompanyId == currentCompanyId && !o.IsDeleted), and add a global EF query filter or a resource-level authorization check in AuthorizationBehavior that validates the loaded entity's CompanyId against the current user's tenant before returning data.
- **Production impact:** Cross-tenant data leak exploitable via simple ID enumeration in production.
- **Business impact:** Breach of donor confidentiality and tenant data-isolation guarantees, a contractual and regulatory (GDPR/PCI-adjacent) exposure for the SaaS vendor.
- **Technical impact:** Missing tenant boundary in a core read path indicates the same pattern likely exists in sibling queries, widening the security surface.
- **Evidence:** Base.Application/Business/DonationBusiness/GlobalDonations/Queries/GetGlobalDonationById.cs:17 (FindRecordByProperty, no CompanyId), :74 (o.GlobalDonationId.Equals(query.globalDonationId) && o.IsDeleted == false — no CompanyId term); Base.Application/Security/AuthorizationBehavior.cs:49-69 (hasAccess check is purely role/capability via HasAccessAsync(userId, menuCode, ...), never touches the target entity or its CompanyId); grep for HasQueryFilter across Base.Infrastructure returned zero matches.
- **Reviewer note:** Read the full handler/validator and the full AuthorizationBehavior — exactly as described. No CompanyId scoping anywhere in the call chain for this query.

### #35 · Donation In Kind (legacy Screen #7 standalone flow) — Unauthorized legacy DIK mutations  — `Critical`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** CreateDonationInKind, UpdateDonationInKind, ToggleDonationInKind, and DeleteDonationInKind all have their [CustomAuthorize] attribute commented out, and AuthorizationBehavior no-ops (returns next()) whenever the attribute is absent.
- **Gap identified:** All four legacy DIK CRUD commands (Create/Update/Toggle/Delete) have their [CustomAuthorize] attribute commented out, and AuthorizationBehavior explicitly no-ops when the attribute is absent, so these mutations run for any authenticated user.
- **Why it's a problem:** Any authenticated user, regardless of role or capability, can create, edit, toggle, or delete in-kind donation records with zero authorization check.
- **Recommended solution:** Restore the [CustomAuthorize(menuCode/capability)] attribute on all four commands with the correct DIK capability codes, and add a regression test asserting AuthorizationBehavior rejects unauthorized callers for each.
- **Production impact:** Unrestricted CRUD on financial donation records reachable by any logged-in user, an immediate exploitable authorization bypass.
- **Business impact:** Risk of fraudulent or accidental deletion/alteration of donation records affecting financial reporting and donor receipts.
- **Technical impact:** Authorization framework silently degrades to no-op on missing attributes, making this a systemic risk anywhere an attribute is forgotten or commented out.
- **Evidence:** Base.Application/Business/DonationBusiness/DonationInKinds/Commands/CreateDonationInKind.cs:12 (`//[CustomAuthorize(...)]`); UpdateDonationInKind.cs:19; ToggleDonationInKind.cs:8; DeleteDonationInKind.cs:8; Base.Application/Security/AuthorizationBehavior.cs:29-33 (`if (authorizeAttribute == null) return await next();`); Base.API/EndPoints/Donation/Mutations/DonationInKindMutations.cs (full file read — CreateDonationInKind/UpdateDonationInKind/DeleteDonationInKind/ToggleDonationInKind resolvers add no independent authorization, only try/catch wrapping).
- **Reviewer note:** Opened all four command files and the resolver file in full — attributes are genuinely commented out and no other layer compensates.

### #36 · In-Kind Donation — Create and Realize — DIK base-currency amount missing FX conversion  — `Critical`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** Both DIK creation (GlobalDonationCompositeWriter) and DIK realization (RealizeInKindDonation) set BaseCurrencyAmount equal to the raw donor-currency amount without multiplying by GlobalDonation.ExchangeRate, unlike the online-donation resolution path which correctly computes amount * exchangeRate.
- **Gap identified:** Both Create (GlobalDonationCompositeWriter) and Realize (RealizeInKindDonation) set BaseCurrencyAmount equal to the raw donor-currency amount without multiplying by GlobalDonation.ExchangeRate, unlike the sibling online-donation resolution path which correctly computes baseCurrencyAmount = staging.Amount * exchangeRate.
- **Why it's a problem:** For any DIK donation in a non-base currency, BaseCurrencyAmount is silently wrong, corrupting consolidated financial totals, exchange gain/loss, and multi-currency reporting.
- **Recommended solution:** Apply the same baseCurrencyAmount = amount * exchangeRate calculation used in ResolveOnlineDonationStaging.cs to both GlobalDonationCompositeWriter's Create path and RealizeInKindDonation's Realize path, and add a unit test covering a non-1.0 exchange rate.
- **Production impact:** Silent financial miscalculation with no error surfaced, corrupting reports before anyone notices.
- **Business impact:** Inaccurate donor receipts, board/finance reports, and audited financial statements for any foreign-currency in-kind donation.
- **Technical impact:** Divergent FX-handling logic across two donation paths (DIK vs online) is a maintainability hazard and violates the single-conversion-point expectation for currency snapshotting.
- **Evidence:** Base.Application/Business/DonationBusiness/GlobalDonations/Services/GlobalDonationCompositeWriter.cs:227-229 (`gd.DonationAmount = estimated; gd.NetAmount = estimated; gd.BaseCurrencyAmount = estimated;` — no ExchangeRate multiplication); Base.Application/Business/DonationBusiness/DonationInKinds/Commands/RealizeInKindDonation.cs:137-139 (identical pattern with RealizedAmount); Base.Application/Business/DonationBusiness/GlobalDonations/Commands/CreateGlobalDonationWithChildren.cs:46 (ExchangeRate is a mandatory field for every donation, DIK included, since DIK goes through this same composite command); contrast with Base.Application/Business/DonationBusiness/OnlineDonationInbox/Commands/ResolveOnlineDonationStaging.cs:151-170 (`baseCurrencyAmount = staging.Amount * exchangeRate`), confirming the correct pattern exists elsewhere and DIK skips it.
- **Reviewer note:** Verified both DIK code paths omit the multiplication and found a sibling online-donation path in the same codebase that performs the multiplication correctly, confirming this is an omission rather than an intentional design choice.

### #37 · In-Kind Donation entry (GlobalDonation flow, mode=DIK) — Zero-distribution DIK insert crash  — `Critical`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** GlobalDonationCompositeWriter inserts a GlobalDonationDistribution row with ParticipantRoleId hardcoded to 0 when the frontend submits zero distribution rows, but ParticipantRoleId is a non-nullable FK column with no row 0 in MasterData.
- **Gap identified:** Zero-distribution DIK submission causes GlobalDonationCompositeWriter to insert a GlobalDonationDistribution with ParticipantRoleId = 0, but ParticipantRoleId is a non-nullable int with a required FK to MasterData (no IsRequired(false) override), so the insert will violate the FK constraint at SaveChangesAsync.
- **Why it's a problem:** The insert will fail the FK constraint at SaveChangesAsync, so any zero-distribution DIK submission (explicitly called out in the code comment as a legitimate case) throws an unhandled database exception instead of completing.
- **Recommended solution:** Either make ParticipantRoleId nullable with IsRequired(false) when distributions are optional, or skip creating the GlobalDonationDistribution row entirely when the distribution list is empty, and add validation to reject/short-circuit zero-distribution submissions before the composite write.
- **Production impact:** Runtime FK-violation exception surfaces to the end user as a failed save on a supported use case.
- **Business impact:** Donors/staff cannot record legitimate zero-distribution in-kind donations, blocking a documented workflow.
- **Technical impact:** A hardcoded sentinel value (0) used as a real FK value is a data-integrity anti-pattern that will resurface wherever ParticipantRoleId is read downstream.
- **Evidence:** Base.Application/Business/DonationBusiness/GlobalDonations/Services/GlobalDonationCompositeWriter.cs:232-244 (comment 'FE may legitimately submit zero rows' then `ParticipantRoleId = 0`); :273-274 (dbContext.GlobalDonations.Add(gd); await dbContext.SaveChangesAsync(...)); Base.Domain/Models/DonationModels/GlobalDonationDistribution.cs:12 (`public int ParticipantRoleId { get; set; }` — non-nullable); Base.Infrastructure/Data/Configurations/DonationConfigurations/GlobalDonationDistributionConfiguration.cs:30-32 (HasOne(ParticipantRole).HasForeignKey(ParticipantRoleId), no IsRequired(false) — required navigation by convention since FK is non-nullable int); MasterDataConfigurations.cs:12 confirms MasterDataId is UseIdentityAlwaysColumn (starts at 1, no row 0 exists).
- **Reviewer note:** Read the full writer method, the entity, and both configuration files — the zero-distribution DIK path really does construct a distribution row pointing at a nonexistent MasterData id, which will throw an FK violation on save for the documented common case.

### #38 · Matching Gift — status transition (Approve/Reject/Receive) — Matching Gift status transition lookup  — `Critical`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** UpdateMatchingGiftStatus.cs resolves the target MasterData row via a query filtered only on DataValue==newCode (e.g. "APPROVED"), with no MasterDataType.TypeCode filter and no IsDeleted filter, despite the handler's own error message claiming TypeCode=MATCHINGGIFTSTATUS scoping.
- **Gap identified:** UpdateMatchingGiftStatus.cs resolves the target MasterData row via dbContext.MasterDatas.Where(m => m.DataValue == newCode).Select(m => m.MasterDataId).FirstOrDefaultAsync(...) with no MasterDataType.TypeCode filter and no IsDeleted filter, despite the handler's own error message claiming '(typeCode=MATCHINGGIFTSTATUS)' scoping.
- **Why it's a problem:** Since the same DataValue strings (e.g. "APPROVED") are reused across at least 17 files spanning Grant, ProgramFundingAllocation, BeneficiaryServiceLog, WhatsAppCampaign, and GrantCalendar MasterData, an unscoped FirstOrDefaultAsync can non-deterministically resolve to the wrong MasterDataType's row, or to a soft-deleted row, silently corrupting the matching-gift status.
- **Recommended solution:** Add an explicit join/filter on MasterDataType.TypeCode=="MATCHINGGIFTSTATUS" and IsDeleted==false to the query in UpdateMatchingGiftStatus.cs, matching the scoping the error message already claims, and add a test that seeds duplicate DataValue rows across TypeCodes to prove correct resolution.
- **Production impact:** Matching-gift status updates can non-deterministically set the wrong MasterDataId depending on row ordering/seed data, producing incorrect status in production.
- **Business impact:** Matching gift records could show incorrect Approved/Rejected/Received status, misleading fundraising staff and corporate matching-gift partners about gift state.
- **Technical impact:** An unscoped shared-lookup-table query is a data-integrity landmine that will only manifest once seed data or MasterData rows shift, making it hard to reproduce and diagnose later.
- **Evidence:** PSS_2.0_Backend/.../MatchingGifts/Commands/UpdateMatchingGiftStatus.cs:85-92 (confirmed by direct Read: query has no TypeCode/IsDeleted filter); grep for the literal DataValue "APPROVED" shows it is reused across at least 17 files spanning Grant, ProgramFundingAllocation, BeneficiaryServiceLog, WhatsAppCampaign, GrantCalendar, and MatchingGift MasterData usages.

### #39 · Recurring Donation Schedule — detail drawer, Retry action — Fake recurring-donation retry (no gateway call)  — `Critical`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** payments  |  **Verification:** CONFIRMED
- **Current implementation:** RetryRecurringDonationSchedule is an explicit SERVICE_PLACEHOLDER that fabricates a successful charge outcome (resets failure counters, marks LastChargeStatus=SUCCESS, reactivates the schedule) without ever calling a payment gateway.
- **Gap identified:** RetryRecurringDonationSchedule is an explicitly labeled SERVICE_PLACEHOLDER that fabricates a successful charge (resets ConsecutiveFailures, increments TotalChargedCount, sets LastChargedDate/LastChargeStatus=SUCCESS, flips status to Active) without ever calling a payment gateway.
- **Why it's a problem:** Staff believe a failed recurring donation was successfully retried and charged, when in reality no money moved, producing phantom revenue and false donor communications.
- **Recommended solution:** Integrate PaymentGatewayService (per the existing TODO) so Retry actually attempts a charge against the stored payment token, updates schedule fields only from the real gateway response, and surfaces genuine success/failure to the UI instead of the toast placeholder.
- **Production impact:** Production job/action reports success without any real payment processing, a silent functional gap disguised as working.
- **Business impact:** Overstated recurring-revenue figures and donor trust risk when 'successful' retries never actually collected funds.
- **Technical impact:** Placeholder logic mutating persistent financial state (counters, status, dates) as if real makes the gap invisible without reading source, increasing regression risk during future gateway integration.
- **Evidence:** Base.Application/Business/DonationBusiness/RecurringDonationSchedules/Commands/RetryRecurringDonationSchedule.cs:3-16 (doc comment: 'SERVICE_PLACEHOLDER...simulating a successful charge attempt...TODO: integrate with PaymentGatewayService'); :48-61 (handler body: no gateway call, sets ConsecutiveFailures=0, TotalChargedCount+=1, LastChargedDate=UtcNow, LastChargeStatusId=SUCCESS); PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/recurringdonors/recurring-schedule-detail-drawer.tsx:345 (`toast.info("Retry sent — gateway integration pending.")`).
- **Reviewer note:** Read the full handler and confirmed the FE toast text verbatim — this is a self-documented placeholder that writes success-shaped data with zero real payment collection.

### #40 · Refund (Screen #13) — Create Refund — Refund payment-status resolution  — `Critical`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** CreateRefund.cs resolves the parent donation's payment-status MasterData row by filtering on TypeCode=="DONATIONSTATUS", a TypeCode that is never seeded anywhere in the codebase, while every sibling command (CompleteRefund, PromoteRecurringCycle, CreateChequeDonation, RealizeInKindDonation, ConfirmCrowdFundDonation, InitiateP2PDonation) uses the correct TypeCode=="PAYMENTSTATUS" for the same DataValue="REFUND" lookup.
- **Gap identified:** CreateRefund.cs line 258 resolves the parent-donation payment-status via TypeCode=="DONATIONSTATUS", but that TypeCode is never seeded anywhere in the codebase — every other resolution site (CompleteRefund.cs:198, PromoteRecurringCycle.cs, CreateChequeDonation.cs, RealizeInKindDonation.cs, ConfirmCrowdFundDonation.cs, InitiateP2PDonation.cs, etc.) uses TypeCode=="PAYMENTSTATUS" for the identical DataValue="REFUND" lookup.
- **Why it's a problem:** Because the TypeCode literal does not exist in seed data, the lookup query returns null at runtime, which will either throw an unhandled null-reference/entity-not-found exception or silently fail to set the refund payment status, breaking refund creation in production.
- **Recommended solution:** Change the filter in CreateRefund.cs:258 from TypeCode=="DONATIONSTATUS" to TypeCode=="PAYMENTSTATUS" to match every other resolution site, add a unit test asserting the lookup succeeds, and add a startup/seed-integrity check that fails fast if a referenced TypeCode/DataValue pair is missing from MasterData.
- **Production impact:** Every refund creation attempt will fail or silently corrupt payment-status data as soon as this code path executes against live data.
- **Business impact:** Finance staff cannot reliably process donor refunds, risking incorrect donor records and reconciliation errors.
- **Technical impact:** Introduces a latent runtime null-lookup defect that diverges from the established MasterData resolution pattern used everywhere else in the codebase.
- **Evidence:** PSS_2.0_Backend/.../Refunds/Commands/CreateRefund.cs:253-266 (TypeCode=="DONATIONSTATUS", confirmed by direct Read); PSS_2.0_Backend/.../Refunds/Commands/CompleteRefund.cs:194-206 (same lookup correctly uses TypeCode=="PAYMENTSTATUS"); repo-wide grep for the literal string "DONATIONSTATUS" across the entire backend returns exactly one hit (CreateRefund.cs:258), and no seed file defines that TypeCode anywhere.
- **Reviewer note:** Directly verified: this line will always return null (refundedPaymentStatusId==null), so every CreateRefund call throws BadRequestException("PaymentStatus master data ... is not seeded.") — the feature is dead on arrival exactly as described. No colliding MasterDataType named DONATIONSTATUS exists, so the described silent-FK-corruption secondary risk is currently only theoretical (the raised exception is the actual failure mode), but the core Critical-severity claim (refund creation is non-functional) is fully confirmed.

### #41 · Refund (Screen #13) — Process Refund / gateway integration — Refund gateway processing integration  — `Critical`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** payments  |  **Verification:** ADJUSTED
- **Current implementation:** ProcessRefund.cs only flips RefundStatusId and ProcessingStartedDate behind a documented SERVICE_PLACEHOLDER comment; no code in Base.Application ever calls IPaymentService.RefundAsync, including CreateRefund.cs and CompleteRefund.cs.
- **Gap identified:** No code path anywhere in the Base.Application layer calls IPaymentService.RefundAsync — ProcessRefund.cs contains only a documented SERVICE_PLACEHOLDER comment and flips RefundStatusId/ProcessingStartedDate; CreateRefund.cs and CompleteRefund.cs likewise never invoke it.
- **Why it's a problem:** Refunds are marked as processed/completed in the system of record without any money ever actually being returned through the payment gateway, creating a silent mismatch between application state and real-world cash movement.
- **Recommended solution:** Implement the IPaymentService.RefundAsync call inside ProcessRefund.cs (or a dedicated gateway-invocation step before CompleteRefund), persist the gateway transaction reference/response, and gate RefundStatusId transitions on a successful gateway response rather than only on internal state.
- **Production impact:** Refunds will be recorded as complete in production while the donor never actually receives their money back, since no gateway call is ever made.
- **Business impact:** Donors are told/shown a refund occurred while no funds move, creating trust, compliance, and potential chargeback/dispute exposure for the organization.
- **Technical impact:** The refund status model is decoupled from the actual payment rail, leaving a functional gap that must be closed before this feature can be considered production-ready (documented as a placeholder, not a defect to silently ship).
- **Evidence:** PSS_2.0_Backend/.../Refunds/Commands/ProcessRefund.cs:1-17,64-66 (explicit SERVICE_PLACEHOLDER comment, no gateway call); grep for "IPaymentService"/"RefundAsync(" across Base.Application returns only ProcessRefund.cs's comment lines — zero actual invocations anywhere in the business layer.
- **Reviewer note:** Core claim confirmed: no refund handler ever calls the gateway. However, the finding understates how close the fix is — IPaymentService.RefundAsync (Base.Support/Payment/Services/IPaymentService.cs:17) is a fully implemented method with real provider-level implementations already built for Razorpay (RazorpayProvider.cs:300), PayU India (PayUIndiaProvider.cs:419), and Braintree (BraintreeProvider.cs:145). This is a wiring gap (the plumbing exists end-to-end at the Support layer but was never called from the Application layer's refund commands), not a from-scratch integration project, which changes the remediation effort/estimate though not the Critical priority — until wired, refunds recorded in PSS never move real money.

### #42 · Refund (Screen #13) — reversal integrity vs Pledge and Fund Distribution — Refund reversal of pledge/distribution effects  — `Critical`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** GlobalDonationCompositeWriter.cs applies pledge-fulfillment side effects (stamping PledgePayment.PaidDate/PaidAmount/PaymentStatusId, recomputing Pledge.PledgeStatusId) and populates GlobalDonationDistribution rows only at donation-creation time; the Refunds folder contains zero references to Pledge or GlobalDonationDistribution.
- **Gap identified:** GlobalDonationCompositeWriter.cs contains pledge-fulfillment logic (stamping PledgePayment.PaidDate/PaidAmount/PaymentStatusId, recomputing parent Pledge.PledgeStatusId to FULFILLED/OVERDUE/ONTRACK) and populates GlobalDonationDistribution rows only at donation-creation time; none of this is reversed anywhere in the Refunds folder.
- **Why it's a problem:** When a donation tied to a pledge installment or fund distribution is refunded, none of the pledge-fulfillment or fund-distribution state created at donation time is ever reversed, leaving the pledge and fund books permanently out of sync with the refunded reality.
- **Recommended solution:** Add a reversal step to the refund command chain (CompleteRefund.cs) that reopens/reverts the affected PledgePayment (clearing PaidDate/PaidAmount, resetting PaymentStatusId), recomputes the parent Pledge.PledgeStatusId, and reverses/adjusts the corresponding GlobalDonationDistribution rows proportionally to the refunded amount.
- **Production impact:** Refunding any donation linked to a pledge or fund allocation will leave stale fulfillment and distribution records live in production with no code path to correct them.
- **Business impact:** Pledge status reports and fund allocation/distribution ledgers will overstate fulfilled pledges and distributed funds after refunds, misleading donors, program managers, and auditors.
- **Technical impact:** Creates permanent data-integrity drift between the donation/refund tables and the pledge and fund-distribution tables, since the creation-path side effects have no corresponding compensating transaction.
- **Evidence:** PSS_2.0_Backend/.../GlobalDonations/Services/GlobalDonationCompositeWriter.cs:277-361 (pledge fulfillment + status recompute, creation-path only) and :126-140,234-237 (GlobalDonationDistribution population at creation); grep for "Pledge" and "GlobalDonationDistribution" inside the Refunds/ folder returns zero matches in both cases (directly confirmed).

### #139 · Cheque Donation — Bounce transition — Bounced cheque leaves parent donation unresolved  — `High`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** BounceChequeDonation updates only the child ChequeDonation row's status/bounce fields; it never updates the parent GlobalDonation's PaymentStatusId, ReceiptNumber, DonationAmount, or NetAmount.
- **Gap identified:** BounceChequeDonation only mutates the child ChequeDonation row (ChequeStatusId/ChequeBouncedDate/ChequeBouncedReason/ChequeIsBounced/ChequeIsCleared); it never touches the parent GlobalDonation's PaymentStatusId, ReceiptNumber, DonationAmount, or NetAmount, so a bounced cheque leaves a stale valid-looking receipt and inflated totals.
- **Why it's a problem:** After a cheque bounces, the parent donation record still reflects a valid, paid state with an active receipt number and full amount, contradicting the actual (failed) payment outcome.
- **Recommended solution:** Extend BounceChequeDonation to also update the parent GlobalDonation's PaymentStatusId (e.g., to Bounced/Failed) and either void/flag the ReceiptNumber and zero the NetAmount, or clearly document and enforce that reversal is a separate required follow-up command with its own validation gate.
- **Production impact:** Financial and receipt data becomes inconsistent immediately after a routine bounce transition, with no compensating automated fix.
- **Business impact:** Inflated donation totals and an invalid receipt remain in donor and finance records, risking incorrect tax receipts and revenue overstatement.
- **Technical impact:** Parent/child donation aggregates can silently drift out of sync, and any report joining on GlobalDonation totals will double-count bounced funds as collected.
- **Evidence:** Base.Application/Business/DonationBusiness/ChequeDonations/Commands/BounceChequeDonation.cs (full file read, lines 42-77 — only `cheque.*` fields set, no `dik.GlobalDonation.*` or dbContext.GlobalDonations touch at all); grep for ChequeIsBounced repo-wide found no report/summary query joining on it (only entity/DTO/migration-snapshot declarations).
- **Reviewer note:** Confirmed the handler is entirely scoped to the ChequeDonation child row and that no downstream reporting query currently excludes bounced cheques via this flag.

### #140 · Cheque Donation — entry (both GlobalDonation composite flow and standalone flow) — Cheque uniqueness pre-check missing CompanyId scope  — `High`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** Both the composite-flow and standalone CreateChequeDonation validators run a ChequeNo-uniqueness AnyAsync check without a CompanyId predicate, despite code comments stating the intent is per-company uniqueness; the DB unique index itself IS correctly company-scoped.
- **Gap identified:** Both the composite-flow validator (CreateGlobalDonationWithChildren.cs) and the standalone CreateChequeDonation validator run a ChequeNo-uniqueness pre-check (c.ChequeNo == chequeNo && c.IsDeleted == false) with no CompanyId predicate, despite the accompanying code comment explicitly stating the intent is per-company uniqueness.
- **Why it's a problem:** The application-level pre-check will incorrectly reject a legitimate cheque number that already exists in a different tenant, a false-positive validation failure, even though the database would have allowed it.
- **Recommended solution:** Add the CompanyId predicate to both AnyAsync uniqueness checks (CreateGlobalDonationWithChildren.cs and CreateChequeDonation.cs) so the application check matches the DB's actual per-company unique index.
- **Production impact:** Legitimate cheque donations get blocked with a false uniqueness error across unrelated tenants, a functional annoyance not a data-loss bug.
- **Business impact:** Staff at one NGO tenant may be unable to record a valid cheque simply because a different, unrelated tenant used the same cheque number, causing support friction.
- **Technical impact:** Divergence between application-level validation logic and the DB constraint it's meant to mirror indicates a copy-paste gap that should be caught by a shared validation helper.
- **Evidence:** Base.Application/Business/DonationBusiness/GlobalDonations/Commands/CreateGlobalDonationWithChildren.cs:91-93 (comment: 'Unique: ChequeNo (per Company, not deleted)'), :109-118 (AnyAsync(c => c.ChequeNo == chequeNo && c.IsDeleted == false, ct) — no CompanyId term); Base.Application/Business/DonationBusiness/ChequeDonations/Commands/CreateChequeDonation.cs:70 (comment: 'ChequeNo uniqueness (per Company where IsDeleted=false)'), :71-80 (identical unscoped AnyAsync query). Note: the underlying DB unique index (ChequeDonationConfiguration.cs:81, HasIndex(ChequeNo, IsActive, CompanyId).IsUnique()) IS correctly company-scoped, so the practical risk is an unscoped app-level pre-check incorrectly rejecting legitimate same-number cheques across tenants (false positive), while the DB itself would have permitted it.
- **Reviewer note:** Both validator methods read in full confirm the unscoped query exactly as claimed. The underlying DB unique index is correctly company-scoped, so the actual defect is the FluentValidation pre-check being stricter/mis-scoped relative to the DB constraint it is meant to pre-empt — producing exactly the false-positive cross-tenant blocking the finding describes.

### #141 · Donation Purpose master — Delete — Donation Purpose master delete safeguard  — `High`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** DeleteDonationPurpose.cs's validator only calls ValidatePropertyIsRequired and FindInActiveRecordByProperty, omitting the ValidateNotReferencedInAnyCollection call that sibling masters DeleteDonationCategory.cs and DeleteDonationGroup.cs both explicitly invoke.
- **Gap identified:** DeleteDonationPurpose.cs's validator calls only ValidatePropertyIsRequired + FindInActiveRecordByProperty, with no ValidateNotReferencedInAnyCollection call, unlike its sibling masters DeleteDonationCategory.cs and DeleteDonationGroup.cs which both explicitly call it.
- **Why it's a problem:** A DonationPurpose that is actively referenced by Pledge, ContactDonationPurpose, CampaignDonationPurpose, or OrganizationalUnitDonationPurpose rows (17 referencing files total) can be deleted without any referential-integrity check, orphaning those child records.
- **Recommended solution:** Add the same ValidateNotReferencedInAnyCollection call used in DeleteDonationCategory.cs/DeleteDonationGroup.cs to DeleteDonationPurpose.cs, scoped across all 17 known referencing tables, and add a regression test confirming delete is blocked when references exist.
- **Production impact:** Deleting a Donation Purpose in production can silently orphan pledges, contact/campaign/organizational-unit associations with a now-dangling foreign key reference.
- **Business impact:** Reports and screens that join through DonationPurpose (pledges, campaigns, contact preferences) can break or show missing/null purpose data after such a delete.
- **Technical impact:** Inconsistent enforcement of the referential-integrity guard across sibling master-data delete handlers creates a data-integrity hole not present in the otherwise-identical Category/Group deletes.
- **Evidence:** PSS_2.0_Backend/.../DonationPurposes/Commands/DeleteDonationPurpose.cs:14-25 (confirmed: no ValidateNotReferencedInAnyCollection call); PSS_2.0_Backend/.../DonationCategories/Commands/DeleteDonationCategory.cs:24-29 (confirmed: does call it); grep confirms DonationPurposeId is referenced across 17 files including Pledge.cs, ContactDonationPurpose.cs, CampaignDonationPurpose.cs, OrganizationalUnitDonationPurpose.cs.

### #142 · Receipt (GlobalReceipt) — number generation — Receipt number uniqueness has no DB backstop  — `High`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** GlobalDonationConfiguration defines no unique index (filtered or otherwise) on ReceiptNumber; the column exists with only a max-length constraint, so uniqueness depends entirely on every code path correctly routing through NumberSequenceGenerator.
- **Gap identified:** GlobalDonationConfiguration.cs has no unique index (filtered or otherwise) on ReceiptNumber anywhere in the file, so uniqueness relies entirely on every write path routing through the application-level NumberSequenceGenerator.
- **Why it's a problem:** Any future write path (manual data fix, migration, bulk import, race condition, or a bug in the generator) can create duplicate receipt numbers with no database-level rejection.
- **Recommended solution:** Add a filtered unique index on (CompanyId, ReceiptNumber) WHERE IsDeleted = false in GlobalDonationConfiguration, mirroring the pattern already used for other unique columns like OnlineDonationPageId, and generate the corresponding migration for the user to apply.
- **Production impact:** Data corruption (duplicate receipts) can be introduced by any bypass path without any error thrown.
- **Business impact:** Duplicate receipt numbers undermine tax-receipt legal validity and donor trust, and complicate audits/reconciliation.
- **Technical impact:** Relying solely on application-level enforcement for a uniqueness invariant is fragile against concurrency and future code changes that skip the generator.
- **Evidence:** Base.Infrastructure/Data/Configurations/DonationConfigurations/GlobalDonationConfiguration.cs (full file read, 108 lines) — ReceiptNumber only appears at line 11 (`HasMaxLength(100)`), no `.IsUnique()` call referencing it anywhere in the file's ~15 HasIndex/unique declarations (which do exist for other columns like OnlineDonationPageId, P2PCampaignPageId).
- **Reviewer note:** Confirmed by reading the entire configuration file — the file actively uses HasIndex/IsUnique for several other columns, making the absence for ReceiptNumber a genuine gap rather than an oversight in review.

### #143 · Receipt Book — donation entry (mode=RECEIPTBOOK) — Receipt book serial race condition  — `High`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** data  |  **Verification:** ADJUSTED
- **Current implementation:** GlobalReceiptDonationInventory.ApplyOnCreateAsync performs a plain FirstOrDefaultAsync check-then-act against ReceiptBookTransactions with no row locking, and the underlying ReceiptBookTransaction table has zero indexes or unique constraints on (ReceiptBookId, ReceiptBookNo).
- **Gap identified:** GlobalReceiptDonationInventory.ApplyOnCreateAsync does a plain FirstOrDefaultAsync check-then-act against ReceiptBookTransactions with no row lock and no backstopping DB unique constraint, so two concurrent submissions for the same book+serial can both pass validation before either commits.
- **Why it's a problem:** Two concurrent submissions using the same receipt book and serial number can both pass the check before either commits, resulting in duplicate receipt-book entries with no database safeguard.
- **Recommended solution:** Add a unique index on (ReceiptBookId, ReceiptBookNo) in ReceiptBookTransactionConfiguration to backstop the check, and wrap the check-then-act in a serializable transaction or use a database-level upsert/optimistic-concurrency token to prevent the race.
- **Production impact:** Concurrent submissions in production can create duplicate receipt-book allocations with no error, a classic TOCTOU bug.
- **Business impact:** Duplicate physical receipt-book serials undermine the audit trail for cash/cheque receipt books, a common finance-compliance concern for NGOs.
- **Technical impact:** Check-then-act without a DB constraint is a known concurrency anti-pattern; any load spike or double-submit will silently corrupt inventory tracking.
- **Evidence:** Base.Application/Business/DonationBusiness/GlobalReceiptDonations/Services/GlobalReceiptDonationInventory.cs:51-80 (FirstOrDefaultAsync check, branch on prior status, no locking/transaction hint); Base.Infrastructure/Data/Configurations/FieldCollectionConfigurations/ReceiptBookTransactionConfiguration.cs (full file read — the actual entity used in the race, ReceiptBookTransaction, has ZERO indexes/unique constraints of any kind, commented or otherwise, on ReceiptBookId+ReceiptBookNo).
- **Reviewer note:** Core gap (TOCTOU race, no DB backstop) is real and if anything worse than described — the cited evidence file (GlobalReceiptDonationConfiguration.cs:64) is a commented-out index on a DIFFERENT table's columns (GlobalReceiptDonation.ReceiptBookNo/ReceiptBookSerialNo, the donation child row) which is not the table the race actually occurs against. The table that matters, ReceiptBookTransaction (Base.Infrastructure/Data/Configurations/FieldCollectionConfigurations/ReceiptBookTransactionConfiguration.cs), has no unique index at all — not even a commented one — so the fix should target that configuration file instead of un-commenting the cited line.

### #144 · Recurring Donation — automated charge engine — Recurring charge engine limited to single gateway  — `High`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** payments  |  **Verification:** CONFIRMED
- **Current implementation:** The only automated recurring-charge job, ProcessDuePayUChargesAsync, is scoped exclusively to PAYU schedules, and PaymentMethodToken's expiry/failure-tracking fields (ExpiryMonth, ExpiryYear, TokenExpiresAt, FailureCount) exist on the schema but are never read by any charge logic.
- **Gap identified:** The only automated recurring-charge job (ProcessDuePayUChargesAsync) is scoped exclusively to PAYU gateway schedules; PaymentMethodToken's ExpiryMonth/ExpiryYear/TokenExpiresAt/FailureCount fields exist on the entity/schema but are never read anywhere in Base.Application before a charge attempt.
- **Why it's a problem:** Recurring donations on gateways other than PAYU are never automatically charged, and expired/failing tokens are never proactively detected, so schedules silently stop collecting funds without alerting anyone.
- **Recommended solution:** Either implement gateway-specific charge jobs for Braintree/Razorpay analogous to PayURecurringChargeService, or explicitly document and enforce that those gateways are fully gateway-initiated (webhook-driven) with a corresponding webhook handler; separately, add token-expiry/failure-count checks before charge attempts to proactively flag or pause expiring schedules.
- **Production impact:** Silent revenue collection failure for non-PAYU recurring donors with no automated retry or alerting.
- **Business impact:** Lost recurring donation revenue and no visibility into expiring payment methods, undermining donor retention reporting.
- **Technical impact:** Dead schema fields (ExpiryMonth/Year, FailureCount) that are never consulted indicate incomplete feature implementation, a maintenance trap for future developers assuming they are enforced.
- **Evidence:** Base.Application/Services/RecurringDonations/PayURecurringChargeService.cs:26 ('Braintree/Razorpay recurring is gateway-initiated...and is NOT touched'), :64 (`s.PaymentGateway.PaymentGatewayCode == "PAYU"`); Base.Domain/Models/DonationModels/PaymentMethodToken.cs:15-21 (ExpiryMonth/ExpiryYear/TokenExpiresAt/FailureCount fields); repo-wide grep for these four field names across Base.Application found matches only in the DTO schema file (PaymentMethodTokenSchemas.cs) and in unrelated SocialMedia/AccountingIntegration token-refresh flows — never in any donation-charge business logic.
- **Reviewer note:** Verified the gateway scoping comment/code and ran a targeted grep confirming these fields are never consulted in any charge-eligibility or dunning logic.

### #145 · Refund (Screen #13) — approval control — Refund approval workflow bypass  — `High`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** security  |  **Verification:** ADJUSTED
- **Current implementation:** CreateRefund.cs sets RefundStatusId directly to REF (complete) in the same call that creates the record, guarded only by [CustomAuthorize(..., Permissions.Create)]; the legacy ApproveRefund.cs/RejectRefund.cs/ProcessRefund.cs commands remain in the codebase but the frontend documents them as unreachable for pre-redesign rows only.
- **Gap identified:** CreateRefund.cs sets RefundStatusId directly to REF (complete) in the same call that creates the record, guarded only by [CustomAuthorize(..., Permissions.Create)]; ApproveRefund.cs/RejectRefund.cs/ProcessRefund.cs remain in the codebase but are documented by the FE as unreachable legacy-only paths for pre-redesign rows.
- **Why it's a problem:** Any user holding Refund Create permission can single-handedly create and finalize a completed refund with no second-approver control, removing the segregation-of-duties safeguard that a financial reversal of this kind typically requires.
- **Recommended solution:** Introduce a maker-checker gate for refunds above a configurable threshold (or for all refunds, per policy) by requiring a distinct Approve permission/step before RefundStatusId is set to complete, and either retire or clearly deprecate the now-dead ApproveRefund/RejectRefund/ProcessRefund commands to avoid confusion.
- **Production impact:** A single compromised or careless Create-permission account can finalize financial refunds in production with no approval checkpoint.
- **Business impact:** Lack of segregation of duties on money-reversal transactions is a common audit/compliance finding and increases fraud exposure for the organization.
- **Technical impact:** Dead legacy approval code (ApproveRefund/RejectRefund/ProcessRefund) remains in the codebase alongside the born-complete path, creating maintenance confusion about which workflow is actually authoritative.
- **Evidence:** PSS_2.0_Backend/.../Refunds/Commands/CreateRefund.cs:1-26 (born-complete design, [CustomAuthorize(..., Permissions.Create)]); PSS_2.0_Frontend/.../crm/donation/refund/refund-detail-drawer.tsx:138-139,158,162 (confirmed verbatim: "PEN/APR/PRO are legacy rows (pre-Session-16). No workflow buttons anywhere" / "A completed refund is immutable" / "Legacy workflow — no further actions").
- **Reviewer note:** Core claim fully confirmed via direct file reads: a single Create-permission call now produces a final, money-affecting REF status with no independent review step, and the FE literally labels the old workflow buttons as legacy/unreachable. One factual correction: ApproveRefund.cs is gated by [CustomAuthorize(..., Permissions.Modify)], not a distinct Permissions.Approve as the recommended-solution text implies ("already scaffolded via ApproveRefund.cs" under a separate Approve permission) — there is no dedicated Approve permission today, so reintroducing a gate would also need a new permission, not just re-enabling an existing one.

### #146 · Refund (Screen #13) — Create Refund (partial refund) — Single-refund-per-donation constraint  — `High`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** Refund.cs and RefundConfiguration enforce, via both a validator rule and a filtered unique DB index (IX_Refunds_GlobalDonationId_Active WHERE IsDeleted=false), that at most one non-deleted Refund row may ever exist per GlobalDonationId.
- **Gap identified:** Refund.cs and the RefundConfiguration EF mapping enforce, via both a validator check and a filtered unique DB index (IX_Refunds_GlobalDonationId_Active WHERE IsDeleted=false, IsUnique), that at most ONE non-deleted Refund row can ever exist per GlobalDonationId — permanently blocking a second refund (partial or full) against a donation that already has one partial refund.
- **Why it's a problem:** A donation that has already received one partial refund can never receive a second partial or the remaining full refund, permanently blocking a legitimate multi-step refund workflow.
- **Recommended solution:** Redesign the constraint to allow multiple Refund rows per GlobalDonationId while tracking cumulative refunded amount against DonationAmount (e.g., a running RefundedAmountToDate check instead of a one-row-per-donation index), and replace the unique index with a validator that only blocks refunds exceeding the remaining refundable balance.
- **Production impact:** Finance staff will hit a hard validation/DB-constraint failure the moment they attempt a second refund against any already-partially-refunded donation.
- **Business impact:** Legitimate partial-then-full refund scenarios (common in donor dispute resolution) cannot be completed, forcing manual off-system workarounds and donor dissatisfaction.
- **Technical impact:** The data model conflates 'one refund record' with 'fully refunded,' which is an incorrect invariant for a business process that inherently supports multiple partial refunds against one payment.
- **Evidence:** PSS_2.0_Backend/.../Base.Domain/Models/DonationModels/Refund.cs:16-17 (header: "At most ONE non-deleted Refund per GlobalDonation"); PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/DonationConfigurations/RefundConfiguration.cs:116-120 (unique filtered index); PSS_2.0_Backend/.../Refunds/Commands/CreateRefund.cs:140-149 (validator rule blocking a second insert).

### #147 · Refund (Screen #13) — Receipt handling on refund — Receipt handling on refund  — `High`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** CompleteRefund.cs computes and stores ReceiptStatusAfterRefundId (UNCHANGED/CANCELLED/REVISED) as an informational marker on the Refund row only, with an explicit "ISSUE-V2-3: revised PDF issuance is OUT OF SCOPE" comment; the underlying GlobalReceiptDonation record/PDF is never voided, regenerated, or gated from download.
- **Gap identified:** CompleteRefund.cs computes and stores ReceiptStatusAfterRefundId (UNCHANGED/CANCELLED/REVISED) as an informational marker on the Refund row only; the actual GlobalReceiptDonation record/PDF is never voided, regenerated, or gated from download anywhere in the backend.
- **Why it's a problem:** A donor or auditor can still download the original, unmodified receipt PDF after a refund has been recorded, even when the marker indicates the receipt should be cancelled or revised, because no enforcement exists on the actual receipt artifact.
- **Recommended solution:** Add a gate in the receipt-download/generation path that checks ReceiptStatusAfterRefundId and blocks or replaces CANCELLED/REVISED receipts, and build the deferred revised-PDF regeneration flow (or, at minimum, stamp a visible 'VOID'/'REVISED' watermark) before this reaches production for tax-receipt-issuing tenants.
- **Production impact:** Stale or invalid donation receipts remain fully downloadable in production after a refund, with no technical control preventing their re-issue.
- **Business impact:** Donors could use an invalid tax receipt after a refund, exposing the NGO to compliance and audit risk with tax authorities.
- **Technical impact:** The ReceiptStatusAfterRefundId field is write-only metadata with no consuming logic, giving a false impression that receipt integrity is handled when it is not enforced anywhere downstream.
- **Evidence:** PSS_2.0_Backend/.../Refunds/Commands/CompleteRefund.cs:137-164 (marker-only logic, explicit "ISSUE-V2-3: revised PDF issuance is OUT OF SCOPE" comment); grep for "GlobalReceiptDonation" restricted to any Receipt-generation command path under DonationBusiness returns no matches referencing ReceiptStatusAfterRefund for gating/regeneration.

### #246 · Donation In Kind — legacy standalone flow (Screen #7) vs GlobalDonation-flow DIK — Legacy DIK records unreachable by new Realize lifecycle  — `Medium`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** DIK records created via the legacy standalone flow (CreateDonationInKind) never get ValuationStatusId populated, since that SQL function only sets the old DIKStatusId field, leaving ValuationStatusId permanently NULL.
- **Gap identified:** DIK records created via the legacy standalone flow never get a `ValuationStatusId` populated by the new lifecycle scheme (it stays NULL, since the SQL function only sets the old `DIKStatusId`), so they can never satisfy RealizeInKindDonation's PENDING/ESTIMATED precondition and are permanently unreachable by the new Realize action.
- **Why it's a problem:** RealizeInKindDonation requires ValuationStatusId to be PENDING or ESTIMATED before allowing realization, so legacy-created DIK records can never satisfy this precondition and are permanently stuck outside the new realization lifecycle.
- **Recommended solution:** Add a data backfill (user-run, per migration-ownership policy) that derives and populates ValuationStatusId for existing legacy DIK rows from their current DIKStatusId, and update CreateDonationInKind's SQL function to also set ValuationStatusId going forward so new legacy-flow records stay compatible.
- **Production impact:** A subset of existing donation records become permanently unmanageable through the current UI's Realize action, a silent functional dead-end.
- **Business impact:** In-kind donations entered before the lifecycle redesign can never be marked as realized/distributed, leaving valuation reporting incomplete for those records.
- **Technical impact:** Two parallel code paths (legacy SQL function vs new composite writer) writing to the same entity without a shared field-population contract is a maintainability risk that will recur with future schema evolution.
- **Evidence:** Base.Application/Business/DonationBusiness/DonationInKinds/Commands/CreateDonationInKind.cs:70-120; Base.Application/Business/DonationBusiness/DonationInKinds/Commands/RealizeInKindDonation.cs:76-81.
- **Reviewer note:** not adversarially verified (Medium/Low)

### #247 · Pledge — installment payment — Pledge installment partial payment  — `Medium`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** GlobalDonationCompositeWriter.cs enforces a strict-pay rule requiring PaidAmount to exactly equal the installment's DueAmount, with no code path that accepts a lesser amount and carries the remainder forward as still due.
- **Gap identified:** A donor cannot pay less than the full scheduled installment amount in a single donation — there is no code path that accepts a partial amount toward one PledgePayment row and carries the remainder forward as still-due.
- **Why it's a problem:** Donors who wish to pay less than a scheduled installment amount (a common real-world occurrence) cannot do so through the system at all, forcing staff to either reject the payment or record it incorrectly against the full due amount.
- **Recommended solution:** Extend GlobalDonationCompositeWriter.cs to support partial installment payments by allowing PaidAmount < DueAmount, tracking a running RemainingDueAmount on PledgePayment, and only marking the installment fully paid once cumulative payments meet or exceed DueAmount.
- **Production impact:** No crash risk, but any attempt to record a partial installment payment in production will be rejected by validation, blocking a legitimate donor transaction.
- **Business impact:** Donors cannot make partial pledge payments, which may reduce overall pledge fulfillment and donor goodwill for organizations that need flexible payment plans.
- **Technical impact:** The strict-equality rule is a rigid business constraint baked into the composite writer that will require a schema/logic change (remaining-balance tracking) to relax, not a simple validation tweak.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/GlobalDonations/Services/GlobalDonationCompositeWriter.cs:~315-318 ('strict-pay rule': PaidAmount must equal installment DueAmount).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #248 · Pledge — write-off — Pledge write-off capability  — `Medium`

- **Module:** Fundraising · Donations & Receipts  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** The Pledge domain has no write-off status, command, or field of any kind — only a Cancel transition exists in CancelPledge.cs; a repo-wide search for write-off terminology returns zero matches.
- **Gap identified:** A repo-wide grep for 'WRITEOFF|WRITE_OFF|WrittenOff|WriteOff' across the entire backend returns zero matches. There is no write-off status, command, or field anywhere in the Pledge domain — only Cancel exists.
- **Why it's a problem:** Uncollectible pledges (donor default, bad debt) have no correct business classification available — staff must either leave them open indefinitely or misuse Cancel, which does not represent the same accounting/financial meaning as a write-off.
- **Recommended solution:** Add a WriteOffPledge command with its own PledgeStatusId (WRITTENOFF), required reason/justification and approval capture, and ensure pledge reporting/aging dashboards exclude written-off pledges from outstanding-receivable totals distinctly from cancelled ones.
- **Production impact:** No functional break today, but finance cannot correctly close out uncollectible pledges in the system, forcing manual workarounds outside the application.
- **Business impact:** Pledge aging and outstanding-receivable reports overstate collectible pledges since bad debt cannot be distinctly recorded, distorting fundraising financial reporting.
- **Technical impact:** Missing status/state in the Pledge lifecycle model leaves an incomplete state machine relative to standard NGO fundraising/accounting practice.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/Pledges/Commands/CancelPledge.cs:40-78 (only Cancel transition exists); repo-wide grep for WRITEOFF/WriteOff patterns returns no results.
- **Reviewer note:** not adversarially verified (Medium/Low)

## Administration / System Configuration

### #1 · Administration > Role Management > Role x Capability Matrix (Tab 3, bulk save) — Role-Capability Matrix Tenant Scoping  — `Critical`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** BulkUpdateRoleCapabilityMatrix loads the target RoleId without validating it belongs to the caller's tenant/company, and only guards against revoke actions — grants of any capability (including USER:Delete) to a role the caller controls are unrestricted; the command also lacks a top-level CompanyId so the pipeline's tenant-isolation check never runs.
- **Gap identified:** Confirmed exactly as claimed: RoleId ownership is never validated against the caller's tenant before being used as an UPSERT target for RoleCapability rows, and there is no bound on which capabilities a ROLECAPABILITY:Modify holder can grant to a role they control (self-escalation to any capability, e.g. USER:Delete, in their own tenant is unrestricted). The command also has no top-level CompanyId property so, as with Finding 1, TenantIsolationBehavior's reflection check does not fire for it.
- **Why it's a problem:** A user holding only ROLECAPABILITY:Modify can escalate privileges within their own tenant by granting themselves or their role any capability, and because the command isn't tenant-scoped, cross-tenant role IDs could theoretically be targeted with no isolation check firing.
- **Recommended solution:** Add CompanyId to the command DTO so TenantIsolationBehavior's reflection check fires; add an explicit server-side ownership check that the RoleId belongs to the caller's CompanyId before UPSERT; introduce a capability allow-list/ceiling (e.g. cannot grant a capability the caller doesn't already hold) alongside the existing revoke-only guard; add audit logging for the grant path (currently TODO).
- **Production impact:** Exploitable privilege-escalation path in a live multi-tenant deployment with no compensating control.
- **Business impact:** A single compromised or malicious tenant admin account can grant itself destructive capabilities (e.g. delete users), creating compliance and data-loss exposure across the tenant.
- **Technical impact:** Breaks the tenant-isolation invariant relied on by every other CQRS command via reflection-based CompanyId detection, and removes the intended authorization boundary between capability grant and revoke.
- **Evidence:** Base.Application/Business/AuthBusiness/RoleCapabilities/Commands/BulkUpdateRoleCapabilityMatrix.cs lines 53-57 (unscoped role load) vs line 159 (scoped read-side load); lines 59-69 (only guard, revoke-only); lines 122 & 131 (audit TODOs); grep confirms zero HasQueryFilter usage anywhere in Base.Infrastructure

### #2 · Administration > User Management > Assign User Roles — User role/company assignment tenant guard  — `Critical`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** AssignUserRoles.cs has no server-side check preventing assignment of an arbitrary RoleId (including SUPERADMIN) or arbitrary CompanyId; the global TenantIsolationBehavior only guards commands exposing a top-level CompanyId property via reflection, which AssignUserRolesCommand does not have (its only property is the nested assignUserRoles DTO), so the behavior silently no-ops, and there is no EF HasQueryFilter providing automatic tenant scoping on Role/UserRole.
- **Gap identified:** Confirmed: no server-side check exists anywhere in this file (or in any pipeline behavior that runs before it) preventing assignment of an arbitrary RoleId (including SUPERADMIN) or an arbitrary CompanyId. I traced the global MediatR TenantIsolationBehavior (Base.Application/Behaviors/TenantIsolationBehavior.cs) which is the only cross-cutting tenant guard in the codebase: it uses reflection to look for a top-level `CompanyId` PROPERTY on the command object itself (line 102, `requestType.GetProperty("CompanyId")`). AssignUserRolesCommand's only property is `assignUserRoles` (a nested DTO) — it has no top-level CompanyId property — so this behavior's ValidateTenantMatch silently no-ops for this command. Confirmed via grep there is also no EF HasQueryFilter anywhere in the backend, so DbSet<Role>/DbSet<UserRole> impose no automatic tenant scoping. Compared directly against DeleteRole.cs (lines 33-37) which explicitly special-cases `role.IsSystem` and `RoleCode=="SUPERADMIN"` — proving this guard pattern exists elsewhere and was simply omitted here.
- **Why it's a problem:** Any caller with access to this endpoint can assign themselves or another user the SUPERADMIN role, or assign roles across a different tenant's CompanyId, completely bypassing the tenant-isolation and privilege-escalation guard that DeleteRole.cs demonstrates is the established pattern elsewhere in the codebase.
- **Recommended solution:** Add an explicit server-side check in AssignUserRoles.cs mirroring DeleteRole.cs's pattern — reject assignment of any role where IsSystem or RoleCode=="SUPERADMIN" unless the caller is themselves a super-admin, and validate the target CompanyId against the caller's tenant context — and extend TenantIsolationBehavior (or add a dedicated validator) to handle nested-DTO commands, not just top-level CompanyId properties.
- **Production impact:** A live privilege-escalation and cross-tenant data-access vulnerability exists in production today, exploitable by any authenticated user who can reach this command.
- **Business impact:** A malicious or compromised user account could grant itself SUPERADMIN access or assign roles into another customer's tenant, a severe multi-tenant SaaS security and contractual-isolation breach.
- **Technical impact:** Exposes a systemic gap in the cross-cutting tenant-isolation behavior (reflection-based, top-level-property-only) that likely affects any other command using a nested-DTO shape, not just this one.
- **Evidence:** Base.Application/Business/AuthBusiness/UserRoles/Commands/AssignUserRoles.cs lines 4, 16, 40-57; Base.Application/Behaviors/TenantIsolationBehavior.cs lines 86-144 (reflection-based CompanyId check that does not fire for this command's shape); Base.Application/Business/AuthBusiness/Roles/Commands/DeleteRole.cs lines 33-37 (comparison pattern that IS applied elsewhere)

### #3 · Audit Trail — Audit log durability / at-least-once delivery  — `Critical`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** Audit rows are queued into a bounded in-memory Channel (10,000 capacity, DropOldest) drained by a background hosted service; failed DB batch writes are logged and discarded, and any unflushed rows beyond a 5-second shutdown window are dropped.
- **Gap identified:** Audit writes go into a bounded in-memory Channel (capacity 10,000, DropOldest) drained by a background hosted service; any batch DB write failure is logged and the batch dropped, and any remainder at shutdown beyond a 5s window is dropped.
- **Why it's a problem:** There is no outbox table, durable local buffer, or alerting, so under load spikes, DB outages, or ordinary process restarts/deploys, audit rows are silently and permanently lost with only a log line as evidence.
- **Recommended solution:** Introduce a durable outbox table (or persisted queue) that the drainer reads from with at-least-once semantics and idempotent dedup (AuditEventId + UNIQUE constraint, per the code's own ISSUE-17 reference); add retry-with-backoff on batch failure and a metric/alert on drop counts and channel saturation.
- **Production impact:** Deploys, restarts, or transient DB blips will cause silent gaps in the audit trail with no operational alert.
- **Business impact:** Compliance and forensic investigations (financial fraud, data-access disputes, donor complaints) may find missing audit records exactly when they matter most.
- **Technical impact:** Audit data integrity is best-effort, not guaranteed, undermining any claim of a reliable audit trail as a system-of-record.
- **Evidence:** Base.Infrastructure/Services/AuditQueue.cs:26-31 (bounded channel `Channel.CreateBounded<AuditLog>(new BoundedChannelOptions(10_000){ FullMode = BoundedChannelFullMode.DropOldest })`) and lines 43-52 (dropped-count warning on write failure). Base.Infrastructure/HostedServices/AuditQueueDrainer.cs:23-25 (doc comment explicitly states 'a failed batch is logged and dropped... For at-least-once semantics, see ISSUE-17 (AuditEventId + UNIQUE dedup)'), lines 99-104 (PersistBatchAsync catch logs 'Rows dropped' and swallows the exception with no retry/alert), and lines 66-81 (final shutdown drain capped at 5 seconds, logs 'Remaining buffered rows dropped' on incomplete flush). All confirmed verbatim by direct file read — no outbox table, no durable local buffer, no alerting beyond log lines.

### #4 · Company Settings — Security tab — Security Settings Runtime Enforcement  — `Critical`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** The 8 Company Settings Security-tab fields (SESSION_TIMEOUT, MAX_LOGIN_ATTEMPTS, TWO_FACTOR_AUTH, PASSWORD_MIN_LENGTH, PASSWORD_EXPIRY_DAYS, PASSWORD_HISTORY_COUNT, AUDIT_TRAIL_RETENTION, DELETED_RECORDS_RETENTION_DAYS) are fully persisted and validated on save, but IOrgSettingsService is never referenced anywhere in AuthBusiness or the Auth mutations, and AuthendicationMutations hardcodes the lockout threshold at 5 regardless of MAX_LOGIN_ATTEMPTS.
- **Gap identified:** The 8 Security-tab settings (SESSION_TIMEOUT, MAX_LOGIN_ATTEMPTS, TWO_FACTOR_AUTH, PASSWORD_MIN_LENGTH, PASSWORD_EXPIRY_DAYS, PASSWORD_HISTORY_COUNT, AUDIT_TRAIL_RETENTION, DELETED_RECORDS_RETENTION_DAYS) are fully persisted/validated but have zero runtime consumer.
- **Why it's a problem:** Every security setting an admin configures on this tab is cosmetic — none of it changes actual login/session/password behavior, giving organizations false confidence that their configured security posture is enforced.
- **Recommended solution:** Wire each setting to its consumer: read MAX_LOGIN_ATTEMPTS in the lockout check, PASSWORD_MIN_LENGTH/EXPIRY_DAYS/HISTORY_COUNT in password-set paths, SESSION_TIMEOUT into JWT/session expiry, and AUDIT_TRAIL_RETENTION/DELETED_RECORDS_RETENTION_DAYS into the relevant retention/cleanup jobs, following the same IOrgSettingsService pattern already used by Donation/Currency/Membership modules.
- **Production impact:** An entire configuration screen ships with zero runtime effect, a critical gap discovered only in production incident review or audit.
- **Business impact:** Organizations cannot actually enforce password policy, session timeout, or lockout thresholds they believe they've configured, exposing them to compliance and security audit failures.
- **Technical impact:** Configuration and enforcement layers are fully disconnected, requiring a systemic wiring effort across Auth, session, and retention subsystems.
- **Evidence:** UpdateCompanySettings.cs:87-97 and 218-228 (ParamCatalog + Upsert calls for all 8 settings) confirmed by direct read. Grep of `IOrgSettingsService` across the whole Base.* tree returned exactly 30 files (Donation/Currency/Membership/EventRegistration/Grant modules) — none under AuthBusiness or Auth Mutations. A second, independent grep for the underlying MasterData property names (LoginAttemptsBeforeLock, PasswordMinLength, PasswordExpiryDays, AutoLogoutMinutes, TwoFactorAuthMode) across Base.API and Base.Application/Business/AuthBusiness returned zero matches anywhere outside the settings-definition files themselves. AuthendicationMutations.cs:70 hardcodes `>= 5` independent of MAX_LOGIN_ATTEMPTS.

### #5 · Login / Authentication — Account Lock/Expiry Bypass on Login  — `Critical`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** On successful password verification, the Login handler unconditionally clears IsLocked and FailedLoginCount without first checking whether the account is currently locked, and GetUserCredential.cs (using IgnoreQueryFilters) filters only on IsActive/IsDeleted — never on IsLocked or AccountExpiresAt.
- **Gap identified:** On successful password verification, the handler unconditionally clears IsLocked and FailedLoginCount before checking whether the account was locked, and never checks AccountExpiresAt at all.
- **Why it's a problem:** A locked-out account (e.g. after 5 failed attempts) or one past its AccountExpiresAt date can still log in successfully with the correct password, since neither condition is ever checked before token issuance.
- **Recommended solution:** In GetUserCredential/AuthendicationMutations, add explicit checks that reject login when IsLocked==true or AccountExpiresAt has passed, returning a clear error before password verification proceeds further; only clear IsLocked/FailedLoginCount after confirming the account was eligible to authenticate.
- **Production impact:** Account lockout and expiry are effectively non-functional security controls in production, silently bypassed on every successful login attempt.
- **Business impact:** Regulatory/compliance failure for organizations relying on account lockout and time-boxed access (e.g. temporary staff, contractors) as a security control.
- **Technical impact:** Core authentication invariant (locked/expired accounts cannot authenticate) is broken, undermining the credibility of the entire login security model.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Auth/Mutations/AuthendicationMutations.cs:70-73 (hardcoded `>= 5` lock threshold, sets IsLocked=true/LockedAt) and lines 138-144 (success branch unconditionally does `successUser.FailedLoginCount = 0; successUser.IsLocked = false;` with zero prior check of IsLocked). Confirmed further: GetUserCredential.cs (Business/AuthBusiness/Users/Queries/GetUserCredential.cs) fetches the user with `.IgnoreQueryFilters()` and filters only on `IsActive`/`IsDeleted` — no IsLocked or AccountExpiresAt predicate anywhere in the query or handler, so a locked/expired account's password is verified and a token issued exactly as for a normal account.

### #6 · Login / User Management — Two-Factor Authentication — Two-Factor Authentication Enforcement  — `Critical`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** IsTwoFactorEnabled/TwoFactorMethod (User entity) and TWO_FACTOR_AUTH (Company Settings) exist as persisted schema/DTO fields, but no OTP/TOTP generation, delivery, or verification code exists anywhere, and the Login mutation goes directly from password verification to token issuance with no second-factor step.
- **Gap identified:** IsTwoFactorEnabled/TwoFactorMethod (User entity) and TWO_FACTOR_AUTH (Company Settings) exist as persisted/validated fields with zero OTP/TOTP generation, delivery, or verification implementation, and no second-factor step in the Login mutation.
- **Why it's a problem:** Two-factor authentication is presented as a configurable feature but is entirely non-functional — enabling it in settings provides no actual additional authentication step, misleading admins about their account security posture.
- **Recommended solution:** Implement an OTP/TOTP service (generation, time-window verification, delivery via email/SMS) and add a second-factor branch in the Login mutation gated on IsTwoFactorEnabled/TWO_FACTOR_AUTH, returning an intermediate challenge token before issuing the full JWT.
- **Production impact:** A named, configurable security feature ships as a stub, with no code path enforcing it — this is a feature-completeness gap, not just a bug.
- **Business impact:** Organizations that require 2FA for compliance (donor-data protection, financial controls) cannot actually achieve it despite the setting appearing available.
- **Technical impact:** Missing entire authentication subsystem (OTP generation/verification/delivery) that the schema and settings layer already assume exists, requiring net-new implementation work, not a fix.
- **Evidence:** Grep 'TwoFactor|GenerateOtp|VerifyOtp|TOTP' across Base.* matched 138 files but on inspection these are exclusively: EF migration snapshots/designers (schema history), Base.Domain/Models/AuthModels/User.cs (entity field), Base.Application/Schemas/AuthSchemas/UserSchemas.cs (DTO), Base.Infrastructure/Data/Configurations/AuthConfigurations/UserConfiguration.cs (EF config), and the CompanySettings schema/validator/handler chain. No handler, service, or controller implements OTP generation/verification; AuthendicationMutations.cs Login flow (read in full, lines 45-180) goes directly from password verification to token issuance with no second-factor branch of any kind.

### #88 · Administration > Menu Management — Menu Row Protection for System-Critical MenuCodes  — `High`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** Menu Management allows any admin with Menu:Modify/Delete to rename or delete a Menu row whose MenuCode matches a hardcoded DecoratorAuthModules constant (e.g. ROLECAPABILITY, USERROLE); UpdateMenu/DeleteMenu enforce no MenuCode immutability and only a HAS_CHILDREN guard, and the Menu entity has no IsSystem/IsProtected flag.
- **Gap identified:** Confirmed exactly as claimed: nothing stops an admin with Menu:Modify/Menu:Delete from renaming or deleting the Menu row whose MenuCode matches a DecoratorAuthModules constant (e.g. "ROLECAPABILITY", "USERROLE"), which would break HasAccessAsync's join for that entire admin area, fail-closed, for every user including SuperAdmins (since HasAccessAsync's join has no SuperAdmin bypass — it requires an actual matching Menu+RoleCapability+HasAccess row-set regardless of role).
- **Why it's a problem:** HasAccessAsync's join has no SuperAdmin bypass, so breaking a system MenuCode fail-closes the entire dependent admin area for every user including SuperAdmins, effectively locking the tenant out of its own administration screens.
- **Recommended solution:** Add an IsSystem/IsProtected boolean to the Menu entity, seed it true for rows matching DecoratorAuthModules constants, and reject UpdateMenu/DeleteMenu when IsSystem is true (block MenuCode rename and deletion); alternatively hardcode a server-side denylist check against DecoratorAuthModules values.
- **Production impact:** A single accidental admin action can produce a full lockout of critical admin screens with no fail-safe or SuperAdmin override to recover.
- **Business impact:** Operational outage requiring direct database intervention to restore admin access, risking extended downtime for the affected tenant.
- **Technical impact:** No safeguard between UI-configurable metadata (Menu rows) and hardcoded authorization-join keys (DecoratorAuthModules constants), coupling runtime security to unprotected admin data.
- **Evidence:** Base.Application/Extensions/DecoratorProperties.cs lines 59-68; Base.Domain/Models/AuthModels/Menu.cs (full file read, no IsSystem/IsProtected/IsLocked field); Base.Application/Business/AuthBusiness/Menus/Commands/UpdateMenu.cs lines 13-134 (no MenuCode immutability rule); Base.Application/Business/AuthBusiness/Menus/Commands/DeleteMenu.cs lines 32-77 (only HAS_CHILDREN guard)

### #89 · Administration > Role Management (Tab 3 matrix) / Menu Management / Capability Management — status toggle actions — RoleCapability IsActive Toggle Enforcement  — `High`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** ToggleRoleCapabilityStatus flips the IsActive flag on a RoleCapability row, but HasAccessAsync's authorization query only filters on HasAccess==true and never inspects IsActive, so the toggle has no effect on actual access decisions; no frontend code even calls this mutation.
- **Gap identified:** Confirmed precisely as claimed: toggling IsActive on a RoleCapability (or, by the same pattern, a Menu/Capability) has zero effect on server-side authorization decisions since HasAccessAsync never inspects that field. Also confirmed no FE reference exists to this mutation (grepped Frontend for ToggleRoleCapability / toggleRoleCapabilityStatus, case-insensitive — zero matches), matching the claim that it's currently unwired.
- **Why it's a problem:** Admins believe they are disabling a role's capability via the toggle, but the capability remains fully functional, creating a false sense of security and an orphaned, unused feature.
- **Recommended solution:** Add an `rc.IsActive == true` predicate to both HasAccessAsync overloads in CustomAuthorizeService so the flag is actually enforced, or remove the toggle/field entirely if it is not meant to be operational; wire the FE control if the feature is intended to ship.
- **Production impact:** A control surfaced in the admin UI (or planned for it) silently does nothing, risking an admin's mistaken belief that access was revoked.
- **Business impact:** Compliance/audit findings if an organization relies on this toggle to demonstrate access-revocation controls that do not actually function.
- **Technical impact:** Dead/misleading authorization state field with no read-path consumer, increasing maintenance confusion and audit-trail inaccuracy.
- **Evidence:** Base.Application/Business/AuthBusiness/RoleCapabilities/Commands/ToggleRoleCapabilityStatus.cs lines 23-56; Base.Application/Security/CustomAuthorizeService.cs lines 14-71 (both HasAccessAsync overloads, only rc.HasAccess==true predicate, no IsActive/IsDeleted anywhere in file); grep of PSS_2.0_Frontend for ToggleRoleCapability/toggleRoleCapabilityStatus returned no matches

### #90 · Login / Authentication — JWT Expiry vs Reported Session Length  — `High`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** The signed JWT's `exp` claim is set to UtcNow+1 day in AuthExtensions.cs, but the ExpiresIn value returned to the client in TokenResponseDto is a hardcoded ~900 seconds (15 minutes) computed independently, and neither reads the SESSION_TIMEOUT company setting.
- **Gap identified:** The signed JWT `exp` claim is set to UtcNow+1 day, but the ExpiresIn value returned to the client is a hardcoded ~900 seconds (15 minutes), and neither reads the SESSION_TIMEOUT company setting.
- **Why it's a problem:** The client believes the session expires in 15 minutes and may schedule refresh/logout logic accordingly, while the token itself actually remains valid for 24 hours, creating a mismatch between perceived and actual session length and bypassing the configurable SESSION_TIMEOUT entirely.
- **Recommended solution:** Compute both the JWT `exp` claim and the ExpiresIn response value from the same source, driven by the SESSION_TIMEOUT company setting (falling back to a sane default), so client-side and server-side session length always agree.
- **Production impact:** Client-side session/idle-timeout logic operates on incorrect assumptions, potentially leaving sessions valid far longer than the UI implies.
- **Business impact:** Organizations configuring a short SESSION_TIMEOUT for compliance get no actual reduction in token validity, undermining a stated security control.
- **Technical impact:** Two independently hardcoded expiry values in the same auth flow, disconnected from the configurable setting, is a maintainability and correctness defect.
- **Evidence:** Base.Application/Extensions/AuthExtensions.cs:89 `Expires = DateTime.UtcNow.AddDays(1)` inside the SecurityTokenDescriptor used to sign the JWT, vs line 109 `ExpiresIn = (int)(DateTime.UtcNow.AddMinutes(15) - DateTime.UtcNow).TotalSeconds` returned in TokenResponseDto — both values confirmed verbatim by direct file read; no reference to SESSION_TIMEOUT/AutoLogoutMinutesId anywhere in this file.

### #91 · User Management — Create/Update/Reset Password — Password Strength & History Validation  — `High`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** CreateUser.cs only validates that Password is non-null/required; UpdateUser.cs hashes and saves any non-null password string with no length, character-class, or history check, matching the finding that PASSWORD_MIN_LENGTH/REQUIRE_*/HISTORY_COUNT settings have no reader.
- **Gap identified:** No length/character-class/history validation on any password-setting path; UpdateUser.cs accepts any non-null password string, hashes it, and saves.
- **Why it's a problem:** Users can set trivially weak passwords (e.g. single character) or reuse a previously compromised password, since none of the configured password-policy settings are enforced at any password-setting entry point.
- **Recommended solution:** Add a shared password-policy validator invoked from CreateUser, UpdateUser, ResetUserPassword, and BulkResetPasswords that reads PASSWORD_MIN_LENGTH/complexity rules from IOrgSettingsService and checks PASSWORD_HISTORY_COUNT against a stored password-history table before accepting a new hash.
- **Production impact:** Weak-password accounts are createable/updatable in production with no server-side guardrail, widening the credential-stuffing/brute-force attack surface.
- **Business impact:** Fails to meet baseline password-policy compliance expectations for an NGO SaaS handling donor and beneficiary data.
- **Technical impact:** Password-setting code paths are inconsistent with the persisted policy settings, meaning the settings schema exists purely as unenforced configuration.
- **Evidence:** CreateUser.cs:21 `ValidatePropertyIsRequired(x => x.user.Password);` — no other password rule. UpdateUser.cs:56-61 confirmed by direct read: `if (command.user.Password != null) { AuthExtensions.CreatePasswordHash(command.user.Password, out ...); user.PasswordHash = passwordHash; user.PasswordSalt = passwordSalt; }` with zero length/complexity/history check before hashing. Consistent with Finding #2's IOrgSettingsService grep showing PASSWORD_MIN_LENGTH/REQUIRE_*/HISTORY_COUNT settings have no reader anywhere.

### #92 · User Management — Reset Password / Bulk Reset Password / Send Invite — Cryptographically Weak Temp Password Generation  — `High`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** GenerateTempPasswordHelper.Generate() uses `new Random()`, a non-cryptographic PRNG, to select each character of temporary passwords, and is shared across SendUserInvite, ResetUserPassword, and BulkResetPasswords, in contrast to AuthExtensions.cs's own GenerateSalt()/GenerateRefreshToken() which correctly use RandomNumberGenerator.
- **Gap identified:** GenerateTempPasswordHelper.Generate() uses `new Random()` (non-cryptographic PRNG) to pick each character of the temp password, shared by 3 commands.
- **Why it's a problem:** System.Random is seeded predictably and is not suitable for security-sensitive values; temp passwords generated this way are more susceptible to prediction/brute-forcing than the rest of the auth system's cryptographic primitives, especially across bulk-reset operations generating many passwords in quick succession.
- **Recommended solution:** Replace `new Random()` in GenerateTempPasswordHelper with System.Security.Cryptography.RandomNumberGenerator (matching the pattern already used in AuthExtensions.GenerateSalt/GenerateRefreshToken) for all three consuming commands.
- **Production impact:** Every invite/reset/bulk-reset temp password issued in production uses a weaker RNG than the rest of the security-sensitive code in the same codebase.
- **Business impact:** Increases risk of account takeover via predictable temporary credentials during onboarding or password-reset workflows.
- **Technical impact:** Inconsistent RNG usage across the auth module (crypto-secure vs non-secure) is both a security weakness and a code-quality inconsistency needing a single fix propagated to 3+ call sites.
- **Evidence:** Business/AuthBusiness/Users/Commands/GenerateTempPassword.cs:12 `var random = new Random();` used at line 14 `s[random.Next(s.Length)]` to build the temp password. Confirmed by grep that GenerateTempPasswordHelper is consumed by exactly 3 other commands: SendUserInvite.cs, ResetUserPassword.cs, BulkResetPasswords.cs (plus its own file) — matching the claim of a single shared helper used across the reset/invite flows. Contrasts with AuthExtensions.cs's own GenerateSalt()/GenerateRefreshToken() which correctly use RandomNumberGenerator.

### #191 · Administration > Login / Session (JWT issuance) — cross-cutting to all RBAC-protected screens — JWT Revocation Latency for SuperAdmin/Role Claims  — `Medium`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** The JWT carries IsSuperAdmin and CurrentCompanyRoles as claims with a 24-hour expiry (AddDays(1)), and TenantContext trusts these claims without a live re-check against the database for the lifetime of the token.
- **Gap identified:** If an admin revokes a user's SuperAdmin flag or removes them from a role/company mid-session (e.g. during an active security incident, offboarding, or role correction), that change has no effect on the user's authorization for up to 24 hours — the user's existing JWT keeps asserting the old IsSuperAdmin/CurrentCompanyRoles values, and TenantContext trusts them without a live check. This directly undermines the RBAC screen's core promise ("revoke access = access revoked") for the SuperAdmin/tenant-role dimension, even though the RoleCapability dimension is correctly live-checked.
- **Why it's a problem:** Revoking a user's SuperAdmin flag or role/company membership mid-session has no effect until the token expires, so 'revoke access = access revoked' does not hold for up to 24 hours — a serious gap during security incidents or offboarding.
- **Recommended solution:** Shorten JWT lifetime (align with the already-correct 15-minute ExpiresIn value) and rely on refresh-token rotation for session continuity, or add a lightweight server-side revocation check (e.g. a token-version/claims-hash column checked on each request) so role/SuperAdmin changes take effect immediately without waiting for expiry.
- **Production impact:** During an active incident (compromised account, terminated employee), access cannot be revoked in real time, extending the exposure window by up to a day.
- **Business impact:** Undermines offboarding and incident-response compliance commitments made to NGO customers regarding immediate access revocation.
- **Technical impact:** Stale authorization claims trusted client-side for the token's full lifetime, decoupled from the correctly live-checked RoleCapability dimension, creating an inconsistent security model.
- **Evidence:** Base.Application/Extensions/AuthExtensions.cs line 62 (IsSuperAdmin claim), line 89 (Expires = AddDays(1)), line 109 (ExpiresIn = AddMinutes(15) computation disconnected from line 89's Expires)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #192 · Audit Trail — Non-forensic audit rows for workflow approvals  — `Medium`

- **Module:** Administration / System Configuration  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** AuditEventPipelineBehavior's workflow branch hardcodes entityId to 0 (with a comment stating it's not extractable at the pipeline level without reflection) and the export branch hardcodes recordCount to 0, so Approve*/Reject*/Submit* commands audit only that an action occurred and by whom, not which record.
- **Gap identified:** Any Approve*/Reject*/Submit* command that does not additionally make its own explicit, entity-ID-aware audit call produces an audit row that records that SOME approval/rejection happened, by whom, but not which record — making the audit trail forensically unusable for exactly the workflow-transition category (approvals) most likely to require traceability (e.g., grant approvals, case approvals).
- **Why it's a problem:** Approvals are precisely the workflow category (grant approvals, case approvals) where knowing which specific record was approved/rejected is essential; a generic audit row without an entity ID is forensically useless for reconstructing what happened.
- **Recommended solution:** Extend the pipeline behavior to extract the entity ID from the command/response via a lightweight marker interface (e.g., IHasAuditableEntityId) implemented by each Approve/Reject/Submit command, rather than relying on reflection; do the same for export record counts.
- **Production impact:** Any audit-driven investigation into an approval decision cannot pinpoint the affected record from the audit log alone.
- **Business impact:** Grant and case approval workflows — high-stakes financial/programmatic decisions — lack traceable, defensible audit records for compliance reviews.
- **Technical impact:** Audit rows across an entire category of workflow transitions are structurally incomplete, requiring cross-referencing with other logs to reconstruct events.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Common/Behaviors/AuditEventPipelineBehavior.cs (workflow branch hardcodes `entityId: 0` with comment 'EntityId not extractable at pipeline level without reflection'; export branch hardcodes `recordCount: 0`)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #193 · Company Settings — Security tab (Audit/Retention) — Audit/data retention settings have no enforcement  — `Medium`

- **Module:** Administration / System Configuration  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** Company Settings exposes audit/retention configuration fields, but no hosted service, background job, or scheduled task purges data per those settings; the only related artifact is a static, non-executing SQL script.
- **Gap identified:** No runtime job, hosted service, or scheduled task implements retention/purge for either setting. A search of Base.Infrastructure/HostedServices and Base.Infrastructure/Jobs for 'Retention'/'Purge' found no runtime implementation; the only related artifact is a static SQL script (sql-scripts-dyanmic/RetentionDashboard-sqlscripts.sql), not an executing job.
- **Why it's a problem:** Configuring a retention period gives administrators a false sense that old data is being purged, when in practice nothing enforces it, so data accumulates indefinitely regardless of the configured policy.
- **Recommended solution:** Implement a scheduled hosted service (or recurring job via existing job infrastructure) that reads the retention settings per company and executes the purge/archival logic on a cadence, reusing the existing SQL script as its query basis.
- **Production impact:** Storage grows unbounded and any retention SLA implied by the setting is unmet in production.
- **Business impact:** Regulatory/compliance retention commitments (e.g., data-minimization policies) made via this setting are not actually honored, exposing the organization to audit findings.
- **Technical impact:** Configuration exists with no corresponding runtime behavior, creating a dead/misleading setting in the codebase.
- **Evidence:** grep for 'Purge'/'Retention' outside Migrations across the backend returned only sql-scripts-dyanmic/RetentionDashboard-sqlscripts.sql; no matches in Base.Infrastructure/HostedServices or Base.Infrastructure/Jobs
- **Reviewer note:** not adversarially verified (Medium/Low)

### #194 · Login — Credential lookup — Cross-tenant username lookup on login  — `Medium`

- **Module:** Administration / System Configuration  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** GetUserCredential resolves login usernames using IgnoreQueryFilters() with a query that matches on UserName/IsActive/IsDeleted only, with no CompanyId predicate, meaning username uniqueness is enforced globally rather than per company.
- **Gap identified:** Username-based login resolution operates globally across all tenants rather than per-company, meaning UserName is effectively a single global namespace shared by every NGO/company on the platform.
- **Why it's a problem:** In a multi-tenant SaaS, this means two different NGOs cannot both have a user named e.g. 'jsmith', and worse, credential lookup logic that ignores tenant boundaries at the query-filter level is a common source of cross-tenant data leakage bugs.
- **Recommended solution:** Scope the credential lookup by CompanyId (passed alongside username at login) so username uniqueness and lookup are per-tenant, removing the blanket IgnoreQueryFilters() unless a company-scoped filter is reapplied explicitly.
- **Production impact:** Username collisions across tenants will cause login failures or ambiguous credential resolution as the platform onboards more NGOs.
- **Business impact:** Constrains each NGO customer to a globally-unique username namespace, an operational and UX limitation inconsistent with multi-tenant SaaS expectations.
- **Technical impact:** Bypassing tenant query filters at the authentication entry point is an architectural inconsistency that raises the risk of similar unscoped-query mistakes elsewhere in the codebase.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Queries/GetUserCredential.cs lines 24-30 (`IgnoreQueryFilters()` + `FirstOrDefaultAsync(o => o.UserName == query.username && o.IsActive == true && o.IsDeleted == false, ...)` — no CompanyId predicate)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #195 · User Management — Activate/Deactivate User — Inconsistent SUPERADMIN protection between deactivate and delete  — `Medium`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** DeleteUser enforces a SUPERADMIN guard preventing deletion of a SUPERADMIN account, but ToggleUserStatus (Activate/Deactivate) has only a self-protect check and no equivalent SUPERADMIN guard.
- **Gap identified:** Any user holding User.Modify permission can deactivate a SUPERADMIN's account (`IsActive=false`), even though that same actor is explicitly blocked from deleting that account — an inconsistent, easily-bypassed privilege boundary (deactivation achieves the same practical lockout as deletion for an active session-less user).
- **Why it's a problem:** Deactivation achieves the same practical lockout as deletion for a SUPERADMIN with no active session, so the missing guard lets any User.Modify holder bypass the intended privilege boundary simply by deactivating instead of deleting.
- **Recommended solution:** Add the same SUPERADMIN guard used in DeleteUser to ToggleUserStatus, blocking non-SUPERADMIN actors from deactivating a SUPERADMIN account.
- **Production impact:** A lower-privileged admin can lock out the platform's highest-privilege account without triggering the safeguard designed to prevent exactly that.
- **Business impact:** Creates a privilege-escalation-adjacent risk where a rogue or compromised admin account can disable top-level administrative access.
- **Technical impact:** Two commands governing equivalent security outcomes enforce inconsistent authorization rules, indicating a gap in the permission model's completeness.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Commands/DeleteUser.cs (SUPERADMIN guard ~lines 44-71) vs ToggleUserStatus.cs (only self-protect check, no SUPERADMIN guard, full 61-line file)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #196 · User Management — Impersonate User — Non-functional Impersonate User mutation exposed  — `Medium`

- **Module:** Administration / System Configuration  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** The ImpersonateUser GraphQL mutation is fully reachable and returns a structurally valid-looking response (AccessToken 'PLACEHOLDER', ExpiresIn 0) with no server-side rejection, even though the frontend currently shows a 'coming soon' toast instead of calling it.
- **Gap identified:** Although the FE does not yet call the broken mutation (reducing user-facing risk today), the GraphQL mutation itself is fully exposed and reachable by anyone with the right permission/token (e.g., via GraphQL Playground or a direct API call), returning a non-functional but structurally valid-looking response with no server-side rejection or NotImplementedException.
- **Why it's a problem:** Anyone with the right permission/token can call the mutation directly (e.g., via GraphQL Playground), bypassing the FE's cosmetic hide, and receive a response that could be mistaken for a working impersonation token by an integrating client or attacker probing the API.
- **Recommended solution:** Either complete the ImpersonateUser implementation server-side or have it throw a NotImplementedException / explicit GraphQL error until implemented, rather than returning a placeholder success-shaped payload.
- **Production impact:** The API surface presents an incomplete security-sensitive feature as if it were functional, which is confusing at minimum and exploitable if the placeholder token is ever treated as valid downstream.
- **Business impact:** A partially-built impersonation capability sitting live in production is a reputational and security risk for an NGO platform handling sensitive constituent data.
- **Technical impact:** Server-side placeholder responses that mimic success violate the principle of fail-closed design for unimplemented privileged operations.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Commands/ImpersonateUser.cs (handler returns `AccessToken = "PLACEHOLDER", ExpiresIn = 0`); PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/shared-cell-renderers/user-actions-cell.tsx lines ~97-99 (toast 'coming soon' instead of calling the mutation) and line 23 comment ('cosmetic hide of Impersonate for non-SUPERADMIN actor')
- **Reviewer note:** not adversarially verified (Medium/Low)

### #197 · User Management — Reset Password — Temp password exposure via GraphQL response  — `Medium`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** The password-reset handler returns the generated plaintext temporary password directly in the ResetUserPasswordResult GraphQL response, in addition to sending it via email.
- **Gap identified:** The plaintext secret is exposed via a second channel beyond email: the GraphQL response body, which is subject to request/response logging, APM tracing, browser devtools network tab, and any FE state management that retains the mutation result.
- **Why it's a problem:** Returning the secret in the API response creates a second exposure surface — request/response logging, APM traces, browser devtools, and any FE state store may retain the plaintext credential well beyond the reset flow.
- **Recommended solution:** Remove TempPassword from the GraphQL response payload entirely; deliver the temporary password only via the existing email channel, and have the mutation return a boolean success/confirmation instead.
- **Production impact:** Any logging/tracing infrastructure enabled in production (APM, GraphQL request logs) will persist plaintext credentials at rest in log stores.
- **Business impact:** Increases risk of credential leakage to anyone with log/trace access, a compliance and audit concern for an NGO handling sensitive donor/beneficiary data.
- **Technical impact:** Expands the credential's exposure surface beyond a single controlled channel, violating least-privilege handling of secrets.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Commands/ResetUserPassword.cs (handler sets `response.TempPassword = tempPassword` and returns it in ResetUserPasswordResult)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #198 · User Management — Terminate Sessions — Missing audit trail for session termination  — `Medium`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** The TerminateUserSessions command handler makes no explicit audit call, and RefreshToken is listed in AuditLogInterceptor.SkippedEntityTypes, so the generic entity-change interceptor also does not capture this change.
- **Gap identified:** `RefreshToken` is in `AuditLogInterceptor.SkippedEntityTypes` (excluded from the generic entity-change audit path), and no dedicated audit call is made — so this admin security action produces zero audit trail entries.
- **Why it's a problem:** A security-sensitive admin action (forcibly terminating another user's active sessions) leaves zero audit trail, making it impossible to later determine who terminated whose sessions and when.
- **Recommended solution:** Add an explicit IAuditLogWriter call inside TerminateUserSessions capturing actor, target user, and timestamp, independent of the generic entity-change interceptor's skip list.
- **Production impact:** Security incident response cannot reconstruct session-termination events during an investigation.
- **Business impact:** Undermines administrative accountability for a privileged security action, a gap likely to surface in a compliance/security audit.
- **Technical impact:** Creates an audit blind spot specifically for the entity type deliberately excluded from the generic audit path.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Commands/TerminateUserSessions.cs (handler body has no IAuditLogWriter call); Base.Infrastructure/Data/Interceptors/AuditLogInterceptor.cs lines 27-31 (SkippedEntityTypes includes 'RefreshToken')
- **Reviewer note:** not adversarially verified (Medium/Low)

### #302 · Administration > Role Management / Menu Management / Modules — all GraphQL mutation entry points — Duplicate Authorization DB Round-Trip  — `Low`

- **Module:** Administration / System Configuration  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** AuthorizationBehavior is registered twice in the MediatR pipeline (once in Base.Application/DependencyInjection.cs, again in Base.API/DependencyInjection.cs), so the HasAccessAsync DB join runs twice per request for every CustomAuthorize-decorated command/query.
- **Gap identified:** Every authorization check (the DB join in HasAccessAsync) runs twice per request for every CustomAuthorize-decorated command/query, doubling DB round-trips for authorization on every protected mutation/query in the system, including all Role/Capability/Menu/Module screens in scope.
- **Why it's a problem:** Every protected mutation/query pays double the DB latency for authorization alone, compounding across all Role/Capability/Menu/Module screens and any other CustomAuthorize-decorated endpoint in the system.
- **Recommended solution:** Remove the duplicate AddOpenBehavior/AddTransient registration for AuthorizationBehavior in one of the two DependencyInjection files, keeping a single registration point (Base.Application is the more appropriate owner for pipeline behaviors).
- **Production impact:** Elevated per-request latency and DB load across the entire authenticated surface, worsening under scale.
- **Business impact:** Unnecessary infrastructure cost and slower perceived responsiveness for end users across all authenticated screens.
- **Technical impact:** Redundant pipeline wiring indicates a DI configuration defect that inflates DB query volume without any functional benefit.
- **Evidence:** Base.Application/DependencyInjection.cs line 30 (config.AddOpenBehavior(typeof(AuthorizationBehavior<,>))); Base.API/DependencyInjection.cs ~line 170 (services.AddTransient(typeof(IPipelineBehavior<,>), typeof(AuthorizationBehavior<,>)))
- **Reviewer note:** not adversarially verified (Medium/Low)

### #303 · Audit Trail (all entity mutations) — Fire-and-forget audit emission on synchronous SaveChanges  — `Low`

- **Module:** Administration / System Configuration  |  **Category:** qa  |  **Verification:** CONFIRMED
- **Current implementation:** The SavedChanges interceptor override for synchronous SaveChanges() calls emits audit rows via an unawaited, fire-and-forget task (`_ = EmitAuditRowsAsync(...)`), explicitly commented as best-effort.
- **Gap identified:** Any code path in the codebase that calls the synchronous `SaveChanges()` (rather than `SaveChangesAsync()`) triggers an unobserved, unawaited Task for audit emission; if the request/process completes or the DbContext is disposed before that fire-and-forget task is scheduled and runs, the audit row for that specific save is silently lost with no logged error tying it back to the originating save call.
- **Why it's a problem:** If the request completes or the DbContext is disposed before the unawaited task is scheduled and runs, the audit row for that save is silently lost with no error logged tying the loss back to the originating save call.
- **Recommended solution:** Audit any remaining synchronous SaveChanges() call sites and migrate them to SaveChangesAsync(), or make the interceptor block synchronously (e.g., `.GetAwaiter().GetResult()`) on the sync path so audit emission is guaranteed before the save call returns.
- **Production impact:** Any code path still using synchronous SaveChanges() risks intermittent, unlogged audit gaps that are difficult to reproduce or detect.
- **Business impact:** Further erodes confidence in the audit trail as a complete system-of-record, compounding the durability gaps already present in the audit pipeline.
- **Technical impact:** Fire-and-forget async work tied to a request-scoped DbContext is a known reliability anti-pattern that can silently drop work on process/context teardown.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Interceptors/AuditLogInterceptor.cs lines 45-53 (`SavedChanges` override: `_ = EmitAuditRowsAsync(eventData.Context, CancellationToken.None);` with comment 'Fire-and-forget on sync path — audit is best-effort on sync saves')
- **Reviewer note:** not adversarially verified (Medium/Low)

### #304 · Login / Authentication — Password hashing — Weak PBKDF2 iteration count for password hashing  — `Low`

- **Module:** Administration / System Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** Password hashing uses PBKDF2 with a hardcoded 10,000 iterations constant.
- **Gap identified:** 10,000 iterations is well below current OWASP guidance for PBKDF2 (recommended minimums are in the hundreds of thousands for SHA-256/512 as of recent years), reducing the computational cost of offline brute-forcing if the password hash table is ever exfiltrated.
- **Why it's a problem:** Current OWASP guidance recommends iteration counts in the hundreds of thousands for PBKDF2-SHA256/512; 10,000 iterations meaningfully reduces the cost of offline brute-forcing if the password hash table is ever exfiltrated.
- **Recommended solution:** Raise the iteration count to meet current OWASP minimums (e.g., 600,000 for SHA-256 per current guidance), and make it a configurable value so it can be increased over time without a code change; plan a rehash-on-next-login migration for existing hashes.
- **Production impact:** No immediate runtime impact, but a future credential-database breach would be more easily brute-forced than with modern standards.
- **Business impact:** Falls short of current security best-practice expectations that donors, partners, or auditors may expect from a platform handling sensitive personal data.
- **Technical impact:** Weakens the cryptographic cost factor protecting stored credentials, a latent security-hardening gap rather than an active vulnerability.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Extensions/AuthExtensions.cs line 14 (`private const int Iterations = 10000;`)
- **Reviewer note:** not adversarially verified (Medium/Low)

## Settings & Configuration

### #75 · Company Email Provider (Settings > Notify > Email Providers) — GetCompanyEmailProviderById / UpdateCompanyEmailProvider  — `Critical`

- **Module:** Settings & Configuration  |  **Category:** IDOR / Tenant Isolation  |  **Verification:** ADJUSTED
- **Current implementation:** GetCompanyEmailProviderById.cs fetches by `CompanyEmailProviderId` only (no CompanyId filter) but DOES call `SensitiveFieldMasking.MaskCredentials(dto.ProviderConfiguration)` before returning, which replaces `apiKey`/`password` JSON keys with a `"••••••••"` placeholder — so the READ path does not leak raw secrets, only non-secret provider metadata (provider type, from-address, display name, etc.) cross-tenant. However, UpdateCompanyEmailProvider.cs fetches via `dbContext.CompanyEmailProviders.FindAsync([companyEmailProviderId], ...)` with NO CompanyId check and NO masking, then persists `ProviderConfiguration` verbatim from the caller's input — allowing a cross-tenant attacker to overwrite another tenant's real (unmasked) provider credentials with attacker-controlled values (a mail-relay hijack), or to submit a real-looking config that silently replaces the victim tenant's working SMTP/API credentials.
- **Gap identified:** The original finding characterized this as a full decrypted-secret read leak; that is overstated for GetById (secrets ARE masked there). The real, unmitigated gap is (a) cross-tenant metadata read via GetById, and (b) cross-tenant WRITE/overwrite of another tenant's live provider credentials via UpdateCompanyEmailProvider, which is arguably more dangerous than a read leak — it lets an attacker silently redirect a victim tenant's outbound transactional/marketing email through an attacker-controlled relay.
- **Why it's a problem:** Even though raw secrets aren't readable, an attacker can blind-overwrite a foreign tenant's email provider config (SMTP host/port/apiKey/from-address) via the Update mutation, which is a serious integrity/hijack vector (email interception, phishing-as-the-brand, or simple denial of service by breaking the victim's email sending) — this survives independent of the read-side masking.
- **Recommended solution:** Add `&& CompanyId == currentCompanyId` to both GetById and Update fetch predicates. Keep the existing masking on reads. Additionally validate on Update that the entity's CompanyId matches the caller's tenant before any field assignment.
- **Production impact:** Update path is immediately exploitable to hijack outbound email routing for any tenant whose CompanyEmailProviderId is known.
- **Business impact:** Brand/phishing risk (attacker relays email as the victim org) and service disruption (victim's real email provider silently replaced).
- **Technical impact:** Cross-tenant write to a security-sensitive settings row; no tenant check anywhere in the CRUD chain except implicitly via SensitiveFieldMasking on one query only.
- **Evidence:** Base.Application/Business/NotifyBusiness/CompanyEmailProviders/Queries/GetCompanyEmailProviderById.cs (no CompanyId filter, but calls SensitiveFieldMasking.MaskCredentials before returning); Commands/UpdateCompanyEmailProvider.cs (`dbContext.CompanyEmailProviders.FindAsync([companyEmailProviderId], ...)` — no CompanyId filter, no masking, direct overwrite of ProviderConfiguration); Queries/GetCompanyEmailProviderStats.cs lines ~53-98 (SensitiveFieldMasking definition: Placeholder="••••••••", SensitiveKeys={"apiKey","password"}); Base.API/EndPoints/Notify/Mutations/CompanyEmailProviderMutations.cs lines 63 & 158 confirm both Update and Save commands are live, reachable GraphQL mutations.
- **Reviewer note:** Original finding overstated the read-path risk (secrets are masked on GetById) but understated that the real, unmitigated danger is the unguarded, unmasked Update path enabling cross-tenant credential/config hijack. Priority kept at Critical because the write vector is at least as dangerous as a read leak; gap/currentImplementation corrected to reflect the masking nuance.

### #76 · Company Payment Gateway (Settings > Payment Gateways) — GetCompanyPaymentGatewayById / UpdateCompanyPaymentGateway / DeleteCompanyPaymentGateway  — `Critical`

- **Module:** Settings & Configuration  |  **Category:** IDOR / Tenant Isolation  |  **Verification:** CONFIRMED
- **Current implementation:** GetCompanyPaymentGatewayById.cs fetches by `CompanyPaymentGatewayId == id && IsDeleted == false` only (no CompanyId predicate), then calls `encryptionService.DecryptForCompany(entity.EncryptedApiKey/EncryptedApiSecret/EncryptedWebhookSecret, entity.CompanyId)` and returns the PLAINTEXT secrets in the response DTO. UpdateCompanyPaymentGateway.cs and DeleteCompanyPaymentGateway.cs use the identical unscoped fetch predicate to locate the row before overwriting/soft-deleting it. No `HasQueryFilter` for tenant scoping exists anywhere in the codebase (verified via full-repo grep).
- **Gap identified:** Any authenticated user who can guess/enumerate a `CompanyPaymentGatewayId` belonging to a DIFFERENT tenant can read that tenant's fully-decrypted payment gateway API key/secret/webhook secret, and can also overwrite or soft-delete that other tenant's gateway configuration — a complete cross-tenant credential leak plus a destructive cross-tenant write, gated only by role/menu capability (`[CustomAuthorize]`), which performs no row-ownership check at all (confirmed by reading `CustomAuthorizeService.HasAccessAsync`).
- **Why it's a problem:** This is the single most severe finding in the unit: it leaks live payment-processor credentials (Braintree/Razorpay/PayU private keys) across tenant boundaries in plaintext, enabling an attacker with a low-privilege account in Tenant A to process/refund/redirect payments or exfiltrate funds using Tenant B's gateway credentials.
- **Recommended solution:** Add `&& c.CompanyId == currentCompanyId` to the fetch predicate in all three handlers (GetById, Update, Delete), sourced from `IHttpContextAccessor.GetCurrentUserStaffCompanyId()`, and never return decrypted secrets in query DTOs (mask/omit like the CompanyEmailProvider read path does).
- **Production impact:** Confirmed exploitable in production as soon as any two tenants' gateway IDs are known/guessable (sequential int PK).
- **Business impact:** Direct financial/legal liability — cross-tenant payment credential theft violates PCI-adjacent obligations and tenant contracts.
- **Technical impact:** Full compromise of another tenant's payment gateway integration; also a write/delete vector for sabotage.
- **Evidence:** Base.Application/Business/DonationBusiness/CompanyPaymentGateways/Queries/GetCompanyPaymentGatewayById.cs (fetch predicate has no CompanyId; decrypts and returns EncryptedApiKey/EncryptedApiSecret/EncryptedWebhookSecret in plaintext); Commands/UpdateCompanyPaymentGateway.cs line 23 (same unscoped predicate); Commands/DeleteCompanyPaymentGateway.cs line 14 (same); zero `HasQueryFilter` matches repo-wide; CustomAuthorizeService.cs confirmed to check only role/menu/capability, never row ownership.
- **Reviewer note:** Verified end-to-end: no mitigating query filter, no masking on this read path (unlike CompanyEmailProvider), no interceptor protection applies here since CompanyId isn't being reassigned — the leak is a direct read/write of a foreign-tenant row.

### #77 · Grid Configuration (Settings > System > Grid Layout Designer) — BulkUpdateGridConfiguration  — `Critical`

- **Module:** Settings & Configuration  |  **Category:** Data Integrity / Tenant Isolation  |  **Verification:** CONFIRMED
- **Current implementation:** Grid.cs entity (Base.Domain/Models/SettingModels/Grid.cs) has NO CompanyId property at all — it is a single global row per GridId shared across all tenants, with `LayoutConfiguration` as a plain shared JSON string column. BulkUpdateGridConfiguration.cs fetches `dbContext.Grids.FirstOrDefaultAsync(g => g.GridId == dto.GridId, ...)` (GridId only — there is no CompanyId to filter by since the column doesn't exist) and directly overwrites `grid.LayoutConfiguration = JsonSerializer.Serialize(dto.LayoutConfiguration)` — a single shared column with no tenant partitioning. By contrast, the sibling `GridField` entities updated in the SAME handler DO carry `CompanyId = upsert.CompanyId` (lines ~126, 146), proving the codebase's own established per-tenant pattern was simply not applied to `Grid.LayoutConfiguration`.
- **Gap identified:** Grid column-layout/configuration customization made by any ONE tenant (e.g., reordering/resizing/hiding grid columns on a shared screen) silently overwrites the SAME global row and is immediately visible to and imposed on EVERY OTHER TENANT in the system — this is not a rare edge case but fires on completely ordinary, non-malicious use of the grid customization feature by any user.
- **Why it's a problem:** This is a functional data-corruption bug that will be triggered constantly in normal production use (not an attack) — every time any tenant's user customizes a grid's column layout, they inadvertently overwrite every other tenant's grid layout for that screen, causing visible UI breakage/confusion platform-wide and a support/trust nightmare.
- **Recommended solution:** Add a `CompanyId` column to `Grid` (or split `LayoutConfiguration` into a new per-tenant child table keyed by GridId+CompanyId, mirroring the existing GridField pattern) and scope both the fetch and the upsert by CompanyId.
- **Production impact:** Fires on ordinary use by any tenant, not just under attack — the highest-likelihood finding in this unit.
- **Business impact:** Cross-tenant UI corruption is highly visible and will generate support tickets/trust erosion across the entire customer base immediately upon multi-tenant usage.
- **Technical impact:** Grid entity architecturally lacks tenant partitioning for LayoutConfiguration despite the codebase demonstrating the correct per-tenant pattern one level down (GridField.CompanyId) in the very same handler.
- **Evidence:** Base.Domain/Models/SettingModels/Grid.cs (54 lines, no CompanyId property); Base.Application/Business/SettingBusiness/Grids/Commands/BulkUpdateGridConfiguration.cs (246 lines) — `var grid = await dbContext.Grids.FirstOrDefaultAsync(g => g.GridId == dto.GridId, cancellationToken);` and `grid.LayoutConfiguration = JsonSerializer.Serialize(dto.LayoutConfiguration); dbContext.Grids.Update(grid);`; contrast with GridField upserts in the same file setting `CompanyId = upsert.CompanyId` at ~lines 126 and 146.
- **Reviewer note:** This is the strongest finding in the unit — it requires no attacker at all, just ordinary multi-tenant usage, to corrupt shared state across tenants.

### #78 · Master Data (Settings > System > Master Data) — UpdateMasterData / DeleteMasterData  — `Critical`

- **Module:** Settings & Configuration  |  **Category:** Authorization / Data Integrity  |  **Verification:** CONFIRMED
- **Current implementation:** UpdateMasterData.cs and DeleteMasterData.cs both fetch via `dbContext.MasterDatas.FindAsync([masterDataId], ...)` with NO check of `IsSystem` or `CompanyId` before modifying/soft-deleting. The `MasterData` entity (Base.Domain/Models/SettingModels/MasterData.cs) DOES define both `IsSystem` (bool, line 14) and `CompanyId` (int?, line 15) precisely to distinguish system-seeded/shared reference data from tenant-owned custom values, but neither handler reads or enforces these flags.
- **Gap identified:** Any user with Modify/Delete capability on the MasterData module can edit or soft-delete SYSTEM master-data rows (e.g., core lookup values like DONATIONTYPE, PAYMENTSTATUS codes referenced by hardcoded string matches throughout the codebase such as InitiateOnlineDonation.cs's GetMasterDataIdFirstOf lookups) shared across ALL tenants, with no protection against breaking every tenant's functionality simultaneously.
- **Why it's a problem:** Because so much business logic resolves MasterData by TypeCode+DataValue string match rather than immutable FK, silently renaming or soft-deleting a system row (e.g., changing DONATIONMODE 'OD' → something else, or deleting PAYMENTSTATUS 'PENDING') can break online donation processing, receipting, and reporting for every tenant in the system simultaneously — a single accidental or malicious edit becomes a platform-wide outage.
- **Recommended solution:** In both handlers, load the entity, check `entity.IsSystem == true` and reject the Update/Delete (or require an elevated superadmin-only permission) unless `entity.CompanyId == currentCompanyId` (tenant-scoped custom rows only); system rows should only be editable through an admin data-migration process, not the standard CRUD mutation.
- **Production impact:** A single Modify/Delete action on the wrong MasterData row can silently break donation/payment/receipt flows platform-wide.
- **Business impact:** Platform-wide functional outage risk from an ordinary (non-malicious) user action, plus a genuine security gap for tenant-scoped rows.
- **Technical impact:** IsSystem/CompanyId columns exist on the entity but are completely unenforced in both mutation handlers.
- **Evidence:** Base.Application/Business/SettingBusiness/MasterDatas/Commands/UpdateMasterData.cs (`dbContext.MasterDatas.FindAsync([masterDataId], ...)` — no IsSystem/CompanyId check); Commands/DeleteMasterData.cs (identical pattern, sets IsDeleted=true unconditionally); Base.Domain/Models/SettingModels/MasterData.cs lines 14-15 (IsSystem, CompanyId defined but unused in these handlers).

### #79 · Organization Bank Accounts (Settings > Organization > Bank Accounts) — GetOrganizationBankAccounts (grid) / GetOrganizationBankAccountById  — `Critical`

- **Module:** Settings & Configuration  |  **Category:** IDOR / Tenant Isolation  |  **Verification:** CONFIRMED
- **Current implementation:** GetOrganizationBankAccounts.cs list/grid query: `dbContext.OrganizationBankAccounts.AsNoTracking().Where(a => a.IsDeleted == false)...` — zero CompanyId predicate anywhere in the base or filtered query, meaning the STANDARD GRID VIEW (not just a direct-ID guess) returns every tenant's bank accounts by default to any user who can open this screen. GetOrganizationBankAccountById.cs has the same gap (`OrganizationBankAccountId` only). AccountNumber itself is separately protected — UpdateOrganizationBankAccount.cs treats it as write-only (only overwritten when the caller supplies a new value), so masked account numbers aren't blindly re-persisted, but this doesn't address the read-side leak of masked-or-not account/bank metadata across tenants.
- **Gap identified:** This is worse than a typical single-row IDOR: the ordinary grid/list screen (no ID guessing required) discloses ALL tenants' organization bank accounts (bank name, branch, account name, currency, masked/partial account number) to any authenticated user with Read permission on this module, cross-tenant, by default, with zero attacker effort.
- **Why it's a problem:** A list screen leaking every tenant's banking relationships (bank, branch, account nickname) is a severe confidentiality breach exploitable passively just by opening the screen — no need to enumerate IDs — making this arguably more dangerous in practice than single-record IDOR findings elsewhere in this unit.
- **Recommended solution:** Add `&& a.CompanyId == currentCompanyId` to the grid base query in GetOrganizationBankAccounts.cs and to the predicate in GetOrganizationBankAccountById.cs.
- **Production impact:** Every page-load of this screen currently leaks cross-tenant data in a multi-tenant production deployment.
- **Business impact:** Breach of tenant data-isolation guarantees for financial/banking metadata — a core NGO/nonprofit SaaS trust requirement.
- **Technical impact:** Systemic missing tenant filter on both list and detail queries for this entity.
- **Evidence:** Base.Application/Business/ApplicationBusiness/OrganizationBankAccounts/Queries/GetOrganizationBankAccounts.cs lines 26-32 (baseQuery has no CompanyId filter); Queries/GetOrganizationBankAccountById.cs lines 25-28 (same); grep of AccountNumber usage in UpdateOrganizationBankAccount.cs confirms AccountNumber is write-only-if-supplied (a separate, narrower protection that does not address this list/detail leak).
- **Reviewer note:** Confirmed and arguably understated in the original finding — the grid/list endpoint (not just GetById) has zero tenant scoping, which is a broader exposure surface than a single-record IDOR.

### #80 · Region Hierarchy Import (Settings > System > Regions > Import CSV) — ImportRegionsCommand  — `Critical`

- **Module:** Settings & Configuration  |  **Category:** Authorization / Missing Access Control  |  **Verification:** CONFIRMED
- **Current implementation:** ImportRegions.cs's `ImportRegionsCommand` record and `ImportRegionsHandler` class have NO `[CustomAuthorize(...)]` decorator anywhere — contrast with essentially every other command/query examined in this unit (e.g., `GetOrganizationBankAccountsQuery` carries `[CustomAuthorize(DecoratorApplicationModules.OrganizationBankAccount, Permissions.Read)]`, `SaveSmsConnectionSettingsCommand` carries `[CustomAuthorize(DecoratorNotifyModules.SmsSetup, Permissions.Modify)]`). The GraphQL mutation wrapper in `Base.API/EndPoints/Shared/Mutations/RegionHierarchyMutations.cs` also has no `[Authorize]`/`[CustomAuthorize]` at the class or method level. The only other unauthenticated mutation found in this codebase, `InitiateOnlineDonationCommand`, explicitly documents its anonymous-access decision in a doc comment ('ANONYMOUS-ALLOWED... no [CustomAuthorize]'); ImportRegionsCommand carries no such comment, i.e., there is no evidence this is an intentional public/anonymous design — it reads as an oversight. Additionally, every row inserted/updated during import hardcodes `CreatedBy = 2` / `ModifiedBy = 2` (confirmed at 10+ call sites for Country/State/District/City/Locality/Pincode) instead of the actual authenticated user's ID.
- **Gap identified:** The CSV region-import mutation, which creates/modifies GLOBAL reference data (Country/State/District/City/Locality/Pincode — none of these entities carry a CompanyId; they are shared across ALL tenants system-wide), has zero permission/capability gate and, per the codebase's own convention (GraphQL fields require `[CustomAuthorize]` to enforce any access control; there is no default-deny policy evident), is very plausibly callable by ANY authenticated user regardless of role — or even anonymously, since nothing in the mutation or handler establishes an auth requirement.
- **Why it's a problem:** Because Country/State/District/etc. are GLOBAL (non-tenant-scoped) tables, an attacker exploiting this gap doesn't just affect one tenant — a malicious or accidental CSV import can inject bogus geographic reference data, duplicate/rename existing countries or states, or corrupt currency associations for every tenant on the platform simultaneously, and every resulting row is misattributed to hardcoded user ID 2 rather than the real actor, destroying audit trail integrity for the incident.
- **Recommended solution:** Add `[CustomAuthorize(DecoratorSharedModules.RegionHierarchy, Permissions.Modify)]` (or an appropriately scoped, likely superadmin-only, permission given the global blast radius) to `ImportRegionsCommand`; replace hardcoded `CreatedBy = 2`/`ModifiedBy = 2` with the real authenticated user ID via `IHttpContextAccessor`.
- **Production impact:** Confirmed: no authorization attribute exists on this command or its GraphQL wrapper, unlike every comparable command in the unit.
- **Business impact:** Platform-wide reference-data integrity risk plus destroyed audit trail (all rows attributed to a fake system user ID 2, not the real actor).
- **Technical impact:** Missing `[CustomAuthorize]` decorator (an actual oversight, not a documented anonymous-by-design decision) combined with hardcoded audit-field values.
- **Evidence:** Base.Application/Business/SharedBusiness/RegionHierarchies/Commands/ImportRegionsCommand/ImportRegions.cs (no [CustomAuthorize] on the command record or handler class; `CreatedBy = 2`/`ModifiedBy = 2` hardcoded at lines 188, 198, 223, 233, 259, 269, 296, 306, 334, 366); Base.API/EndPoints/Shared/Mutations/RegionHierarchyMutations.cs (GraphQL mutation wrapper also has no [Authorize]/[CustomAuthorize]); contrast with GetOrganizationBankAccountsQuery and SaveSmsConnectionSettingsCommand, both of which carry [CustomAuthorize] as the codebase's standard pattern.
- **Reviewer note:** If anything the original finding understates severity: since the affected tables are GLOBAL (not tenant-scoped), this is a platform-wide integrity risk, not merely a single-tenant IDOR, and there is no doc-comment (unlike InitiateOnlineDonation) suggesting the missing auth is intentional.

### #181 · Accounting Integration (Settings > Integrations > Accounting) — ConnectAccountingProvider  — `High`

- **Module:** Settings & Configuration  |  **Category:** Mocked/Non-Functional Integration  |  **Verification:** CONFIRMED
- **Current implementation:** ConnectAccountingProvider.cs (152 lines) contains an explicit `SERVICE_PLACEHOLDER` doc comment and fabricates all OAuth connection state: `entity.AccessToken = $"mock_at_{Guid.NewGuid():N}"; entity.RefreshToken = $"mock_rt_{Guid.NewGuid():N}"; entity.ExternalCompanyName = $"[Mocked] Company {companyId}"; entity.ExternalRealmId = Guid.NewGuid().ToString();` — no real OAuth handshake with QuickBooks/Xero/etc. ever occurs. The surrounding atomic-transaction provider-switch logic (ensuring only one active provider connection at a time) is real and correctly implemented — only the OAuth exchange itself is mocked.
- **Gap identified:** The 'Connect Accounting Provider' feature presents as fully functional (generates what look like real access/refresh tokens and a company name) but never actually authenticates with any external accounting system — any subsequent sync/export operation that depends on these tokens will fail or silently no-op against the real provider API.
- **Why it's a problem:** Admins configuring this integration will believe their accounting system is connected (the UI shows a 'Connected' state with a company name) when in fact no real connection exists, leading to silent data-sync failures discovered only when accounting reconciliation doesn't happen.
- **Recommended solution:** Implement the real OAuth 2.0 authorization-code flow for each supported accounting provider, or clearly gate/label this feature as 'Coming Soon' in the UI so admins aren't misled into believing it is live.
- **Production impact:** Any tenant enabling this feature today gets a non-functional integration that appears successful.
- **Business impact:** Silent accounting-sync failure risk with no user-facing indication of the underlying mock.
- **Technical impact:** Feature is architecturally sound (real state machine/transaction) but its core external-integration step is entirely fabricated.
- **Evidence:** Base.Application/Business/IntegrationBusiness/AccountingIntegrations/ConnectCommand/ConnectAccountingProvider.cs — SERVICE_PLACEHOLDER comment plus fabricated AccessToken/RefreshToken/ExternalCompanyName/ExternalRealmId assignments; FE grep of AccountingIntegrationMutation.ts shows only internal code comments referencing SERVICE_PLACEHOLDER, no user-facing 'Coming Soon' disclosure found in the FE.

### #182 · API Keys (Settings > Integrations > API Keys) — ApiKey creation/rotation vs. inbound request authentication  — `High`

- **Module:** Settings & Configuration  |  **Category:** Authentication / Dead Feature  |  **Verification:** CONFIRMED
- **Current implementation:** ApiKey.cs model, ApiKeyConfiguration.cs, ApiKeySchemas.cs, and Create/Update/Rotate command handlers all exist and correctly generate/hash/store `HashedKey` values. A full-repo grep for `HashedKey` returns 82 matches — almost entirely EF migration snapshot/Designer files plus the model/config/handlers themselves. A grep for `ApiKey` scoped to `Base.API` (the HTTP/GraphQL entry-point layer) returns only 7 files: RazorpayWebhookController.cs, PaymentWebhookController.cs, appsettings.json, PaymentFlowService.cs, PayUWebhookController.cs, ApiKeyQueries.cs, ApiKeyMutations.cs — none of which implement any middleware, filter, or attribute that validates an inbound request's presented API key against a stored `HashedKey` before granting access to a protected endpoint.
- **Gap identified:** The ApiKey feature lets admins generate, rotate, and revoke API keys through the UI, but there is no code path anywhere that actually consumes/validates a caller-presented API key against `HashedKey` to authenticate/authorize any request — the entire feature is a CRUD shell around a credential that is never checked.
- **Why it's a problem:** Any integration or documentation that tells external partners 'use this API key to authenticate' is falsely promising a security boundary that doesn't exist — either no endpoint is actually protected by API keys (meaning the feature is decorative/misleading), or worse, if any endpoint is documented/expected to require an API key, that endpoint is actually open with no key check at all.
- **Recommended solution:** Implement API-key authentication middleware (e.g., a custom `AuthenticationHandler` or GraphQL request-pipeline hook) that extracts a presented key from a header, hashes it, and compares it to stored `HashedKey` values before allowing the request through; wire it to whichever endpoints are meant to be key-protected. If no endpoint is currently meant to use this, remove or clearly label the feature as not-yet-wired.
- **Production impact:** Feature is present and appears functional in the admin UI (keys can be generated/rotated) but provides zero actual security enforcement anywhere in the request pipeline.
- **Business impact:** False sense of security for any integration partner relying on API keys; potential support/compliance issue if partners are told API keys are required.
- **Technical impact:** Dead/unwired authentication primitive — CRUD exists, enforcement does not.
- **Evidence:** Grep for `HashedKey` across Base.Application/Base.API (82 matches, all migration/model/config/handler, zero request-pipeline consumers); grep for `ApiKey` scoped to Base.API (7 files: RazorpayWebhookController.cs, PaymentWebhookController.cs, appsettings.json, PaymentFlowService.cs, PayUWebhookController.cs, ApiKeyQueries.cs, ApiKeyMutations.cs — no authentication middleware/filter among them).

### #183 · Certificate Templates (Settings > Contact > Certificate Templates) — GetCertificateTemplateById / UpdateCertificateTemplate  — `High`

- **Module:** Settings & Configuration  |  **Category:** IDOR / Tenant Isolation  |  **Verification:** ADJUSTED
- **Current implementation:** GetCertificateTemplateById.cs fetches by `CertificateTemplateId` only (no CompanyId filter) — confirmed cross-tenant read of full HtmlContent. UpdateCertificateTemplate.cs (117 lines) fetches the SAME way (tracked entity, not AsNoTracking), applies `command.certificateTemplate.Adapt(entity)`, and then explicitly does `entity.CompanyId = companyId;` (comment: "Enforce tenant scope") using the CALLER's own CompanyId — this is an attempt at self-healing tenant reassignment on write. However, `TenantSaveChangesInterceptor.cs` globally blocks CompanyId changes on Modified (existing) entities for ALL users (`entry.Property(companyIdProperty.Name).IsModified = false`), so this reassignment line is a no-op at the database level — the entity's true CompanyId in the DB does NOT change.
- **Gap identified:** The original finding's framing of a 'tenant hijack primitive' / literal ownership-theft via CompanyId reassignment does NOT survive scrutiny — the SaveChangesInterceptor silently blocks that exact write from persisting. The REAL, still-unmitigated gap is narrower but still serious: (1) GetCertificateTemplateById leaks another tenant's full HtmlContent (a donation tax-receipt/certificate template, potentially containing tenant-specific legal/branding language) on a simple ID guess, and (2) UpdateCertificateTemplate allows a cross-tenant attacker to overwrite another tenant's HtmlContent/other fields (defacement/corruption of a legally-relevant document template) even though the CompanyId itself won't actually move to the attacker's tenant.
- **Why it's a problem:** Even without literal ownership transfer, an attacker can silently deface or corrupt another tenant's donation-receipt certificate template (which may be legally required to contain specific tax-exemption language) — this can cause improperly-formatted receipts to go out to donors without the victim tenant's knowledge, a compliance and trust issue, though it does not let the attacker 'steal' the record into their own tenant's visible inventory.
- **Recommended solution:** Add `&& CompanyId == currentCompanyId` to both the GetById and Update fetch predicates; remove the now-provably-ineffective `entity.CompanyId = companyId;` line since it doesn't persist and gives a false sense of protection to future maintainers reading the code.
- **Production impact:** Exploitable now for cross-tenant read and content-overwrite; NOT exploitable for actual tenant reassignment/ownership theft due to the interceptor.
- **Business impact:** Compliance/trust risk (tampered legal document templates) rather than data-ownership theft.
- **Technical impact:** Missing tenant filter on fetch predicates in both Query and Command handlers for this entity; the code's own 'enforce tenant scope' line is dead code given the interceptor.
- **Evidence:** Base.Application/Business/ContactBusiness/CertificateTemplates/Commands/UpdateCertificateTemplate.cs lines 75-82 (unscoped fetch + `entity.CompanyId = companyId;` at line 82); Base.Infrastructure/Data/Interceptors/TenantSaveChangesInterceptor.cs (Modified-entity block: `entry.Property(companyIdProperty.Name).IsModified = false;`) proves the reassignment never reaches the DB; Queries/GetCertificateTemplateById.cs (`o.CertificateTemplateId.Equals(query.certificateTemplateId) && o.IsDeleted == false` — no CompanyId).
- **Reviewer note:** Downgraded from a 'tenant hijack / ownership theft' framing (refuted by TenantSaveChangesInterceptor blocking persisted CompanyId changes) to a cross-tenant read/content-overwrite IDOR. Priority adjusted from Critical to High given the narrower real-world blast radius (defacement, not theft of ownership).

### #184 · SMS Settings / WhatsApp Settings (Settings > Notify > SMS & WhatsApp Setup) — SaveSmsConnectionSettings (and companion WhatsApp handler)  — `High`

- **Module:** Settings & Configuration  |  **Category:** Encryption at Rest  |  **Verification:** CONFIRMED
- **Current implementation:** SmsSetting.cs model has multiple plain `string?` columns explicitly commented `// SECRET`: `TwilioAuthToken`, `BirdApiKey`, `VonageApiSecret`, `LocalApiKey`, `LocalApiSecret`, `CustomAuthValue` — none have any encryption annotation or converter. SaveSmsConnectionSettings.cs assigns each of these directly from the incoming DTO with NO call to `IEncryptionService` anywhere in the handler (e.g., `entity.TwilioAuthToken = dto.TwilioAuthToken;`, `entity.BirdApiKey = dto.BirdApiKey;`) — contrast with CompanyPaymentGateway, which correctly uses `IEncryptionService.EncryptForCompany()`/`DecryptForCompany()` for its analogous secret fields. The handler DOES correctly scope its own fetch by `CompanyId == companyId` (so this is purely an encryption-at-rest gap, not a tenant-isolation gap) and does implement a masking-aware 'only overwrite if not already masked' pattern (checking for `…`/`•` characters) to avoid re-persisting a masked placeholder as the real secret.
- **Gap identified:** SMS provider credentials (Twilio auth token, Bird/Vonage/Local/Custom API keys and secrets) are stored in plaintext in the database, unlike the equivalent CompanyPaymentGateway secrets which use per-tenant AES-GCM encryption via IEncryptionService.
- **Why it's a problem:** A database-level compromise (backup leak, insider access, SQL injection elsewhere, misconfigured read replica) directly exposes live SMS provider credentials in plaintext for every tenant, which could be used to send spam/phishing SMS on the tenant's account/reputation or incur direct billing fraud — the same class of risk the codebase already recognizes and mitigates for payment gateways but not here.
- **Recommended solution:** Apply the same `IEncryptionService.EncryptForCompany()`/`DecryptForCompany()` pattern used by CompanyPaymentGateway to all SECRET-commented fields on SmsSetting (and the equivalent WhatsAppSetting fields), with a corresponding EF value converter or explicit encrypt/decrypt calls in the Save/Get handlers.
- **Production impact:** Plaintext secrets currently persist to the production database for every tenant using SMS/WhatsApp connections.
- **Business impact:** Credential-leak blast radius extends to SMS/WhatsApp provider accounts on a DB compromise, with billing-fraud and reputational (spam/phishing) consequences.
- **Technical impact:** Inconsistent encryption posture across the codebase — one integration (payment gateway) does it correctly, this one does not.
- **Evidence:** Base.Domain/Models/NotifyModels/SmsSetting.cs lines 23,29,35,42-43,51 (SECRET-commented plain string columns); Base.Application/Business/NotifyBusiness/SmsSettings/SaveConnectionCommand/SaveSmsConnectionSettings.cs (direct DTO-to-entity assignment for all secret fields, zero IEncryptionService calls; fetch correctly scoped by CompanyId at line 35).
- **Reviewer note:** Confirmed as purely an encryption-at-rest gap; tenant isolation for this handler is actually correct (CompanyId-scoped fetch), which is worth noting since it differs from most other findings in this unit.

### #185 · Social Media Integration (Settings > Integrations > Social Media) — ConnectSocialMediaAccount  — `High`

- **Module:** Settings & Configuration  |  **Category:** Mocked/Non-Functional Integration  |  **Verification:** CONFIRMED
- **Current implementation:** ConnectSocialMediaAccount.cs (120 lines) contains an explicit `// SERVICE_PLACEHOLDER — mock OAuth values (SP-1)` comment and fabricates: `ExternalAccountId = $"MOCK_ACCT_{mockSuffix}"`, `AccessTokenEncrypted = $"MOCK_TOKEN_{tokenSuffix}"`, `RefreshTokenEncrypted = $"MOCK_REFRESH_{tokenSuffix}"`, and `FollowerCount = random.Next(1000, 15001)` via a plain `new Random()` — i.e., the displayed follower count is a randomly generated number with no relation to any real social media account.
- **Gap identified:** The Social Media integration feature fabricates both the OAuth connection AND ongoing account statistics (follower count) that would be displayed to admins as if they were real, live data pulled from the connected platform.
- **Why it's a problem:** This goes beyond a non-functional connection: it actively presents FABRICATED, randomly-varying metrics (follower count) as real data in what is presumably a dashboard/stats display, which is materially misleading to any admin making decisions based on it (e.g., reporting social media reach to a board or funder).
- **Recommended solution:** Implement the real OAuth flow and real Graph/API-based follower-count retrieval for each supported platform, or clearly label this entire feature as 'Coming Soon'/disabled in the FE until implemented; at minimum remove the random-number fabrication so no data is displayed rather than fake data.
- **Production impact:** Any tenant connecting a social account today sees fabricated, randomly-changing follower counts presented as real.
- **Business impact:** Reputational/trust risk if fabricated metrics are used in donor-facing or board reporting; NGOs specifically may report these numbers externally.
- **Technical impact:** Both the connection state and the ongoing metrics pipeline are mocked, not just the initial OAuth handshake.
- **Evidence:** Base.Application/Business/IntegrationBusiness/SocialMedia/Commands/ConnectSocialMediaAccount.cs — SERVICE_PLACEHOLDER comment, MOCK_ACCT_/MOCK_TOKEN_/MOCK_REFRESH_ fabricated identifiers, and `var random = new Random(); FollowerCount = random.Next(1000, 15001);`; FE grep of SocialMediaMutation.ts shows only internal SERVICE_PLACEHOLDER code comments, no user-facing disclosure.
- **Reviewer note:** Slightly more severe than the Accounting Integration finding because it fabricates ongoing displayed METRICS (follower count), not just a one-time connection state.

### #290 · External Pages — Online Donation Page (public submit) — CSRF token validation  — `Medium`

- **Module:** Settings & Configuration  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** InitiateOnlineDonation.cs validates only `req.CsrfToken.Length < 16` — a shape/length check, not a real cryptographic or cookie/header double-submit comparison.
- **Gap identified:** Any caller can pass an arbitrary 16+ character string as CsrfToken and pass this check; there is no verification that the token matches a value the server actually issued to that browser session.
- **Why it's a problem:** This is documented in the code's own class-level comment as intentionally shape-only pending 'real cookie/header pairing... implemented at the API endpoint layer' — but no such real CSRF middleware was found elsewhere in Base.API during this review, meaning the public donation form has no functioning CSRF protection against forged cross-site submissions.
- **Recommended solution:** Implement real double-submit-cookie CSRF validation (server sets a signed cookie on page load; the submitted CsrfToken must match the cookie value via constant-time comparison) at the API/middleware layer, and remove reliance on length-only checks in the handler.
- **Production impact:** Live in production; the check currently provides no real protection against forged submissions from a malicious third-party page.
- **Business impact:** A malicious site could attempt to submit donation-initiate requests on behalf of an unsuspecting visitor's browser session; combined with the other hardening layers this is a partial mitigation gap rather than a full open door.
- **Technical impact:** Confirmed the only validation performed is `req.CsrfToken.Length < 16`; no real CSRF middleware/cookie-pairing implementation was located in Base.API.
- **Evidence:** Base.Application/Business/DonationBusiness/OnlineDonationPages/PublicMutations/InitiateOnlineDonation.cs:30-36 (class doc comment acknowledging shape-only check) and :106-113 (Length < 16 check only)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #291 · Online Donation Page (Public) — Initiate Donation — InitiateOnlineDonationCommand — reCAPTCHA bot-detection  — `Medium`

- **Module:** Settings & Configuration  |  **Category:** Security Control Gap (Public Endpoint Hardening)  |  **Verification:** CONFIRMED
- **Current implementation:** InitiateOnlineDonation.cs line 116: `var recaptchaScore = 1.0m; // SERVICE_PLACEHOLDER returns 1.0 until reCAPTCHA configured.` followed by `if (recaptchaScore < 0.3m) { throw new BadRequestException("RECAPTCHA_LOW_SCORE: Bot-like traffic detected."); }` — the score is a hardcoded literal, never sourced from an actual Google reCAPTCHA (or equivalent) verification call, making the bot-rejection branch permanently unreachable dead code. Other public-endpoint hardening on this same handler IS real: honeypot field check (silent mocked-success on fill), CSRF token shape/length validation (`req.CsrfToken.Length < 16`), and a documented (elsewhere-registered) rate-limit policy "DonationSubmit".
- **Gap identified:** There is no functioning bot/automated-traffic detection on the public, anonymous donation-initiation endpoint — the reCAPTCHA score check is a permanently-passing placeholder, so this specific layer of defense contributes nothing.
- **Why it's a problem:** A public, unauthenticated, financially-consequential endpoint (creates a payment-gateway session and a staging donation row) with a documented-but-nonfunctional bot defense is exposed to automated abuse (mass fake-donation-session creation, gateway API quota exhaustion, staging-table flooding) that the code's own comments claim is mitigated but isn't.
- **Recommended solution:** Integrate real Google reCAPTCHA v3 (or hCaptcha/Turnstile) server-side verification: accept a client-supplied reCAPTCHA token in the request, call the provider's siteverify API, and use the REAL returned score in the existing `< 0.3m` threshold check.
- **Production impact:** Confirmed as a currently-dead security check; however, other layered defenses (honeypot, CSRF shape check, rate-limiting) remain in place, partially reducing the practical exploitability compared to having zero defenses.
- **Business impact:** Automated/bot abuse of the public donation-initiation flow (session/quota exhaustion, staging-table spam) is not actually prevented despite code comments claiming otherwise.
- **Technical impact:** Dead code / permanently-true security gate; explicitly self-documented as `SERVICE_PLACEHOLDER (ISSUE-9)` in the file's own header comment, meaning the gap is already tracked internally.
- **Evidence:** Base.Application/Business/DonationBusiness/OnlineDonationPages/PublicMutations/InitiateOnlineDonation.cs line 116 (`var recaptchaScore = 1.0m; // SERVICE_PLACEHOLDER returns 1.0 until reCAPTCHA configured.`) and line 117 (`if (recaptchaScore < 0.3m)` — unreachable given the hardcoded 1.0m); header doc-comment (lines 30-35) explicitly lists this as 'ISSUE-9' among known hardening gaps, alongside the honeypot (real) and CSRF shape-check (real) and rate-limit policy (registered elsewhere) items.
- **Reviewer note:** Priority adjusted downward from the assumption of 'no bot protection at all' to Medium/High-leaning, since honeypot + CSRF shape-check + rate-limiting are genuinely implemented alongside this one dead check — reCAPTCHA is one of four layers and the only non-functional one, not the sole defense.

### #292 · Region Hierarchy (Settings) — Single-node Create/Update/Delete  — `Medium`

- **Module:** Settings & Configuration  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** The entire RegionHierarchies module contains only: ImportRegionsCommand (bulk CSV upsert), ExportRegions and GetRegionHierarchyTree/GetRegionNodeDetail (read-only queries). No Create/Update/Delete command exists for a single Country/State/District/City/Locality/Pincode node.
- **Gap identified:** An admin cannot correct a single misspelled city, merge a duplicate locality, or delete an unused pincode without re-running a full CSV import — `RegionUsageGuard.EnsureNotInUseAsync` is dead code with an explicit doc comment stating it is 'future wiring — not yet injected into existing per-level Delete handlers' because no Delete handlers exist to call it.
- **Why it's a problem:** Region data feeds Contact/Branch/Family address fields platform-wide; a typo introduced by any historical bulk import (or a legitimately renamed administrative district) has no supported single-record fix path, forcing risky full-file re-imports for a one-field correction.
- **Recommended solution:** Add single-node Create/Update/Delete commands per hierarchy level, wiring the already-built RegionUsageGuard.EnsureNotInUseAsync into the Delete paths to block deletion of in-use/parent nodes.
- **Production impact:** Any data-quality fix at this level today requires a full CSV re-upload, a heavier and riskier operation than a targeted edit.
- **Business impact:** Ongoing address data-quality debt with no lightweight correction tool for admins.
- **Technical impact:** Confirmed via directory listing: only ImportRegionsCommand + 2 read queries + ExportRegions exist; RegionUsageGuard.cs doc comment explicitly confirms Delete handlers don't exist yet.
- **Evidence:** Base.Application/Business/SharedBusiness/RegionHierarchies/ (folder listing: only Commands/ImportRegionsCommand, Queries/ExportRegionsQuery, Queries/GetRegionHierarchyTreeQuery, Queries/GetRegionNodeDetailQuery, Helpers/RegionUsageGuard.cs); Base.Application/Business/SharedBusiness/RegionHierarchies/Helpers/RegionUsageGuard.cs (doc comment: 'future wiring — not yet injected into existing per-level Delete handlers in this session')
- **Reviewer note:** not adversarially verified (Medium/Low)

## Deployment · Config · Ops Readiness

### #21 · Cross-cutting — Backend configuration (Base.API) — Secrets management  — `Critical`

- **Module:** Deployment · Config · Ops Readiness  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/appsettings.json is tracked in the backend's own Azure DevOps git repo (verified: `git ls-files` lists it, 19 commits touch it including 'fis: update dev fe url in appsettings', 'fix: update the db url in appsettings json'). It contains a live RSA JWT private+public keypair, a Postgres connection string with a plaintext password (Host=148.251.86.78;Database=Pss2.0_Dev_latest;Username=appuser;Password=sKeIGZ2ejuGr;Port=5434), a Security.EncryptionKey, a PaymentGateway.CredentialEncryptionKey, and a SendGrid WebhookVerificationKey, all in cleartext.
- **Gap identified:** The backend .gitignore (PSS_2.0_Backend/.gitignore:55) only excludes 'appsettings.*.json' (env-suffixed variants), not the base file, and no per-environment override file exists anywhere in the repo (confirmed: repo-wide search finds exactly one appsettings*.json outside obj/bin) — so this single committed file is the only configuration source, secrets included.
- **Why it's a problem:** Anyone with read access to the Azure DevOps repo (current/past devs, CI logs, forks) can extract the JWT signing key to forge tokens, decrypt any tenant's payment-gateway credentials via the static AES key, and connect directly to the database. The DB in question is labelled 'Dev_latest', but because there is no separate per-environment secrets layer anywhere in the codebase, there's no evidence these same static encryption/JWT keys aren't reused verbatim if/when promoted toward UAT/Production — and regardless, plaintext credentials of any tier sitting in cleartext git history is a standing compromise path.
- **Recommended solution:** Strip all secret values from appsettings.json, load them from Key Vault/App Service settings/environment variables per environment, purge git history of the exposed values, and rotate every credential (DB password, JWT keypair, EncryptionKey, PaymentGateway key, SendGrid key).
- **Production impact:** Full compromise path: DB access, JWT forgery, decryption of stored payment credentials — amplified by the confirmed absence of any environment-specific config layer (see companion finding), so nothing prevents these same keys from being live in every tier.
- **Business impact:** Regulatory/PCI exposure for a payments product; breach notification obligations if exploited.
- **Technical impact:** Every tenant's encrypted secrets become crackable once the static key is known; JWT trust boundary broken entirely.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/appsettings.json:1-33 (verified by direct read: RSA PrivateKey, Postgres password, EncryptionKey, CredentialEncryptionKey, SendGrid key all in cleartext); PSS_2.0_Backend/.gitignore:55 (only 'appsettings.*.json'); `git log --oneline -- .../appsettings.json` in the backend's own repo shows 19 commits including live DB-URL edits.

### #22 · Cross-cutting — Backend HTTP pipeline — CORS configuration  — `Critical`

- **Module:** Deployment · Config · Ops Readiness  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** Verified: Base.API/DependencyInjection.cs:363-367 — `app.UseCors(option => option.AllowAnyHeader().AllowAnyMethod().SetIsOriginAllowed(_ => true).AllowCredentials());`. `services.AddCors()` (line 39) is called with no policy configuration at all — no named policies are ever registered anywhere in the file (confirmed via grep for AddPolicy: only unrelated rate-limiter policies like 'P2PStartFundraiser' exist, none named 'CorsPolicy').
- **Gap identified:** Confirmed as described. There is also a second, later call `app.UseCors("CorsPolicy")` (line 388) referencing a named policy that was never registered — this is dead/vestigial middleware (ASP.NET Core's default CORS policy provider returns no policy for an unregistered name and no-ops rather than throwing), so it does not mitigate or override the first, fully-open policy which still applies and still sets permissive CORS headers on the response via its earlier-registered OnStarting hook.
- **Why it's a problem:** SetIsOriginAllowed(_ => true) + AllowCredentials() means any origin on the internet can issue credentialed/cookie-bearing cross-origin requests against the API, defeating CORS as a CSRF boundary across every tenant.
- **Recommended solution:** Replace the origin predicate with an explicit allow-list from configuration (Frontend:BaseUrl + known public domains), keep AllowCredentials only for those origins, and remove the dead unnamed 'CorsPolicy' UseCors call or properly register/scope it.
- **Production impact:** Cross-site authenticated request forgery against any logged-in user, any tenant.
- **Business impact:** Direct security/compliance failure for a multi-tenant SaaS handling donations/payments.
- **Technical impact:** CORS trust boundary effectively disabled app-wide; a second UseCors call for a non-existent policy adds confusion/dead code but does not restrict the first.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/DependencyInjection.cs:39 (AddCors() with no policies registered), :363-367 (wildcard+credentials policy), :388 (dead app.UseCors("CorsPolicy") referencing an unregistered name).

### #23 · Cross-cutting — Frontend API base URL — Environment/config management  — `Critical`

- **Module:** Deployment · Config · Ops Readiness  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** Verified by direct read: src/application/configs/navigation-configs/BaseUrlConfig.ts currently sets `export const BASE_URL = "https://localhost:57897";` with the Azure dev URL (`https://devapi-psscorefe.peopleserve.app`) commented out immediately above it. GraphQL/API/SignalR endpoint constants are all template-literal derivations of this one hardcoded value — no `process.env` reference anywhere in the file.
- **Gap identified:** Confirmed — this is a compile-time literal requiring manual comment/uncomment + recommit to move between environments, and its current committed state is localhost.
- **Why it's a problem:** If built from this exact commit, the entire deployed app would attempt to reach a local developer machine — total functional outage — and nothing in the toolchain (TS compiler, lint, CI) would catch it since it's syntactically valid. Confirmed via `git log` that this exact file has been toggled between azurewebsites/peopleserve.app/localhost across at least 10 commits (d46a0ef7, e3382804, bd4fbb3c, etc.), i.e. a real recurring pattern, not a one-off.
- **Recommended solution:** Replace the hardcoded constant with `process.env.NEXT_PUBLIC_API_BASE_URL` (and siblings), inject per-environment via App Service config/pipeline variables, and add a CI guard failing the build if the resolved value is localhost outside local dev.
- **Production impact:** One missed manual edit before a promotion build = total outage of all API/GraphQL/SignalR calls.
- **Business impact:** Silent full-application outage risk tied purely to developer discipline, not tooling.
- **Technical impact:** No single source of truth for environment endpoints; same build artifact cannot be promoted across dev/QA/UAT/prod.
- **Evidence:** PSS_2.0_Frontend/src/application/configs/navigation-configs/BaseUrlConfig.ts:1-11 (verified current value is literally 'https://localhost:57897'); `git log --oneline` on this file in the frontend's own repo shows repeated environment-URL toggling commits (d46a0ef7 and earlier).

### #24 · Cross-cutting — Frontend CI/CD — CI/CD pipeline correctness  — `Critical`

- **Module:** Deployment · Config · Ops Readiness  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** PSS_2.0_Frontend/azure-pipelines.yml (trigger: dev branch, 69 lines) is the more recently-touched of the two pipeline files in the repo (last commit d42204a4 'Updated azure-pipelines.yml'; sibling nextjs-azure-pipeline.yaml, trigger: dev-deployment branch, hasn't been touched since initial setup c825a316) — indicating azure-pipelines.yml is the actively maintained one. Its final step, `- task: AzureWebApp@1`, is indented with 1 leading space vs 2 spaces for every sibling `- task:`/`- script:` entry, and its child keys use 2-space indent vs 4-space for siblings.
- **Gap identified:** Reproduced the parse failure directly: running PyYAML's safe_load against the actual file produces `PARSE ERROR: while parsing a block mapping ... expected <block end>, but found <block sequence start> ... line 59, column 2` — confirming the file is not valid YAML as committed.
- **Why it's a problem:** Azure Pipelines cannot execute past this malformed block from a standard parse, meaning either this exact file has never successfully run past the archive/publish steps (the actual AzureWebApp@1 deploy step never fires from this source), or the live Azure DevOps pipeline definition has silently diverged from git — either way, pipeline-as-code isn't pipeline-as-run.
- **Recommended solution:** Fix indentation so all `- task:` entries share the same 2-space indent and children use consistent 4-space indent; add a YAML lint/validate gate (`az pipelines validate` or equivalent) so this can't recur; add build→test→deploy staging with an approval gate before AzureWebApp@1.
- **Production impact:** Deploy automation for the frontend cannot be trusted to reflect what's in git.
- **Business impact:** Untracked/undocumented deployment process risk; deploys may be happening manually or via a diverged pipeline definition.
- **Technical impact:** YAML fails to parse; no test/lint gate anywhere in the pipeline before shipping to Azure Web App.
- **Evidence:** PSS_2.0_Frontend/azure-pipelines.yml:52 (2-space `- task: PublishBuildArtifacts@1`) vs :59 (1-space ` - task: AzureWebApp@1`) and :60-68 (2-space child indent instead of 4); reproduced with PyYAML: 'PARSE ERROR: while parsing a block mapping ... line 59, column 2' (verified directly against the committed file).

### #25 · Cross-cutting — Frontend root config — Secrets management / TLS  — `Critical`

- **Module:** Deployment · Config · Ops Readiness  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** Verified via `git ls-files` in the frontend's own repo: both .env (NEXTAUTH_SECRET=59fEes2O7ZhNyMiiqD7rMQevspBeUtucvsoSo6KL0o4===) and .env.local (NODE_TLS_REJECT_UNAUTHORIZED=0, with an inline comment reading 'DO NOT set this in production') are tracked. The frontend .gitignore has the standard Next.js `# .env` (line 110) and `# .env*.local` (line 30) lines commented out, so neither pattern is active.
- **Gap identified:** Exactly as described — the NextAuth session-signing secret and a TLS-validation-disabling flag are both committed, tracked files rather than local-only/vaulted values.
- **Why it's a problem:** Anyone with repo access can forge/decrypt NextAuth session cookies since the signing secret is static and public in history. If the Azure pipeline's ArchiveFiles@2 step (which zips '$(System.DefaultWorkingDirectory)' wholesale per azure-pipelines.yml) includes .env.local in the deployed artifact, the TLS-bypass flag would apply to the running production/dev App Service process, not just a developer's machine.
- **Recommended solution:** Un-comment the .env exclusions in .gitignore, purge both files from history, rotate NEXTAUTH_SECRET, and inject it via hosting-platform env config. Never let NODE_TLS_REJECT_UNAUTHORIZED=0 exist in a tracked file.
- **Production impact:** Session forgery risk; potential TLS downgrade if .env.local ships inside the archived build (plausible given the pipeline archives the whole working directory).
- **Business impact:** Account takeover risk across the tenant base if NEXTAUTH_SECRET is exploited.
- **Technical impact:** Auth cookie trust boundary compromised; TLS validation bypass possible in deployed runtime.
- **Evidence:** PSS_2.0_Frontend/.env:1 (verified content); PSS_2.0_Frontend/.env.local:1-4 (verified content, includes the 'DO NOT set this in production' comment); PSS_2.0_Frontend/.gitignore:30,110-111 (`# .env*.local`, `# .env` both commented out); `git ls-files | grep -iE '^\.env'` in frontend repo confirms .env and .env.local are tracked.

### #119 · Cross-cutting — Backend CI/CD — CI/CD pipeline existence  — `High`

- **Module:** Deployment · Config · Ops Readiness  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** Repo-wide search for *.yml/*.yaml under PSS_2.0_Backend (excluding obj/bin) returns only PeopleServe/docker-compose.override.yml (a local-dev compose override) plus PeopleServe/docker-compose.dcproj and PeopleServe/Services/Base/Base.API/Dockerfile — no pipeline file exists.
- **Gap identified:** Confirmed — there is no automated build/test/migration/deploy pipeline for the .NET backend anywhere in its own git repo.
- **Why it's a problem:** Backend releases (including migration application, since MigrateAsync only runs in Development — see companion finding) have no reproducible, auditable path from commit to production; deploys are presumably manual with no build/test gate.
- **Recommended solution:** Author an azure-pipelines.yml for Base.API mirroring the frontend's pattern: restore/build/test the solution, run an explicit reviewable migration-apply step, deploy the published artifact with environment-gated approval before Production.
- **Production impact:** No repeatable backend release process; migration application entirely undocumented for non-dev environments.
- **Business impact:** Release risk and audit-trail gap for a regulated NGO/finance-adjacent product.
- **Technical impact:** No CI gate (build/test) exists before backend code reaches any deployed environment.
- **Evidence:** Verified via `find` over the backend's own repo for *.yml/*.yaml → only PeopleServe/docker-compose.override.yml; PeopleServe/Services/Base/Base.API/Dockerfile exists but no pipeline file references it.

### #120 · Cross-cutting — Backend configuration loading — Environment/config management  — `High`

- **Module:** Deployment · Config · Ops Readiness  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** Verified: Base.API/DependencyInjection.cs:407-408 — `builder.Configuration.AddJsonFile("appsettings.json", optional: true, ...).AddJsonFile($"appsettings.{environment}.json", optional: true, ...)`, expecting per-environment override files.
- **Gap identified:** Confirmed by repo-wide search: the only appsettings*.json file anywhere in the backend repo (outside obj/bin) is the single base appsettings.json. No appsettings.Development/QA/UAT/Production.json exist.
- **Why it's a problem:** Since the base file holds real credentials and static keys (see companion secrets finding) and no environment-specific override layer exists in source control, every environment either shares those exact values unless someone hand-edits the file per deploy (same fragile pattern as BaseUrlConfig.ts), or relies entirely on undocumented out-of-repo App Service configuration that can't be reviewed or reproduced from source.
- **Recommended solution:** Introduce real appsettings.{Environment}.json files (secrets-free, Key-Vault-backed) per target environment, or move entirely to environment-variable/Key-Vault-backed configuration and strip literal values from the checked-in file.
- **Production impact:** No environment-specific configuration exists in source control; deploy-time config is either manual or invisible.
- **Business impact:** Cannot audit or reproduce what configuration actually runs in QA/UAT/Production from the codebase.
- **Technical impact:** Config-loading code expects a layering pattern the repo never populates.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/DependencyInjection.cs:407-408 (AddJsonFile pattern, verified); repo-wide `find . -iname 'appsettings*.json'` excluding obj/bin returns only Base.API/appsettings.json (verified).

### #121 · Cross-cutting — Backend health endpoint — Health/readiness endpoint  — `High`

- **Module:** Deployment · Config · Ops Readiness  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** Verified: Base.API/DependencyInjection.cs:49 — `services.AddHealthChecks().AddSqlServer(configuration.GetConnectionString("Database")!);` exposed via `app.UseHealthChecks("/health", ...)` at line 393. The actual DB provider is Postgres — Base.Infrastructure/DependencyInjection.cs:44 `options.UseNpgsql(connectionString, ...)` — and the live connection string (appsettings.json) is Npgsql-format (`Host=...;Username=...;Password=...`). Directory.Packages.props:45 references only `AspNetCore.HealthChecks.SqlServer`; no Npgsql health-check package exists anywhere in the repo.
- **Gap identified:** Confirmed exactly as described — AddSqlServer uses Microsoft.Data.SqlClient's SqlConnectionStringBuilder/SqlConnection, which does not recognize Npgsql keywords like 'Host' or 'Username' and will throw (ArgumentException: keyword not supported) when the health check tries to open a connection using this string.
- **Why it's a problem:** The /health endpoint — the exact signal an orchestrator uses for routing/restart decisions — will misreport DB health (Unhealthy or exception) regardless of actual Postgres availability, making it either useless or actively harmful (spurious restarts, or false negatives hiding a real outage).
- **Recommended solution:** Swap to AspNetCore.HealthChecks.NpgSql pointed at the same connection string, verify /health returns Healthy, wire into the App Service health-check config.
- **Production impact:** Readiness/liveness signal is unreliable or broken.
- **Business impact:** Outage detection/auto-recovery for the whole platform cannot be trusted.
- **Technical impact:** Health-check package mismatched to actual DB provider.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/DependencyInjection.cs:49 (AddSqlServer); PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/DependencyInjection.cs:44 (UseNpgsql); PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/appsettings.json:14 (Postgres-format connection string, verified via direct read); PSS_2.0_Backend/PeopleServe/Directory.Packages.props:45-46 (AspNetCore.HealthChecks.SqlServer 9.0.0 only, no Npgsql health-check package present).

### #122 · Cross-cutting — Backend startup (Program.cs) — DB migration strategy  — `High`

- **Module:** Deployment · Config · Ops Readiness  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** Verified: Base.API/Program.cs:56-60 — `if (app.Environment.IsDevelopment()) { await app.InitialiseDatabaseAsync(); app.UseHangfireDashboard("/hangfire"); }`, and InitialiseDatabaseAsync (Base.Infrastructure/Data/Extensions/DatabaseExtentions.cs:12) calls `context.Database.MigrateAsync()`. This runs ONLY when ASPNETCORE_ENVIRONMENT=Development.
- **Gap identified:** Confirmed — no pipeline, console app, or script anywhere in the repo applies migrations for non-Development environments. Combined with the confirmed absence of any backend CI/CD pipeline and only one appsettings.json existing in the whole repo, there is no visible, repeatable mechanism for migrations to reach QA/UAT/Production.
- **Why it's a problem:** 320 migration files (.cs incl. Designer, verified count) exist under source control; without an explicit tracked apply step, schema drift (migrations merged but never applied, or applied ad hoc against the wrong target) is a standing risk each release.
- **Recommended solution:** Add an explicit, reviewed migration-apply step (e.g. `dotnet ef migrations bundle` run against the target connection string) as its own gated pipeline stage, separate from app startup, so migrations are never silently skipped or run implicitly by whichever instance starts first.
- **Production impact:** Schema drift / manual, undocumented migration application to production.
- **Business impact:** Release risk; data-loss risk if migrations are ever applied out of order or against the wrong target manually.
- **Technical impact:** 320 migrations under source control with no traceable apply mechanism outside Development.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/Program.cs:56-60 (verified); PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Extensions/DatabaseExtentions.cs:7-12 (verified); `find .../Migrations -iname '*.cs' | wc -l` → 320 (verified count matches finding exactly).

### #231 · Cross-cutting — Backend host validation — Config hardening  — `Medium`

- **Module:** Deployment · Config · Ops Readiness  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** "AllowedHosts": "*" in appsettings.json.
- **Gap identified:** ASP.NET Core's host-header validation middleware is effectively disabled (wildcard allows any Host header).
- **Why it's a problem:** Combined with the CORS finding (SetIsOriginAllowed always true), the API has no host-header defense-in-depth layer either, widening the surface for host-header-based attacks (cache poisoning, password-reset-link poisoning if any host-derived URLs are generated).
- **Recommended solution:** Set AllowedHosts to the real API domain(s) (e.g. the App Service default host + any custom domain) per environment instead of "*".
- **Production impact:** Host-header validation provides no protection in any environment.
- **Business impact:** Marginal but real widening of attack surface for a public-facing donation platform.
- **Technical impact:** Wildcard host allow-list.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/appsettings.json:39.
- **Reviewer note:** not adversarially verified (Medium/Low)

### #232 · Cross-cutting — Hangfire background jobs — Operational visibility / dashboard  — `Medium`

- **Module:** Deployment · Config · Ops Readiness  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** `app.UseHangfireDashboard("/hangfire")` is only called inside the `if (app.Environment.IsDevelopment())` block in Program.cs, alongside the dev-only DB migration call.
- **Gap identified:** The Hangfire dashboard — the only UI for inspecting recurring/background job history, failures, and retries (email sends, PayU recurring charges, event-communication dispatch, import jobs) — is unreachable in QA/UAT/Production.
- **Why it's a problem:** Ops/support staff have zero visibility into background job health in any deployed environment; a stuck or failing recurring job (e.g. the PayU SI recurring-charge cron or the event-communication dispatcher) would only be discoverable via raw log files, not any dashboard, delaying incident detection for money-moving jobs.
- **Recommended solution:** Enable the Hangfire dashboard in non-Development environments behind proper authorization (e.g. `IDashboardAuthorizationFilter` restricted to admin roles) rather than disabling it outright.
- **Production impact:** No operational visibility into background/recurring jobs outside local dev.
- **Business impact:** Slower incident response for payment-related recurring jobs (PayU SI charges) if they silently fail.
- **Technical impact:** Dashboard middleware registration is environment-gated with no authenticated production alternative.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/Program.cs:56-60 (UseHangfireDashboard inside IsDevelopment block only).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #233 · Cross-cutting — Public anonymous endpoints (Donation/P2P/CrowdFund/Prayer/Volunteer/Event) — Rate limiting / graceful degradation under scale  — `Medium`

- **Module:** Deployment · Config · Ops Readiness  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** All public-facing rate limit policies (P2PStartFundraiser, P2PDonationSubmit, PublicSubmitRateLimit, PublicPrayedRateLimit, VolunteerSubmit, CrowdFundDonationSubmit, DonationSubmit, EventRegistrationSubmit) are implemented with ASP.NET Core's built-in `RateLimitPartition.GetFixedWindowLimiter`, which stores counters in-process memory.
- **Gap identified:** None of these limiters use a distributed backing store (e.g. Redis); each App Service instance keeps its own independent counter.
- **Why it's a problem:** The moment the backend scales to more than one instance (standard for production availability), the effective rate limit for every public money/registration endpoint becomes PermitLimit × instanceCount, silently weakening the anti-abuse/anti-fraud protection these limits were added for (per the code comments referencing prior incidents, e.g. ODP-B1 unbounded donation submit).
- **Recommended solution:** Back the rate limiter with a distributed store (e.g. a Redis-based partitioned limiter, or Azure API Management rate limiting at the edge) so limits hold true regardless of instance count.
- **Production impact:** Anti-abuse controls degrade proportionally to horizontal scale-out.
- **Business impact:** Increased fraud/spam exposure on public donation and registration funnels precisely when traffic (and instance count) is highest.
- **Technical impact:** In-memory FixedWindowRateLimiter is not scale-out safe.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/DependencyInjection.cs:226-339 (all AddPolicy calls use RateLimitPartition.GetFixedWindowLimiter with no distributed cache/store).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #317 · Cross-cutting — Backend exception handling wiring — Global error handling  — `Low`

- **Module:** Deployment · Config · Ops Readiness  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** `services.AddExceptionHandler<CustomExceptionHandler>();` registers a custom IExceptionHandler in DI, but no `app.UseExceptionHandler(...)` call exists anywhere in the pipeline to actually invoke it; a separate `app.UseMiddleware<ErrorHandlingMiddleware>()` is the middleware actually wired into the request pipeline.
- **Gap identified:** CustomExceptionHandler is registered but never executed — dead configuration that silently does nothing.
- **Why it's a problem:** This is a maintenance trap: a future developer modifying CustomExceptionHandler (e.g. to change error response shape for a specific exception type) would reasonably assume it's live and be confused when behavior doesn't change, since ErrorHandlingMiddleware is the actual active handler.
- **Recommended solution:** Either remove the unused AddExceptionHandler<CustomExceptionHandler>() registration, or replace ErrorHandlingMiddleware with the proper `app.UseExceptionHandler()` + `IExceptionHandler` pipeline pattern consistently.
- **Production impact:** No functional impact today (ErrorHandlingMiddleware covers error handling), but represents config drift that will mislead future changes.
- **Business impact:** Low; developer-time risk only.
- **Technical impact:** Two competing, only-one-live exception-handling mechanisms registered in the same app.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/DependencyInjection.cs:48 (AddExceptionHandler<CustomExceptionHandler>, no matching UseExceptionHandler found anywhere in Base.API); PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/DependencyInjection.cs:372 (app.UseMiddleware<ErrorHandlingMiddleware>() is the actual active handler).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #318 · Cross-cutting — Local dev docker override — Environment/config management  — `Low`

- **Module:** Deployment · Config · Ops Readiness  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** docker-compose.override.yml hardcodes `ASPNETCORE_ENVIRONMENT=Development` for the base.api service, with no corresponding non-dev compose file in the repo.
- **Gap identified:** If this override file were ever used as a template for any hosted container deployment (rather than purely local dev-with-Visual-Studio), it would force Development-mode behavior — auto migrations, Hangfire dashboard exposed, verbose errors — in that environment.
- **Why it's a problem:** Given there is no backend CI/CD pipeline and no environment-specific appsettings (companion findings), this docker-compose file is the only containerization artifact in the repo; without a documented, separate production compose/pipeline path, there's a real risk of this dev-oriented config being reused as a starting point for an actual deployment.
- **Recommended solution:** Add a clearly separate docker-compose.prod.yml (or equivalent App Service/pipeline config) that never sets ASPNETCORE_ENVIRONMENT=Development, and document that docker-compose.override.yml is local-dev-only.
- **Production impact:** Latent risk of dev-mode settings reaching a non-dev container deployment.
- **Business impact:** Low today given no pipeline references this file, but a documentation/process gap.
- **Technical impact:** Single compose file mixes dev-only concerns with no prod counterpart.
- **Evidence:** PSS_2.0_Backend/PeopleServe/docker-compose.override.yml:1-12.
- **Reviewer note:** not adversarially verified (Medium/Low)

## QA & Testing Gaps

### #56 · All COMPLETED screens (per REGISTRY.md) — E2E test coverage breadth  — `Critical`

- **Module:** QA & Testing Gaps  |  **Category:** qa  |  **Verification:** ADJUSTED
- **Current implementation:** tests/e2e/screens/ contains exactly 2 spec files (branch.spec.ts, onlinedonationpage.spec.ts) — confirmed by directory listing. REGISTRY.md has 211 rows with status '| COMPLETED |' (slightly fewer than the cited 213, likely due to duplicate historical rows in the file — immaterial to the finding). TESTING-TRACKER.md Summary table confirmed verbatim: Total 47 / Tested 0 / Pass 0 / Issues 0 / Failed 0, covering 46 COMPLETED + 1 NEEDS_FIX (#19).
- **Gap identified:** Automated Playwright coverage exists for ~1% of shipped screens; 0/47 manual test tasks in the tracker have been executed.
- **Why it's a problem:** The overwhelming majority of business flows (approval workflows, financial calcs, cascades, FK guards) have never been exercised end-to-end by anyone, automated or manual.
- **Recommended solution:** Execute the TESTING-TRACKER.md backlog as a release-blocking gate; extend Playwright coverage via /test-batch to money-moving/workflow-heavy screens before GA.
- **Production impact:** Vast majority of 'production-ready' screens have had no human or automated end-to-end verification of actual business logic.
- **Business impact:** Undiscovered breakage in core NGO workflows at go-live.
- **Technical impact:** No regression detection across ~98%+ of the screen inventory.
- **Evidence:** .claude/screen-tracker/TESTING-TRACKER.md:144-157 (Summary table verified verbatim: Total 47/Tested 0/Pass 0); tests/e2e/screens/ directory listing confirms only branch.spec.ts and onlinedonationpage.spec.ts exist. Minor correction: REGISTRY.md has 211 (not 213) rows literally marked '| COMPLETED |'.

### #57 · All screens / multi-tenant data model — Tenant-isolation testing  — `Critical`

- **Module:** QA & Testing Gaps  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** Confirmed 0 matches for `HasQueryFilter` anywhere under Base.Infrastructure. Confirmed no OnModelCreating-level global filter mechanism of any kind (checked DbContext files, only found per-repository ad hoc IsDeleted checks, nothing tenant-related). 835 files under Base.Application reference CompanyId (close to the cited 828 — a version/count drift, not material). auth.setup.ts confirmed to use a single hardcoded credential set (E2E_USERNAME/E2E_PASSWORD/E2E_TENANT env vars, never varied across specs).
- **Gap identified:** No EF Core global query filter for CompanyId exists as a defense-in-depth safety net, and no automated test (BE or E2E) asserts any handler is correctly tenant-scoped.
- **Why it's a problem:** With manual per-handler filtering as the ONLY tenant boundary and zero tests asserting it, a single missed CompanyId predicate in any of 800+ files leaks another NGO's data, and nothing would catch it.
- **Recommended solution:** Add a global HasQueryFilter(e => e.CompanyId == _tenantContext.CompanyId) at the DbContext level, plus a two-tenant-seeded integration test suite asserting zero cross-tenant leakage on list/get queries.
- **Production impact:** No automated verification that tenant isolation holds across any of the CompanyId-touching files.
- **Business impact:** Cross-tenant data leakage is a contractual/legal breach for a multi-tenant NGO SaaS holding donor PII and financial records.
- **Technical impact:** Tenant boundary is entirely manual/per-handler with zero automated regression protection.
- **Evidence:** Verified: 0 HasQueryFilter matches in Base.Infrastructure; 835 files under Base.Application reference CompanyId (cited count of 828 is close, minor drift); tests/e2e/shared/auth.setup.ts confirmed single hardcoded USERNAME/PASSWORD/TENANT with no per-spec variation.

### #58 · CI/CD pipeline (Azure Pipelines) — Automated test gate before deploy  — `Critical`

- **Module:** QA & Testing Gaps  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** Read PSS_2.0_Frontend/azure-pipelines.yml in full: steps are NodeTool@0 → inline script (pnpm install/build + startup.sh generation) → ArchiveFiles@2 → PublishBuildArtifacts@1 → AzureWebApp@1. No test/lint task at any stage. Confirmed only one azure-pipelines*.yml exists in the whole repo (frontend only; no backend pipeline file at all).
- **Gap identified:** No `pnpm test`/Playwright/`dotnet test` step gates the deploy; a syntactically-valid but functionally-broken build ships as soon as `pnpm build` succeeds.
- **Why it's a problem:** No automated gate prevents a broken build (functionally) from reaching production.
- **Recommended solution:** Add a `dotnet test` stage (once a BE test project exists) and a Playwright test stage gating AzureWebApp@1; fail pipeline on red.
- **Production impact:** Broken screens/flows can deploy straight to production with zero automated check.
- **Business impact:** Outages/broken donation flows discovered by users instead of pre-release.
- **Technical impact:** Pipeline provides zero quality signal beyond 'it compiled'.
- **Evidence:** PSS_2.0_Frontend/azure-pipelines.yml (full file read): steps = NodeTool@0 → inline build script → ArchiveFiles@2 → PublishBuildArtifacts@1 → AzureWebApp@1; no test task present anywhere in the file.

### #59 · Entire Backend (all 175+ screens/entities) — Backend automated test coverage  — `Critical`

- **Module:** QA & Testing Gaps  |  **Category:** qa  |  **Verification:** CONFIRMED
- **Current implementation:** Backend solution has exactly 5 csproj files (Base.API, Base.Application, Base.Domain, Base.Infrastructure, Base.Support); confirmed via `find PSS_2.0_Backend -iname '*.csproj'`. No Tests project directory exists (searched for '*Test*' dirs — only command-folder hits like `UpdateStatusCommand`/`TestConnectionCommand` matched, no actual test project).
- **Gap identified:** Zero unit/integration tests for the entire .NET 8 backend; no xunit/nunit/Moq package reference in any csproj.
- **Why it's a problem:** Every CQRS handler, workflow guard, FX conversion, and multi-tenant filter is verified only by manual click-through; regressions in shared code can silently break dozens of screens with no automated signal.
- **Recommended solution:** Stand up Base.Application.Tests (handler/validator unit tests, mocked repos) and Base.API.IntegrationTests (WebApplicationFactory + Testcontainers Postgres); prioritize money-moving/state-machine handlers first.
- **Production impact:** Silent regressions ship undetected; only safety net is manual QA which the tracker shows is not executed.
- **Business impact:** Money-handling bugs reach donors/funders before detection.
- **Technical impact:** No regression safety net for CQRS handlers shared across the whole product.
- **Evidence:** Verified via `find PSS_2.0_Backend -iname '*.csproj'` → only the 5 Base.* projects; no *.Tests directory found; no xunit/nunit/Moq reference located.

### #60 · Online Donation Page (#10, EXTERNAL_PAGE / public anonymous surface) — Public-facing hardening tests (CSRF, honeypot, rate-limit, reCAPTCHA)  — `Critical`

- **Module:** QA & Testing Gaps  |  **Category:** security  |  **Verification:** ADJUSTED
- **Current implementation:** Read onlinedonationpage.spec.ts in full and confirmed: 8 real test() blocks, 25 test.skip() blocks (not 26 — the finding's number reflects the Run 1 test-result.md snapshot; since then the two CSP frame-ancestors tests, previously one skipped item, were implemented as 2 real request-based tests per 'ODP-H8/ISSUE-8 CLOSED' comment, raising real-test count from 6→8 and lowering skip count from 26→25). Confirmed line-exact: line 268-270 skips 'CSRF token issued + validated; honeypot rejects bot fill; rate-limit 5/min/IP' and line 324-325 skips 'reCAPTCHA v3 token verified server-side'. test-result.md frontmatter confirms last_run_status: INFRA_ERROR, total_runs: 1 (stale — spec has been modified since without a re-run logged).
- **Gap identified:** CSRF, honeypot, rate-limit, and reCAPTCHA verification remain unautomated stubs; the one recorded run never executed even the real smoke tests (missing E2E credentials).
- **Why it's a problem:** The most security-sensitive, unauthenticated, money-accepting endpoint in the product has none of its abuse-prevention controls under automated test — a regression silently disabling rate-limiting or CSRF would ship undetected.
- **Recommended solution:** Wire the public-mutation Playwright helper (rate-limit, CSRF, honeypot) referenced in ISSUE-19, unskip these tests, and log a fresh Run entry reflecting the now-real CSP tests before considering this screen production-safe.
- **Production impact:** Anonymous donation endpoint's abuse-prevention controls are unverified by any automated check.
- **Business impact:** Bot spam, fraud, or CSRF-driven unauthorized donations could occur undetected.
- **Technical impact:** 25/33 tests are skipped stubs (not 26/32 as originally stated — 2 CSP tests were unskipped since the last logged run); the real tests have never actually executed end-to-end (INFRA_ERROR, stale by at least one spec revision).
- **Evidence:** PSS_2.0_Frontend/tests/e2e/screens/onlinedonationpage.spec.ts:268-270,324-325 (verified verbatim — still test.skip()); .claude/screen-tracker/prompts/onlinedonationpage.test-result.md:22-27 (INFRA_ERROR, 26 skipped — but this is now stale versus the current spec file, which has 25 skips + 2 newly-real CSP tests per an inline comment referencing 'ODP-H8/ISSUE-8 CLOSED').

### #166 · All entities (Grant, Case, Donation, Pledge, Refund, etc.) — Concurrent-edit / optimistic-concurrency testing  — `High`

- **Module:** QA & Testing Gaps  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** Confirmed 0 matches for IsConcurrencyToken, RowVersion, ConcurrencyCheck (and checked for [Timestamp]/xmin patterns too) across all of Base.Infrastructure.
- **Gap identified:** No entity has an EF concurrency token configured, so concurrent edits silently last-write-win with no conflict detection, and no test exists (because there's no mechanism to test).
- **Why it's a problem:** In a multi-user NGO admin tool, concurrent edits on shared Case/Grant/Pledge/Donation records are routine, not an edge case; silent overwrite is a data-loss bug no test surfaces.
- **Recommended solution:** Add a byte[] RowVersion concurrency token to high-contention entities (Case, Grant, Pledge, GlobalDonation) plus a backend integration test asserting a second concurrent SaveChanges throws DbUpdateConcurrencyException.
- **Production impact:** No automated proof that concurrent writes behave safely — because they currently don't.
- **Business impact:** Two staff working the same Case/Grant can silently clobber each other's changes with no warning.
- **Technical impact:** Absence of concurrency tokens confirmed by absence of any matching pattern in the entire infrastructure layer.
- **Evidence:** Verified via grep across Base.Infrastructure for IsConcurrencyToken|RowVersion|ConcurrencyCheck|xmin|[Timestamp] → 0 matches.

### #167 · All screens using role-based capability (BUSINESSADMIN vs restricted roles) — RBAC / permission-denial tests  — `High`

- **Module:** QA & Testing Gaps  |  **Category:** security  |  **Verification:** ADJUSTED
- **Current implementation:** Confirmed playwright.config.ts (actual path: PSS_2.0_Frontend/tests/e2e/playwright.config.ts, not the cited root-level path) defines exactly 2 projects: 'setup' (runs auth.setup.ts) and 'chromium' (depends on setup, uses the single persisted storageState.json). No second role/tenant project exists. auth.setup.ts confirmed to use one hardcoded credential triple with no role variable.
- **Gap identified:** No E2E or BE test exercises a non-BUSINESSADMIN role or verifies a 403/permission-denied path on any mutation.
- **Why it's a problem:** Per project convention, FE only gates button visibility, not enablement — server-side authorization is the sole real gate, and it is entirely untested by automation.
- **Recommended solution:** Add a second Playwright auth project (restricted role) plus backend integration tests asserting low-privilege mutation attempts return a GraphQL authorization error for money-moving mutations.
- **Production impact:** Authorization enforcement is unverified by any automated test across the product.
- **Business impact:** A staff member without approval rights could execute privileged actions if a handler is missing its authorization check, undetected.
- **Technical impact:** Single-role test harness cannot detect authorization regressions by construction.
- **Evidence:** PSS_2.0_Frontend/tests/e2e/playwright.config.ts:92-117 (verified: exactly 'setup' + 'chromium' projects, no second-role project) and tests/e2e/shared/auth.setup.ts:23-32 (verified: single USERNAME/PASSWORD/TENANT, no role variable). Path in original finding (playwright.config.ts at repo-relative root) was slightly off — actual file lives under tests/e2e/, not the frontend root — but the substance is confirmed.

### #168 · Background jobs (OpenExchangeRatesSyncJob, AuditQueueDrainer) — Background-job test coverage  — `High`

- **Module:** QA & Testing Gaps  |  **Category:** qa  |  **Verification:** ADJUSTED
- **Current implementation:** Confirmed HostedServices/ contains exactly 2 BackgroundService/IHostedService implementations (OpenExchangeRatesSyncJob.cs, AuditQueueDrainer.cs). Read OpenExchangeRatesSyncJob.cs header comment confirming it syncs FX rates daily at 04:00 UTC and is also invoked manually via TriggerOpenExchangeRatesSyncCommand; note it defaults OFF (Fx:AutoSyncEnabled=false) until an admin flips it on. Additionally found the product also uses Hangfire for dynamic recurring jobs (RecurringJob.AddOrUpdate/RemoveIfExists in Import Schedule and Email Send Job commands, plus BackgroundJob.Enqueue in EmailExecutorService) — these are a separate, equally-untested background surface not captured by the finding's narrow 'BackgroundService' framing, which if anything broadens rather than narrows the real gap.
- **Gap identified:** The FX-sync job and audit-queue drainer have zero test coverage for sync/parse logic, error handling, or idempotency; the broader Hangfire-based recurring-job surface (imports, email sends) is equally untested since no BE test project exists.
- **Why it's a problem:** A silent failure in FX sync (once enabled) would record donations at a stale/wrong rate undetected; a stuck AuditQueueDrainer would silently stop producing audit records.
- **Recommended solution:** Add unit tests for sync/parse logic (mock HttpClient) and an integration test asserting correct upsert behavior, plus a drainer test for poison-message handling; extend coverage to the Hangfire-based import/email recurring jobs.
- **Production impact:** Production-critical scheduled/background logic (currency correctness, audit trail, plus Hangfire-driven imports/email) runs entirely untested.
- **Business impact:** Wrong FX rates (once auto-sync is enabled) mis-value multi-currency donations; audit trail gaps undermine compliance.
- **Technical impact:** No regression protection on any scheduled job in the codebase, BackgroundService-based or Hangfire-based.
- **Evidence:** Verified exactly 2 files implementing BackgroundService/IHostedService under HostedServices/; OpenExchangeRatesSyncJob.cs header docs confirm daily FX sync purpose (default-off flag noted as a minor mitigating detail not in the original finding). No test project exists to cover any of this (per Finding 1).

### #169 · Branch (#41, MASTER_GRID) — E2E test stability / actual pass rate  — `High`

- **Module:** QA & Testing Gaps  |  **Category:** qa  |  **Verification:** CONFIRMED
- **Current implementation:** Read .claude/screen-tracker/prompts/branch.test-result.md in full. Frontmatter confirms verbatim: last_run_status: NEEDS_FIX, total_runs: 7, passed_last_run: 2, failed_last_run: 14, skipped_last_run: 5. Run 7 body documents the 14 concrete failures (grid-timeout ×8, FK react-select selector ×2, testid hooks missing ×2 for branch-widgets/side-panel, toggle-vs-modal mismatch, 12-column assertion) exactly as summarized in the finding.
- **Gap identified:** The most-iterated E2E suite in the product has never gone green across 7 runs; underlying screen behavior (widgets, side-panel, FK cascades) remains functionally unverified by this suite.
- **Why it's a problem:** If the flagship best-covered screen is still NEEDS_FIX after 7 iterations, true confidence in the other 200+ screens (with zero specs) is lower still.
- **Recommended solution:** Run /test-fix #41 --until-green to close the 14 real failures before treating Branch as validated; use only as template once fully green.
- **Production impact:** Widgets, side-panel Quick Stats, and FK cascades on Branch are unverified in any automated way.
- **Business impact:** Org-structure data errors go unnoticed.
- **Technical impact:** Harness itself (module/menu warm-up, moduleCode seeding) took 6 runs to stabilize before real assertions could execute.
- **Evidence:** .claude/screen-tracker/prompts/branch.test-result.md:16-90 — frontmatter and Run 7 table verified verbatim, matching the finding exactly.

### #170 · Money-moving workflow screens (Refund #13, Grant #62, Pledge #12, Recurring Donation #8, Cheque Donation #6) — Negative/boundary business-flow test coverage  — `High`

- **Module:** QA & Testing Gaps  |  **Category:** qa  |  **Verification:** CONFIRMED
- **Current implementation:** Confirmed TESTING-TRACKER.md rows for #6, #8, #12, #13, #62 all show ⬜ NOT_TESTED with the exact descriptions cited (Cheque Donation 3-modal kanban, Recurring Donation 9 commands, Pledge PAID-history-preserving regen, Refund 5-state PEN→APR→PRO→REF/REJ, Grant 5-workflow-cmd kanban). Confirmed no spec file exists for any of these screen numbers — tests/e2e/screens/ contains only branch.spec.ts and onlinedonationpage.spec.ts.
- **Gap identified:** No automated or manual test verifies any of these state-machine guard conditions (illegal transitions, PAID-history preservation, commitment-aware guards).
- **Why it's a problem:** These are exactly the money-in-motion, multi-state-transition flows most likely to have subtle AI-generated guard-condition bugs, and none of it is covered by any test.
- **Recommended solution:** Author Playwright specs or BE integration tests specifically asserting illegal transitions are rejected and that Pledge Update preserves prior PAID PledgePayment rows.
- **Production impact:** State-machine guard bugs in financial workflows are undetectable until a real user hits them in production.
- **Business impact:** Double refunds, incorrectly approved grant tranches, or lost pledge-payment history directly cost the organization money or corrupt donor records.
- **Technical impact:** No regression protection on any workflow state-machine in the fundraising/grant domain.
- **Evidence:** .claude/screen-tracker/TESTING-TRACKER.md rows for #6 (line 51), #8 (line 53), #12 (line 136), #13 (line 137), #62 (line 120) — all verified ⬜ NOT_TESTED verbatim; confirmed no spec file exists for any of these screen numbers in tests/e2e/screens/.

### #274 · E2E test harness (all specs) — Test data isolation / cleanup  — `Medium`

- **Module:** QA & Testing Gaps  |  **Category:** qa  |  **Verification:** CONFIRMED
- **Current implementation:** tests/e2e/shared/test-data.ts's cleanupTestRows() delegates the actual delete to a per-spec callback; in branch.spec.ts:69-76 that callback is an empty stub with a comment stating 'rows leak harmlessly until the delete is wired.'
- **Gap identified:** Test data cleanup is not actually implemented for the one screen that has a spec — every Playwright run against a shared/persistent environment leaves `_TEST_*` Branch rows behind permanently.
- **Why it's a problem:** Repeated CI/local runs against a shared dev or staging database will accumulate test-junk rows indefinitely, polluting FK dropdowns, grid counts, and KPI aggregates (e.g., Branch's 'Total Branches' widget) for real users/testers, and risking test-vs-test interference since workers=1 is required specifically because 'the DB isn't isolated per worker' (playwright.config.ts:59-61).
- **Recommended solution:** Wire the DeleteBranch GraphQL mutation (and equivalent for every future spec) into cleanupTestRows, or move to a disposable per-run test database/schema so cleanup isn't load-bearing.
- **Production impact:** Non-production but directly undermines trust in any shared test/staging environment's data integrity.
- **Business impact:** Low direct business impact, but corrupts demo/staging environments used for stakeholder review.
- **Technical impact:** Confirms the test infrastructure itself is not yet production-grade — even its own hygiene mechanism is an unimplemented stub.
- **Evidence:** PSS_2.0_Frontend/tests/e2e/screens/branch.spec.ts:69-76 (empty cleanup stub); tests/e2e/shared/test-data.ts:46-59 (cleanupTestRows delegates to per-spec callback that may be a no-op); playwright.config.ts:59-62 (workers forced to 1 because DB isn't isolated per worker).
- **Reviewer note:** not adversarially verified (Medium/Low)

## Organization · Events & Staff

### #47 · Auction Management — Multi-tenant isolation (CompanyId scoping)  — `Critical`

- **Module:** Organization · Events & Staff  |  **Category:** Security / Multi-Tenancy  |  **Verification:** CONFIRMED
- **Current implementation:** All Auction module command/query handlers load AuctionItem exclusively by AuctionItemId with no CompanyId predicate: PlaceBid.cs (lines 44-48), RecordPaymentAuctionItem.cs, AwardAuctionItem.cs, PauseAuctionItem.cs, ResumeAuctionItem.cs, LowerReserveAuctionItem.cs, ReAuctionAuctionItem.cs, DeleteAuctionItem.cs, and GetAuctionItems.cs (scoped only by eventAuctionId, no CompanyId filter) were all read in full and confirmed to follow this identical pattern. In PlaceBid.cs, companyId IS resolved via httpContextAccessor.GetCurrentUserStaffCompanyId() (line 42) and stamped onto the newly created AuctionBid row (line 107, CompanyId = companyId), but it is never used to validate that the target AuctionItem itself belongs to the caller's tenant. A repo-wide grep for HasQueryFilter across the entire backend (Base.Infrastructure and beyond) returns zero matches, confirming there is no global EF Core tenant-isolation safety net anywhere in the codebase to compensate.
- **Gap identified:** Any authenticated staff user with AuctionItem.Modify/Delete permission in ANY company/tenant can pass an arbitrary auctionItemId belonging to a DIFFERENT tenant and successfully bid on, award, pause/resume, adjust the reserve of, record payment against, re-auction, or delete that item — a cross-tenant IDOR affecting the entire module's write surface, not an isolated handler.
- **Why it's a problem:** This breaks the fundamental multi-tenant security boundary of the SaaS platform: without per-handler CompanyId scoping AND without a global query filter, tenant data isolation for the entire Auction module is effectively unenforced at the data-access layer.
- **Recommended solution:** Immediate: add `&& a.CompanyId == companyId` to the FirstOrDefaultAsync/Where predicate in all 9 confirmed handlers, resolving companyId from httpContextAccessor at the top of each. Structural: add a global EF Core HasQueryFilter on CompanyId for all tenant-scoped entities (AuctionItem included) in Base.Infrastructure's DbContext OnModelCreating, to prevent this entire class of bug recurring in future handlers.
- **Production impact:** Live cross-tenant data corruption/exposure risk in production for any multi-company deployment using the Auction module.
- **Business impact:** Tenant A staff can manipulate Tenant B's live auction (place bids, award winners, take payments, delete items) — a severe trust and compliance failure for a multi-tenant SaaS.
- **Technical impact:** Confirmed systemic (9/9 handlers checked lack scoping) and confirmed there is no compensating global safety net (zero HasQueryFilter usages anywhere in the codebase) — this is not merely one overlooked handler.
- **Evidence:** PlaceBid.cs lines 42-48/107; RecordPaymentAuctionItem.cs, AwardAuctionItem.cs, PauseAuctionItem.cs, ResumeAuctionItem.cs, LowerReserveAuctionItem.cs, ReAuctionAuctionItem.cs, DeleteAuctionItem.cs (all: FirstOrDefaultAsync(a => a.AuctionItemId == command.auctionItemId, ...) only); GetAuctionItems.cs (Where(x => x.IsDeleted == false && x.EventAuctionId == query.eventAuctionId) only); repo-wide grep for 'HasQueryFilter' returns zero results.

### #48 · Campaign Dashboard — Fundraising progress tracking (TotalDonationCount / TotalDonorCount / ProgressPercentage)  — `Critical`

- **Module:** Organization · Events & Staff  |  **Category:** Data Integrity / Reporting Correctness  |  **Verification:** ADJUSTED
- **Current implementation:** GetCampaignDashboard.cs (line 45) contains the comment 'SERVICE_PLACEHOLDER: aggregate sources missing FK on GlobalDonation — use stored counters' and reverse-computes totalRaised from goal * campaign.ProgressPercentage.Value / 100m (lines 46-48) and totalDonors from the frozen campaign.TotalDonorCount field.
- **Gap identified:** There is no real write path anywhere in the codebase that updates Campaign.ProgressPercentage, TotalDonorCount, or TotalDonationCount from actual donation activity. A repo-wide grep for assignments to these three fields returns exactly one hit: DuplicateCampaign.cs (lines 103-105), which only RESETS them to 0 on duplication — never populates them from real data.
- **Why it's a problem:** The root cause is more severe than a missing write path: GlobalDonation.cs has no CampaignId FK at all (confirmed via grep — zero matches), so donations cannot even be attributed to a campaign at the schema level. Pledge.cs does have a CampaignId column (line 18), but grep confirms zero aggregation queries anywhere use Pledge.CampaignId either. The campaign dashboard is therefore permanently frozen/non-functional for real fundraising progress — every number shown is either 0 or a stale value from creation/duplication.
- **Recommended solution:** Add CampaignId (nullable FK) to GlobalDonation, wire donation-create/void handlers to increment/decrement the three campaign counters transactionally (or compute live via aggregation query instead of stored counters to avoid drift), and add a backfill for existing rows if any exist via Pledge.CampaignId.
- **Production impact:** Campaign fundraising dashboards show static/incorrect progress for the life of the campaign; goal-tracking, donor-count, and progress-bar UI are all non-functional against real data.
- **Business impact:** Fundraising staff and leadership cannot see real campaign performance — a core value proposition of a nonprofit donation platform.
- **Technical impact:** Missing FK is a schema-level gap, not just a missing service call; fixing requires a migration, not just a code patch.
- **Evidence:** Base.Application/Business/ApplicationBusiness/Campaigns/Queries/GetCampaignDashboard.cs lines 45-48; Base.Application/Business/ApplicationBusiness/Campaigns/Commands/DuplicateCampaign.cs lines 103-105 (only reset-to-0 write path found); Base.Domain/Models/DonationModels/GlobalDonation.cs (no CampaignId field present).
- **Reviewer note:** Core finding and Critical priority fully confirmed — in fact the true root cause is worse than originally framed. Correction: this is not merely a 'missing write path' bug fixable in application code alone; GlobalDonation architecturally lacks the CampaignId column needed for real aggregation, so the fix requires a schema migration (new nullable FK) in addition to the write-path/backfill work. recommendedSolution updated accordingly.

### #49 · Event Ticketing — Public Registration Checkout — Per-ticket-type capacity enforcement  — `Critical`

- **Module:** Organization · Events & Staff  |  **Category:** Data Integrity / Business Logic  |  **Verification:** CONFIRMED
- **Current implementation:** InitiateEventRegistration.cs (public #169 flow) checks only regPage.Capacity (event-level aggregate, lines ~319-385) and ticket.Status?.DataValue != "ONSALE" / Visibility != "PUBLIC" (line 292). It never sums existing registrations against ticket.QuantityAvailable.
- **Gap identified:** A specific ticket type (e.g. a 20-seat VIP tier) can be oversold indefinitely through the public checkout as long as the overall event-level capacity has room, because QuantityAvailable is never checked at submission time.
- **Why it's a problem:** Confirmed by direct comparison: the admin-side CreateEventRegistration.cs DOES enforce this per-ticket (line 86: `var wouldExceed = (currentSold + dto.Quantity) > ticket.QuantityAvailable;`), and GetEventRegistrationPageBySlug.cs independently computes IsSoldOut for read-only FE display (line 257) — proving the business rule is known and intended, but the public submission path silently omits the actual guard. There is also no lazy/background job that would retroactively block oversold tickets: GetAllEventTicket.cs only sets a display-only StatusCode = "SOLDOUT" (never persisted, lines 102-110), so the ticket.Status?.DataValue != "ONSALE" gate in the public path never trips even when a ticket type is objectively sold out.
- **Recommended solution:** Add the same per-ticket sold/QuantityAvailable check used in CreateEventRegistration.cs (lines 80-99) into InitiateEventRegistration.cs before accepting a paid/confirmed registration; route overflow to waitlist consistent with waitlistEnabled semantics.
- **Production impact:** Public checkout can oversell any ticket tier without limit; first production event with tiered pricing will overbook VIP/limited seats.
- **Business impact:** Overselling limited-capacity tiers causes refund/complaint volume and reputational damage at in-person events.
- **Technical impact:** No transactional guard on the write path most exposed to anonymous/public traffic (highest-risk entrypoint in the module).
- **Evidence:** Base.Application/Business/ApplicationBusiness/EventRegistrationPages/PublicMutations/InitiateEventRegistration.cs lines 292, 319-385 (event-level only) vs Base.Application/Business/ApplicationBusiness/EventRegistrations/Commands/CreateEventRegistration.cs line 86 (per-ticket check present in admin path only).

### #50 · Event Ticketing / Event Dashboard / Analytics — Registration status resolution consistency  — `Critical`

- **Module:** Organization · Events & Staff  |  **Category:** Data Integrity / Reporting Correctness  |  **Verification:** ADJUSTED
- **Current implementation:** Two independently-evolved MasterData TypeCodes represent the same logical concept: EVENTREGSTATUS (used by the older admin-era code: GetAllEventTicket.cs, CreateEventRegistration.cs, CancelEventRegistration.cs, ApproveEventRegistration.cs, DeleteEventTicket.cs, GetEventTicketingSummary.cs, GetEvent.cs, GetEventDashboardById.cs, GetEventSummary.cs) and EVENTREGISTRATIONSTATUS (used exclusively by the newer #169 public flow: InitiateEventRegistration.cs, ConfirmEventRegistration.cs, GetEventRegistrationPageBySlug.cs, GetAllEventRegistrationPages.cs, GetEventRegistrationPageStats.cs, GetEventRegistrationPageSummary.cs, EventCommunicationDispatcher.cs). Registrations created via the public path are stamped with EVENTREGISTRATIONSTATUS ids; every admin-side query/report/waitlist-promotion filters by EVENTREGSTATUS ids instead, so those rows are systematically invisible.
- **Gap identified:** Registrations submitted through the public registration page (the primary real-world intake channel) are excluded from revenue totals (GetAllEventTicket.cs lines 81-88), the event dashboard (GetEventDashboardById.cs lines 81-91), and — most severely — waitlist promotion (CancelEventRegistration.cs lines 29-78 resolves cancelledId/confirmedId/waitlistId from EVENTREGSTATUS only, so it can never find or promote a waitlisted public registrant on cancellation).
- **Why it's a problem:** This is a systemic taxonomy split across ~9 handlers, not an isolated bug, confirmed via full-codebase grep for both TypeCodes. It causes silent revenue undercounting and broken waitlist promotion for the exact registration channel the #169 feature was built to serve.
- **Recommended solution:** Pick one canonical TypeCode (recommend EVENTREGISTRATIONSTATUS since it is the newer/active public flow) and migrate all ~9 admin-side handlers to resolve against it, backfilling existing EVENTREGSTATUS-tagged rows to the unified MasterData ids. Do NOT rely on any existing SQL function to already handle this dual-lookup — none exists.
- **Production impact:** Every event dashboard/revenue report understates real registration activity for public-channel signups; cancellations on public registrations never trigger waitlist promotion.
- **Business impact:** Finance/ops sees incorrect ticket revenue and registrant counts; waitlisted attendees are never notified when a seat opens up, causing lost revenue and complaints.
- **Technical impact:** Two parallel status-code universes for the same entity indicates the #169 rework was never reconciled with pre-existing admin-side handlers.
- **Evidence:** Grep-confirmed split across Base.Application/Business/ApplicationBusiness/Event* files; CancelEventRegistration.cs lines 29-78 (EVENTREGSTATUS only) cannot match rows created by InitiateEventRegistration.cs (EVENTREGISTRATIONSTATUS only).
- **Reviewer note:** Core bug fully confirmed and priority (Critical) upheld, but two supporting claims in the original evidence/recommendedSolution needed correction: (1) GetEventDashboardById.cs does NOT actually 'work around' the trap for its own query as originally described — it contains a comment explicitly documenting the mismatch (lines 77-80) but still resolves against EVENTREGSTATUS (lines 81-91) exactly like GetAllEventTicket.cs, i.e. it makes the same choice, not a divergent one. (2) The claim that 'SQL analytics functions already correctly [resolve both TypeCodes] via TypeCode IN (...)' is unsubstantiated — a repo-wide grep for this pattern in any .sql file returned zero results. This sentence should be removed from the recommended solution as fabricated/unverifiable.

### #51 · Organization · Staff — Create/Edit — Staff role assignment on create  — `Critical`

- **Module:** Organization · Events & Staff  |  **Category:** Access Control / Data Integrity  |  **Verification:** ADJUSTED
- **Current implementation:** NewUserSubFormDto.RoleId is captured in the FE (staff-accordion-form.tsx line ~392-398: roleId: values.newUser.roleId ?? 0 is included in the newUser payload) and defined server-side in StaffSchemas.cs (NewUserSubFormDto.RoleId, lines 92-98), but CreateStaff.cs never reads or forwards it: Path A (lines 162-184, new user account) builds UserRequestDto with UserName/Password/UserTypeId/ProfilePathUrl/AlternateUserName/CompanyId only — RolesToAssign is never populated from command.staff.NewUser.RoleId in any of the three creation paths (new-user, link-existing, legacy auto-create).
- **Gap identified:** A newly created staff member's selected role is silently discarded server-side; the user account is created with zero roles assigned, since CreateUser.cs (lines 84-92) confirms RolesToAssign is the only mechanism that actually grants roles via AssignUserRolesCommand, and CreateStaff.cs never sets it.
- **Why it's a problem:** The staff record and its linked user account exist with no permissions, silently breaking access for that new hire until an admin manually notices and fixes it via a separate role-assignment screen (if one exists) — a save-time data-loss bug with no client or server error surfaced.
- **Recommended solution:** In CreateStaff.cs Path A (and any other path that creates a new UserRequestDto), map command.staff.NewUser.RoleId into UserRequestDto.RolesToAssign (as a single-element list) before dispatching CreateUserCommand.
- **Production impact:** Every staff member created via the 'new user account' path has no role/permissions post-save until manually corrected.
- **Business impact:** New hires cannot access any module on day one; support/admin overhead to diagnose and fix per-user.
- **Technical impact:** Confirmed dead field end-to-end: FE captures it, DTO carries it, but the handler never reads it.
- **Evidence:** Base.Application/Business/ApplicationBusiness/Staffs/Commands/CreateStaff.cs lines 162-227 (no reference to NewUser.RoleId in any path); Base.Application/Business/AuthBusiness/Users/Commands/CreateUser.cs lines 84-92 (RolesToAssign is the sole role-grant mechanism).
- **Reviewer note:** Backend bug and Critical priority fully confirmed as-is. Minor factual correction only: currentImplementation originally described the FE as validating newUser.roleId as hard-required; in fact staff-accordion-form.tsx line 70 defines it as `z.number().min(1,...).optional().nullable()` with no refine()/superRefine() enforcing it conditionally — so the FE does not even guarantee a role is chosen before submit, compounding (not lessening) the underlying issue. Verdict/priority unchanged.

### #156 · Auction Management — Commission/buyer's-premium, public bidding flow, finance/tax-receipt linkage, award-vs-bid validation  — `High`

- **Module:** Organization · Events & Staff  |  **Category:** Business Logic / Financial Integrity  |  **Verification:** CONFIRMED
- **Current implementation:** AuctionItem.cs (69 lines) has no commission/fee/buyer's-premium field (only EstimatedValue, StartingBid, BidIncrement, ReservePrice, CurrentHighBid, BidsCount, WinningBidAmount, PaymentStatusId/Method/CollectedDate, CurrencyId). PlaceBid.cs's own docstring (line 7) states 'admin manual entry — mocks public bidder flow'. AwardAuctionItemValidator (AwardAuctionItem.cs lines 8-22) only requires winningBidAmount > 0 with no cross-check against entity.CurrentHighBid or the AuctionBid ledger — an admin can award any dollar amount regardless of actual bidding history. GlobalDonation has no AuctionItemId/AuctionId reference (grep-confirmed) and 'commission' appears nowhere in the codebase except the unrelated Ambassador compensation module.
- **Gap identified:** No commission/buyer's-premium field exists on won items; there is no real public/anonymous bidding channel (confirmed by the handler's own docstring); AwardAuctionItem can record a winning amount disconnected from the actual highest bid; and won/paid auction items have no linkage into finance.Donations or tax-receipt generation, so a won-and-paid auction item never produces a receipt through the standard donation pipeline.
- **Why it's a problem:** Auctions are a real-money fundraising channel; without a public bidding surface it cannot function as a live silent/timed auction product, and without award-vs-bid validation plus finance linkage, revenue recognition and donor tax receipting for auction proceeds are entirely manual/outside the system.
- **Recommended solution:** Add a CommissionRate/BuyersPremium field to AuctionItem (or EventAuction as a default); build a real public bid-submission endpoint scoped like InitiateEventRegistration.cs; add a validator rule in AwardAuctionItem requiring winningBidAmount to reconcile with entity.CurrentHighBid or an actual AuctionBid row; add a GlobalDonation creation step (with ReceiptNumber generation, per the DIK-style lifecycle) when RecordPaymentAuctionItem marks an item Paid.
- **Production impact:** Auction module can only be operated as an admin-entry ledger, not a real public auction; won items cannot be reconciled financially or tax-receipted through standard workflows.
- **Business impact:** No commission capture reduces realized revenue tracking; lack of public bidding limits the product's usefulness for live/silent auction events; manual finance reconciliation increases audit risk.
- **Technical impact:** AwardAuctionItem's lack of bid-ledger cross-check is also a data-integrity gap (an item can be 'won' at an amount no one actually bid).
- **Evidence:** Base.Domain/Models/ApplicationModels/AuctionItem.cs (full read, no commission field); Base.Application/Business/ApplicationBusiness/AuctionBids/Commands/PlaceBid.cs line 7 docstring; Base.Application/Business/ApplicationBusiness/AuctionItems/Commands/AwardAuctionItem.cs lines 8-22 (no bid cross-check) and lines 33-54 (StatusId/WinningBidAmount set directly from caller input); grep confirms zero 'commission' hits outside the unrelated Ambassador module and zero AuctionItemId reference in GlobalDonation.

### #157 · Organization · Organizational Unit — Delete — Delete guard dependent-record counts  — `High`

- **Module:** Organization · Events & Staff  |  **Category:** Data Integrity / Referential Safety  |  **Verification:** ADJUSTED
- **Current implementation:** DeleteOrganizationalUnit.cs (lines ~44-56) computes a real descendantsCount via CountAsync against child OrganizationalUnits, but hardcodes `var staffCount = 0; var contactsCount = 0; var donationsCount = 0;` with the comment 'Staff / Contact / Donation counts return 0 (SERVICE_PLACEHOLDER — FKs not wired yet)' before the blocking-condition check.
- **Gap identified:** The delete guard can never actually block a delete due to dependent staff, contacts, or donations — it only ever blocks on child organizational units, regardless of how many staff/contacts/donations are actually linked to the unit.
- **Why it's a problem:** Deleting an organizational unit that still has staff, contacts, or donations attached silently soft-deletes it, orphaning those records' organizational context with no warning to the user — the guard's own UI message implies a real check ('Cannot delete this organizational unit because it has: ... staff ... contacts ... donations') that never fires.
- **Recommended solution:** For staffCount: query the existing `dbContext.OrganizationalUnitStaffs` junction table (confirmed actively populated by AssignStaffToOrganizationalUnit.cs) filtered by OrganizationalUnitId — this requires NO schema change, only wiring the existing table into the guard. For donationsCount: GlobalDonation.cs already has an OrganizationalUnitId column (confirmed present, line 32) — this count is also immediately wireable with no schema change. Only contactsCount is a genuine gap: Contact.cs has no OrganizationalUnitId field at all (grep-confirmed zero matches), so blocking on contacts would require a new FK/relation — this part alone needs new schema work.
- **Production impact:** Deleting an org unit with active staff or recorded donations against it proceeds silently with no integrity check, despite the fix for 2 of the 3 counts requiring zero schema changes.
- **Business impact:** Org-chart cleanup/restructuring can silently orphan staff assignments and donation attribution without any admin warning.
- **Technical impact:** The comment's framing ('FKs not wired yet') is only accurate for the contacts count; staff (via existing OrganizationalUnitStaffs junction) and donations (via existing GlobalDonation.OrganizationalUnitId) already have the necessary FKs and are trivially fixable in the handler alone.
- **Evidence:** Base.Application/Business/ApplicationBusiness/OrganizationalUnits/Commands/DeleteOrganizationalUnit.cs (staffCount/contactsCount/donationsCount hardcoded to 0, SERVICE_PLACEHOLDER comment); AssignStaffToOrganizationalUnit.cs lines 50-71 (OrganizationalUnitStaffs actively populated, proving the staff data source already exists and is unused by the guard); Base.Domain/Models/DonationModels/GlobalDonation.cs line 32 (OrganizationalUnitId FK already present); Base.Domain/Models/ContactModels/Contact.cs (grep confirms no OrganizationalUnitId field — genuine gap only for this one count).
- **Reviewer note:** Core finding fully confirmed as described (all three counts hardcoded to 0) and High priority upheld. Correction/enhancement: the original finding characterized this uniformly as blocked on missing FKs, but investigation shows staffCount and donationsCount are actually trivially fixable today with existing schema (OrganizationalUnitStaffs junction table and GlobalDonation.OrganizationalUnitId column both already exist and are populated) — only contactsCount genuinely requires new schema work (Contact has no OrganizationalUnitId at all). This makes the bug arguably MORE severe from a 'why wasn't this just fixed' standpoint, since 2/3 of the guard could be wired up with a same-day code-only fix.

### #254 · Event Ticketing — Discount code  — `Medium`

- **Module:** Organization · Events & Staff  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** EventTicket.DiscountCode is a modeled, admin-editable string field (persisted by CreateEventTicket.cs/UpdateEventTicket.cs with string-length validation). A grep for 'DiscountCode' across all of Base.Application returns only these two write-side hits plus the DTO declaration — it is never read in InitiateEventRegistration.cs's pricing calculation (`totalAmount = unitPrice * req.Quantity + (req.DonationAmount ?? 0m)`) or anywhere else.
- **Gap identified:** An admin can set a discount code on a ticket type through the UI, but no checkout flow anywhere validates a submitted code against it or applies any discount to the price.
- **Why it's a problem:** The field creates a false impression of a working discount-code feature for admins configuring ticket types, when in fact entering a value has zero effect on what any registrant is ever charged.
- **Recommended solution:** Either implement discount-code validation/application in InitiateEventRegistration.cs's price calculation, or remove the field from the admin ticket-type form until the feature is built.
- **Production impact:** Configured discount codes silently have no effect on checkout pricing.
- **Business impact:** Marketing/fundraising promotions relying on discount codes for events will not actually discount anything, discovered only when a donor complains about being charged full price.
- **Technical impact:** Dead field carried through DTO/entity/validation layers with no corresponding business logic.
- **Evidence:** Base.Domain/Models/ApplicationModels/EventTicket.cs:22 (DiscountCode field); grep for 'DiscountCode' across Base.Application returns only EventTicketSchemas.cs (DTO) and CreateEventTicket.cs/UpdateEventTicket.cs (persistence) — no read/apply site in InitiateEventRegistration.cs's pricing logic.
- **Reviewer note:** not adversarially verified (Medium/Low)

### #255 · Event Ticketing (admin — Create Registration) — Ticket capacity check transaction safety  — `Medium`

- **Module:** Organization · Events & Staff  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** CreateEventRegistration.cs (admin-side registration entry, line 86: `var wouldExceed = (currentSold + dto.Quantity) > ticket.QuantityAvailable;`) performs the read-then-write capacity check with no surrounding database transaction or execution strategy, unlike InitiateEventRegistration.cs's public path which wraps the equivalent check in `Database.CreateExecutionStrategy().ExecuteAsync(...)` + `BeginTransactionAsync` specifically to close the race window.
- **Gap identified:** Two concurrent admin-side registration creations for the same near-capacity ticket type can both read the same currentSold value before either commits, both pass the `wouldExceed` check, and both insert — oversubscribing the ticket type.
- **Why it's a problem:** The team clearly understood and solved this exact race for the public checkout path (transaction + re-read pattern) but did not apply the same fix to the admin-side equivalent, leaving a narrower but real overselling window whenever two staff members (or double-clicks) create registrations for the same ticket concurrently.
- **Recommended solution:** Wrap CreateEventRegistration.cs's read-check-insert sequence in the same `Database.CreateExecutionStrategy().ExecuteAsync` + transaction pattern already used in InitiateEventRegistration.cs.
- **Production impact:** Low-frequency but real overselling risk on staff-entered registrations for high-demand events.
- **Business impact:** Occasional overbooked events when staff process registrations concurrently (e.g. at a busy front desk / call center).
- **Technical impact:** Inconsistent concurrency-safety pattern between two handlers performing the same logical operation.
- **Evidence:** Base.Application/Business/ApplicationBusiness/EventRegistrations/Commands/CreateEventRegistration.cs:86 (no transaction wrapping the check); Base.Application/Business/ApplicationBusiness/EventRegistrationPages/PublicMutations/InitiateEventRegistration.cs:319-385 (execution-strategy + transaction pattern used for the equivalent public-path check).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #322 · Staff (Edit — Reporting-To / org chart) — Org-chart cycle detection bound  — `Low`

- **Module:** Organization · Events & Staff  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** UpdateStaffValidator's cycle-check (UpdateStaff.cs lines 72-92) walks up the ReportingToStaffId chain from the proposed manager looking for the current staff id, but the walk is hard-capped at 10 iterations (`for (var i = 0; i < 10 && !visited.Contains(current); i++)`).
- **Gap identified:** In an org chart with a reporting depth greater than 10 levels, the cycle-check loop exits (`break`) before reaching the top of the chain without having found a cycle, so a cycle introduced at depth >10 would pass validation undetected.
- **Why it's a problem:** Large enterprise organizations can plausibly exceed 10 reporting levels (e.g. Country → Region → Branch → Department → Team → Sub-team...); the arbitrary bound means the cycle guard's correctness silently degrades exactly for the customers most likely to have deep hierarchies.
- **Recommended solution:** Remove the fixed iteration cap and instead bound the loop by the total staff count for the company (or track visited-count without capping at a fixed constant), since `visited.Contains(current)` already prevents infinite loops on any real cycle.
- **Production impact:** Narrow edge case only affecting orgs with reporting chains deeper than 10 levels.
- **Business impact:** Potential for an undetected reporting-cycle in very large/deep organizations, causing org-chart rendering or reporting-rollup logic elsewhere to infinite-loop or misbehave.
- **Technical impact:** Arbitrary magic-number loop bound in a correctness-critical validator.
- **Evidence:** Base.Application/Business/ApplicationBusiness/Staffs/Commands/UpdateStaff.cs:72-92 (`for (var i = 0; i < 10 ...)`).
- **Reviewer note:** not adversarially verified (Medium/Low)

## Volunteer & Membership

### #84 · Hour Tracking (Volunteer Hour Log — Approve/Reject/Bulk Approve/Bulk Reject/Detail) — Hour-tracking approval workflow  — `Critical`

- **Module:** Volunteer & Membership  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** Verified in code: ApproveVolunteerHourLog.cs:25-27 `FirstOrDefaultAsync(h => h.VolunteerHourLogId == command.volunteerHourLogId, ...)`; RejectVolunteerHourLog.cs:31-33 same pattern keyed on `command.request.VolunteerHourLogId`; BulkApproveVolunteerHourLogs.cs:42-44 and BulkRejectVolunteerHourLogs.cs:48-50 loop over `command.request.Ids` with the identical unscoped fetch per id; GetVolunteerHourLogById.cs:23-37 filters only `h.VolunteerHourLogId == query.volunteerHourLogId && h.IsDeleted == false`. None of the five include `CompanyId`. Contrast confirmed: GetAllVolunteerHourLogs.cs:33-37 correctly resolves `companyId = httpContextAccessor.GetCurrentUserStaffCompanyId()` and filters `h.CompanyId == companyId`. Also confirmed system-wide: AuthorizationBehavior.cs (the only authorization pipeline behavior) checks menu-code/permission only (HasAccessAsync(userId, menuCode, capabilityCode)) — there is no resource-level/tenant ownership check anywhere in the pipeline, and a repo-wide grep found zero `HasQueryFilter` usages, so there is no EF global-filter safety net either.
- **Gap identified:** Confirmed exactly as reported — every ID-based single/bulk mutation and the GetById query for VolunteerHourLog omit the CompanyId predicate, and no other layer (authorization pipeline, EF global filters) compensates.
- **Why it's a problem:** Cross-tenant IDOR: any authenticated staff account with VolunteerHourLog Modify/Read permission in Tenant A can approve/reject/bulk-process/view full detail of Tenant B's hour-log rows by numeric ID guessing/enumeration.
- **Recommended solution:** Add `&& h.CompanyId == companyId` (companyId resolved server-side) to the fetch predicate in all five handlers; centralize via a shared tenant-scoped lookup helper to prevent recurrence.
- **Production impact:** Exploitable today by any staff-level account with the base module permission against any other tenant's hour-log IDs.
- **Business impact:** Breaks the core multi-tenant isolation guarantee; cross-tenant PII/payroll-adjacent data exposure and tampering risk.
- **Technical impact:** Confirms a systemic 'load-by-id without tenant filter' pattern that recurs across the codebase (same pattern found in Volunteer and MemberEnrollment approve handlers below).
- **Evidence:** Base.Application/Business/ApplicationBusiness/VolunteerHourLogs/ApproveCommand/ApproveVolunteerHourLog.cs:25-27; RejectCommand/RejectVolunteerHourLog.cs:31-33; BulkApproveCommand/BulkApproveVolunteerHourLogs.cs:42-44; BulkRejectCommand/BulkRejectVolunteerHourLogs.cs:48-50; GetByIdQuery/GetVolunteerHourLogById.cs:23-37 (no CompanyId); contrast GetAllQuery/GetAllVolunteerHourLogs.cs:33-37 (CompanyId-scoped correctly); Base.Application/Security/AuthorizationBehavior.cs:1-74 (permission-only, no resource scoping).

### #85 · Member Enrollment (Create / Update) — Staff-approval workflow bypass via IsSystemApproval flag  — `Critical`

- **Module:** Volunteer & Membership  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** Verified: MemberEnrollmentSchemas.cs:40 `public bool? IsSystemApproval { get; set; } = false;` on the client-facing request DTO. MemberEnrollmentMutations.cs:22-36 (`CreateMemberEnrollment`) and :41-55 (`UpdateMemberEnrollment`) pass the DTO straight to the command with zero server-side stripping. CreateMemberEnrollment.cs:107-124,177: `if (dto.IsSystemApproval == true)` resolves ACT status and sets `enrollment.StatusId = initialStatusId` (ACT) with `ApprovedByStaffId = null`, `ApprovedDate = DateTime.UtcNow`, gated only by `[CustomAuthorize(..., Permissions.Create)]` — no MEM_APPROVAL_MODE org-setting check at all in Create (worse than described: Create honors the client flag unconditionally with no org-setting gate whatsoever, unlike Approve which does check MEM_APPROVAL_MODE). UpdateMemberEnrollment.cs:105-120 shows the identical `if (dto.IsSystemApproval == true)` branch gated only by `Permissions.Modify`, also with `ApprovedByStaffId = null`.
- **Gap identified:** Confirmed and slightly worse than originally stated: Create not only bypasses the ApproveMemberEnrollment gate, it does so with no org-level MEM_APPROVAL_MODE check at all (that setting is only consulted in the dedicated Approve command) — any Create/Modify-permission caller can unconditionally force ACT status via a single boolean in the payload.
- **Why it's a problem:** Defeats a core business control: organizations relying on staff review before activating paid memberships can have it silently bypassed by any user with basic create/modify rights, with no accountability trail (ApprovedByStaffId explicitly nulled) and no org-setting override to prevent it.
- **Recommended solution:** Remove IsSystemApproval from the client-facing DTO, or make it strictly server-derived and only honored on trusted internal invocation paths (e.g., a payment webhook); route any legitimate 'approve immediately' UX through the existing dedicated ApproveMemberEnrollment command/permission, and make Create/Update also respect MEM_APPROVAL_MODE consistently with Approve.
- **Production impact:** Exploitable by any user with Create/Modify permission on MemberEnrollment via one extra GraphQL field — no special tooling required.
- **Business impact:** Undermines membership revenue-assurance/compliance controls (dues verification, fraud checks) that the approval workflow exists to enforce.
- **Technical impact:** The same flag also drives renewal-row approval state (IsSystemApproval propagated to MembershipRenewal at CreateMemberEnrollment.cs:253), so the bypass corrupts downstream audit/renewal history as well.
- **Evidence:** Base.Application/Schemas/MemSchemas/MemberEnrollmentSchemas.cs:40; Base.API/EndPoints/Mem/Mutations/MemberEnrollmentMutations.cs:22-55; Base.Application/Business/MemBusiness/MemberEnrollments/CreateCommand/CreateMemberEnrollment.cs:107-124,177,253; Base.Application/Business/MemBusiness/MemberEnrollments/UpdateCommand/UpdateMemberEnrollment.cs:105-120.

### #86 · Member Portal (Login / Auth Gate) — Member self-service portal authentication  — `Critical`

- **Module:** Volunteer & Membership  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** Verified: login-page.tsx:26-49 accepts any non-empty string and unconditionally calls `setMemberSession({ memberCode: value.toUpperCase(), contactId: 1, firstName: 'Khalid', contactName: 'Khalid Al-Mansouri' })` with no backend call, explicitly commented `SERVICE_PLACEHOLDER ISSUE-2: hit a member-auth endpoint ... For now, store a mock session`. member-auth-guard.tsx:1-6 explicitly labeled `SERVICE_PLACEHOLDER — ISSUE-2: client-side member auth gate`; :21-38 shows `getMemberSession`/`setMemberSession` are raw localStorage read/write with no token or signature; the guard (:72-79) only checks presence of this localStorage blob. Confirmed the contrast is real: GetMyMemberEnrollment.cs:22-36 resolves the member's ContactId strictly server-side from `httpContextAccessor.GetCurrentUserId()` → `Contacts.First(c => c.UserId == currentUserId)`, i.e., it requires a real authenticated staff/user JWT and never trusts a client-supplied ContactId — meaning the FE's localStorage-only member session cannot actually authenticate against this query in production (no real user JWT exists for a 'member' who only went through the mock login).
- **Gap identified:** Confirmed exactly as reported — there is no real authentication in the Member Portal login path; the guard only checks for the client's own localStorage write.
- **Why it's a problem:** The Member Portal as shipped cannot authenticate real members: the login always succeeds with a hardcoded fake identity and the client-side guard is trivially satisfiable, while the real backend query requires a genuine authenticated session that this flow never establishes — so the feature is non-functional/insecure, not merely rough around the edges.
- **Recommended solution:** Do not ship the Member Portal to production until real authentication exists (NextAuth member credential/OTP/magic-link tied to Contact.UserId) with server-verified sessions and a server-side/middleware guard replacing the localStorage check.
- **Production impact:** Member Portal must be treated as a non-functional prototype until real auth lands — it does not work for actual members today, and shipping it as-is is a security and functionality regression.
- **Business impact:** A donor/member-facing 'self-service' feature would fail for real users entirely.
- **Technical impact:** All portal pages currently trusting `getMemberSession()` need re-validation once real auth exists.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/page-components/member/portal/login-page.tsx:1-49; PSS_2.0_Frontend/src/presentation/components/page-components/member/portal/components/member-auth-guard.tsx:1-95; Base.Application/Business/MemBusiness/MemberEnrollments/Queries/GetMyMemberEnrollment.cs:22-36 (contrast — real server-side auth resolution).

### #87 · Volunteer (Approve) / Member Enrollment (Approve) — Volunteer and Member enrollment approval  — `Critical`

- **Module:** Volunteer & Membership  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** Verified: ApproveVolunteer.cs:25-27 `dbContext.Volunteers.Include(v => v.VolunteerStatus).FirstOrDefaultAsync(v => v.VolunteerId == command.volunteerId, ...)` — no CompanyId filter, no companyId resolution anywhere in the handler. ApproveMemberEnrollment.cs:39-41 `dbContext.MemberEnrollments.Include(e => e.Status).FirstOrDefaultAsync(e => e.MemberEnrollmentId == command.memberEnrollmentId && e.IsDeleted == false, ...)` — also no CompanyId filter (companyId is only later read off `enrollment.CompanyId` for an org-setting lookup at line 59, not used to scope the fetch).
- **Gap identified:** Confirmed — same cross-tenant IDOR pattern recurs on Volunteer and MemberEnrollment approve handlers.
- **Why it's a problem:** A staff user in one tenant can approve/activate another tenant's Volunteer or MemberEnrollment purely by ID, including forcing a MemberEnrollment to ACT (billing/membership status) cross-tenant.
- **Recommended solution:** Add CompanyId scoping to both fetch queries (resolve companyId via httpContextAccessor before the query, not after); grep-audit the codebase for the same `FirstOrDefaultAsync(x => x.<Id> ==` anti-pattern (250+ hits system-wide per grep, confirming this is a systemic remediation item, not a two-handler fix).
- **Production impact:** Directly exploitable; client cannot self-protect since the FE trusts BE authorization.
- **Business impact:** Breaks multi-tenant isolation for two more core entities — volunteer roster integrity and paid membership activation.
- **Technical impact:** Confirms the IDOR is a repeated architectural gap in the CQRS 'single-record ID-based command' pattern, not an isolated bug.
- **Evidence:** Base.Application/Business/ApplicationBusiness/Volunteers/ApproveCommand/ApproveVolunteer.cs:25-27; Base.Application/Business/MemBusiness/MemberEnrollments/ApproveCommand/ApproveMemberEnrollment.cs:39-41.

### #188 · Membership Renewal (bulk reminders) — Renewal reminder automation  — `High`

- **Module:** Volunteer & Membership  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** Verified: SendBulkRenewalReminders.cs is `[CustomAuthorize(..., Permissions.Modify)]`, staff-triggered, correctly CompanyId-scoped (line 38, 71) unlike the expiry-check command, and enqueues a one-shot Hangfire job via `jobClient.Enqueue<IRenewalReminderJobService>(x => x.ProcessBulkRemindersAsync(companyId, renewalIds, ...))` at line 118-119. Confirmed via repo-wide grep: no `RecurringJob.AddOrUpdate` registration exists anywhere in the backend for this or any other recurring schedule.
- **Gap identified:** Confirmed — reminders (DueThisMonth/Overdue/AutoRenewFailures/AllUpcoming tabs) are never sent automatically; a staff member must manually trigger 'Send Reminders' per tab, per tenant, every time.
- **Why it's a problem:** Enterprise membership systems expect unattended scheduled reminders; requiring manual daily/weekly staff action across every tenant will not scale and will directly reduce renewal/retention rates.
- **Recommended solution:** Add a recurring Hangfire job (daily) per active tenant that runs the same filter logic as SendBulkRenewalReminders and auto-enqueues ProcessBulkRemindersAsync, keeping the manual button as a supplementary ad-hoc trigger.
- **Production impact:** No automatic reminders will go out in production without daily manual staff action across every tenant.
- **Business impact:** Reduced renewal rates / member churn from missed reminders — undermines the purpose of the feature.
- **Technical impact:** None beyond adding scheduling wiring; the underlying job service (RenewalReminderJobService) itself works correctly when invoked and is properly tenant-scoped.
- **Evidence:** Base.Application/Business/MemBusiness/MembershipRenewals/Commands/SendBulkRenewalReminders.cs:12,29-38,71,110-119; repo-wide grep for `RecurringJob.AddOrUpdate` returned zero matches; only 2 unrelated `RecurringJob.RemoveIfExists` calls exist.

### #189 · Membership Renewal (renewal/expiry engine) — Automated membership expiry processing  — `High`

- **Module:** Volunteer & Membership  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** Verified: CheckMemberEnrollmentExpiries.cs doc comment (lines 3-7) says 'Called by scheduler or admin trigger'; validator comment at line 20 says 'tenant-scoped from context' but the handler query (lines 59-64) has zero CompanyId filter — it queries ALL companies' Active/past-EndDate enrollments in one unscoped pass and updates them all. Confirmed only manual invocation path exists: MemberEnrollmentMutations.cs:234-249 is a plain GraphQL mutation with no scheduling wrapper. Confirmed via grep: only 2 HostedServices exist backend-wide (OpenExchangeRatesSyncJob, AuditQueueDrainer — both unrelated), and grep for `RecurringJob.AddOrUpdate` across the entire backend returned zero matches (the only 2 `RecurringJob.` hits are `RemoveIfExists` calls in unrelated Import/Email job-deletion code).
- **Gap identified:** Confirmed on both counts: (1) no scheduled/automatic job exists — the expiry transition is manual-trigger only; (2) when triggered, the query is completely unscoped by CompanyId, processing every tenant's data in one pass.
- **Why it's a problem:** Memberships silently remain Active (with all benefits/portal access) past real expiry until a staff member manually triggers the mutation — a revenue-leakage/access-control correctness issue. The missing tenant scoping compounds this: one tenant's trigger click expires records across ALL tenants, which is itself a serious multitenancy correctness bug (could also mass-expire another tenant's legitimately active memberships).
- **Recommended solution:** Register a genuine recurring Hangfire job (`RecurringJob.AddOrUpdate`) that runs per-tenant daily, and add an explicit CompanyId parameter/loop to the query so a single run only ever touches one company's data (or all companies deliberately, looped, never a single unscoped query).
- **Production impact:** Expired memberships will not automatically lose Active status in production; additionally the current manual trigger is unsafe to invoke because it silently affects every tenant, which likely makes it currently unused/dangerous in practice.
- **Business impact:** Members keep paid-tier benefits indefinitely past real expiry absent manual staff action; the unscoped-batch bug also risks one tenant's admin action incorrectly expiring another tenant's active memberships.
- **Technical impact:** No infra gap — Hangfire is already used elsewhere; this is purely a missing registration + a missing WHERE clause.
- **Evidence:** Base.Application/Business/MemBusiness/MemberEnrollments/CheckExpiriesCommand/CheckMemberEnrollmentExpiries.cs:3-7,20,56-64 (no CompanyId anywhere in handler); Base.API/EndPoints/Mem/Mutations/MemberEnrollmentMutations.cs:234-249 (manual-trigger mutation only); repo-wide grep confirmed 2 HostedServices (neither membership-related) and 0 `RecurringJob.AddOrUpdate` calls anywhere in the backend.

### #190 · Volunteer Schedule (Assign Volunteer to Shift / Get Available Volunteers) — Volunteer availability and shift-assignment integrity  — `High`

- **Module:** Volunteer & Membership  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** Verified: GetAvailableVolunteersForShift.cs:28-29 comment explicitly states 'SERVICE_PLACEHOLDER ranking — for now, return active volunteers NOT yet assigned to this shift, sorted alphabetically. Distance = 0.' The query (lines 31-46) only excludes volunteers already assigned to this exact shift (`!assignedIds.Contains(v.VolunteerId)`) and filters IsActive/CompanyId — no blackout-date filter, no time-overlap-with-other-shifts filter, and no skill-requirement filter, even though `v.Skills` is Included (line 41) and returned in the DTO purely for display (line 52-55), never used in a WHERE predicate. `Availability = 'Available'` (line 56) and `DistanceKm = 0` (line 57) are hardcoded literals for every record. Confirmed VolunteerBlackout is a real persisted entity elsewhere in the schema (present in EF migrations) that is never queried here.
- **Gap identified:** Confirmed exactly as reported — the 'availability' computation is fully hardcoded/fake; blackout dates, shift-time overlaps, and skill-match requirements are captured elsewhere in the system but never consulted here.
- **Why it's a problem:** Staff scheduling volunteers see a list that appears vetted (labeled 'Available', with a distance value) but is actually just 'any active volunteer not already on this specific shift' — enabling double-booking during stated unavailable periods, skill-mismatched assignments, or assigning volunteers already committed to a time-overlapping different shift, while the UI implies these checks already happened.
- **Recommended solution:** Implement real filtering: exclude volunteers with an overlapping VolunteerBlackout window for the shift's date, exclude volunteers already assigned to a time-overlapping different shift, and filter/rank by VolunteerShiftSkill requirement match. Until implemented, clearly flag Availability/Distance as placeholder in the UI rather than presenting them as computed facts.
- **Production impact:** Staff using this feature get misleading results that look computed but are not, defeating the purpose of an availability-check feature.
- **Business impact:** Volunteer no-shows/conflicts from unenforced blackout/overlap checks, and possible skill-mismatch assignments for skill-sensitive activities.
- **Technical impact:** VolunteerBlackout and VolunteerShiftSkill data are captured/persisted elsewhere but never consumed in this query — dead data giving a false sense of coverage.
- **Evidence:** Base.Application/Business/ApplicationBusiness/VolunteerShifts/GetAvailableVolunteersQuery/GetAvailableVolunteersForShift.cs:1-63 (placeholder comment lines 28-29; hardcoded fields lines 56-57; unused Skills include lines 41-42,52-55; no blackout/overlap query anywhere in file).

### #296 · Hour Tracking (Create Volunteer Hour Log) — Duplicate hour-log submission prevention  — `Medium`

- **Module:** Volunteer & Membership  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** CreateVolunteerHourLog.cs contains a duplicate check (lines 87-95) explicitly commented '// ISSUE-4: warn-only — do not block; duplicate check is informational only' — matching same volunteer/date/activity/start-time submissions are detected but never blocked from being inserted.
- **Gap identified:** A volunteer (or staff logging on their behalf) can submit the same hours multiple times for the same date/activity/time, and the system will accept all of them as separate approvable records.
- **Why it's a problem:** Volunteer hours often feed into recognition/reporting (and in some NGOs, grant-matching or compliance reporting) — allowing silent duplicate submissions inflates hour totals and, if an approver isn't paying close attention, duplicate hours can be approved and double-counted.
- **Recommended solution:** Either hard-block exact duplicates server-side (return a clear validation error) or require an explicit 'confirm duplicate' override flag from the client with an audit note, rather than silently allowing unlimited duplicate inserts.
- **Production impact:** Duplicate/inflated hour logs can be submitted and approved without any server-side prevention.
- **Business impact:** Inaccurate volunteer-hour reporting used for recognition, grant compliance, or impact reporting.
- **Technical impact:** n/a — the detection logic already exists, only the blocking behavior is missing.
- **Evidence:** Base.Application/Business/ApplicationBusiness/VolunteerHourLogs/CreateCommand/CreateVolunteerHourLog.cs:87-95.
- **Reviewer note:** not adversarially verified (Medium/Low)

### #297 · Member Portal (Signup / Join flow) — Self-service enrollment / signup  — `Medium`

- **Module:** Volunteer & Membership  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** login-page.tsx (lines 94-105): the 'Join now' link for prospective members who aren't yet enrolled just calls `toast.info("Membership signup is coming soon. Contact your org.")` — no actual signup flow. dashboard-page.tsx's no-enrollment empty state (lines 184-191) similarly shows a 'Join Now' button that calls `alert("Join flow coming soon")`.
- **Gap identified:** There is no self-service membership signup/enrollment flow in the Member Portal at all — both entry points are explicit 'coming soon' stubs.
- **Why it's a problem:** A 'Member Portal' / 'self-service' feature set that cannot onboard new members through self-service (only staff-created enrollments via the admin CreateMemberEnrollment screen) falls short of the stated self-service scope for this module, on top of the login mechanism itself being non-functional (see related Critical finding).
- **Recommended solution:** Either scope the Member Portal explicitly as 'existing-member self-service only' in documentation/product decisions, or build the self-service signup flow (public enrollment form → CreateMemberEnrollment with appropriate guardrails) consistent with other EXTERNAL_PAGE patterns already used elsewhere in the codebase (e.g., donation pages).
- **Production impact:** No new-member self-service onboarding path exists; all enrollment must go through staff today.
- **Business impact:** Reduces the practical value of the 'self-service' Member Portal feature as currently scoped/marketed.
- **Technical impact:** n/a.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/page-components/member/portal/login-page.tsx:94-105; PSS_2.0_Frontend/src/presentation/components/page-components/member/portal/dashboard-page.tsx:184-191.
- **Reviewer note:** not adversarially verified (Medium/Low)

### #298 · Membership Renewal (Manual & Auto-Renew payment processing) — Renewal payment amount/currency integrity  — `Medium`

- **Module:** Volunteer & Membership  |  **Category:** payments  |  **Verification:** CONFIRMED
- **Current implementation:** Both MembershipManualRenewalService.ProcessPaymentSucceededAsync (lines 75-96) and MembershipRenewalWebhookService.ProcessPaymentSucceededAsync (lines 84-119) write `dto.Amount` and `dto.CurrencyId` (client/gateway-supplied) directly onto the MembershipRenewal and MembershipPaymentTransaction rows, and unconditionally advance EndDate by a full renewal cycle on success — with no comparison of `dto.Amount`/`dto.CurrencyId` against the enrollment's/tier's expected fee or currency (`enrollment.TotalAmount`, `enrollment.CurrencyId`, `tier.AnnualFee`/`MonthlyFee`).
- **Gap identified:** There is no server-side check that a reported successful payment actually matches the expected renewal price/currency for the tier before granting a full renewal cycle (EndDate extension + ACT status). A short-paid, wrong-currency, or tampered webhook amount is trusted at face value.
- **Why it's a problem:** Payment amount/currency integrity checks are a standard safeguard against gateway/client payload manipulation or integration bugs; without it, a member could be renewed for a full cycle having paid an incorrect (e.g., much lower, or wrong-currency) amount, silently creating a revenue/reconciliation discrepancy that is hard to detect after the fact since the renewal already completed.
- **Recommended solution:** Before finalizing the renewal (setting RENEWED/ACT), validate `dto.Amount` and `dto.CurrencyId` against the expected tier fee/currency (allowing for documented discounts/pro-rating), and flag/hold for staff review any mismatch rather than silently accepting and completing the cycle.
- **Production impact:** Amount/currency mismatches from gateway or client input are accepted without validation today.
- **Business impact:** Potential silent revenue shortfall or currency-reporting inconsistency across a member's renewal history.
- **Technical impact:** Affects financial reconciliation/reporting accuracy for MembershipPaymentTransaction records.
- **Evidence:** Base.Application/Services/Memberships/MembershipManualRenewalService.cs:75-96; Base.Application/Services/Memberships/MembershipRenewalWebhookService.cs:84-119.
- **Reviewer note:** not adversarially verified (Medium/Low)

### #299 · Membership Renewal (reminder delivery) — Renewal reminder channel coverage and failure visibility  — `Medium`

- **Module:** Volunteer & Membership  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** RenewalReminderJobService.cs: the entire SMS channel is commented out (lines 3, 21, 27, 41, 92-101, 164-192) — only email is actually dispatched despite the data model (Channel, LastReminderChannels) supporting multi-channel. If no default Email template is configured for a company, the job logs a warning and silently returns (lines 43-49) with zero reminders sent and no surfaced error/alert to staff.
- **Gap identified:** 1) SMS reminders are advertised by the data model but never actually sent. 2) A tenant that has not configured a default email renewal-reminder template gets zero reminders sent, silently, with no visible failure indicator anywhere in the UI — staff would have no way to know reminders aren't going out.
- **Why it's a problem:** Silent no-op failure modes are a production support nightmare: a misconfigured tenant (missing template) will simply never notify members of upcoming/overdue renewals, and nobody will know until members complain about lapsed memberships they were never warned about.
- **Recommended solution:** Surface a hard validation/warning at the point of triggering bulk reminders (mutation response or grid banner) when no default template is configured, rather than a job-log-only warning. Either fully implement SMS or remove SMS references from the data model/UI until implemented, to avoid promising a channel that silently does nothing.
- **Production impact:** Misconfigured tenants get no visible signal that renewal reminders are silently failing.
- **Business impact:** Member churn from unremembered renewals in any tenant without an email template configured.
- **Technical impact:** SMS-related fields/UI toggles exist but are dead code paths.
- **Evidence:** Base.Support/Mem/RenewalReminderJobService.cs:3,21,27,41,43-49,92-101,164-192.
- **Reviewer note:** not adversarially verified (Medium/Low)

### #300 · Volunteer / Hour Tracking — Volunteer blackout / unavailability enforcement  — `Medium`

- **Module:** Volunteer & Membership  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** VolunteerBlackout.cs (14 lines) is a simple entity (VolunteerId, FromDate, ToDate, Reason) captured/persisted only in CreateVolunteer.cs, UpdateVolunteer.cs, and VolunteerMappings.cs. Confirmed via grep that it is never referenced/read in any query or command that would enforce it (AssignVolunteer.cs, GetAvailableVolunteersForShift.cs, CreateVolunteerHourLog.cs all omit it).
- **Gap identified:** Blackout/unavailability dates entered by staff on a volunteer's profile are stored but have zero effect anywhere in the system — they don't block shift assignment, don't affect the 'available volunteers' list, and don't block hour-log submission during a blackout window.
- **Why it's a problem:** This gives staff a false sense that entering blackout dates protects against scheduling that volunteer during their stated unavailability, when in fact the field is purely decorative — a classic captured-but-dead-data gap that will surface as real-world scheduling conflicts.
- **Recommended solution:** Enforce VolunteerBlackout in AssignVolunteer.cs (reject or warn-with-override when assigning during a blackout window) and in GetAvailableVolunteersForShift.cs (exclude blacked-out volunteers from the availability list) as the minimum bar; optionally also flag hour-log entries logged during a blackout window for staff review.
- **Production impact:** Feature appears to exist in the UI (volunteer profile blackout entry) but has no functional effect anywhere downstream.
- **Business impact:** Volunteers scheduled/contacted during periods they explicitly marked unavailable — a poor volunteer-experience and operational reliability issue.
- **Technical impact:** n/a — requires wiring existing data into the two consuming handlers.
- **Evidence:** Base.Domain/Models/ApplicationModels/VolunteerBlackout.cs:1-14; grep confirms references only in DecoratorProperties.cs, IApplicationDbContext.cs, Volunteers/CreateCommand/CreateVolunteer.cs, Volunteers/UpdateCommand/UpdateVolunteer.cs, Mappings/VolunteerMappings.cs — never in AssignVolunteer.cs or GetAvailableVolunteersForShift.cs.
- **Reviewer note:** not adversarially verified (Medium/Low)

### #301 · Volunteer Schedule (Assign Volunteer to Shift) — Shift assignment conflict/capacity enforcement  — `Medium`

- **Module:** Volunteer & Membership  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** AssignVolunteer.cs checks the shift exists and isn't deleted (lines 32-34), the volunteer exists/active (lines 37-40), and blocks only the exact duplicate (same volunteer, same shift) assignment (lines 43-47). Line 49 explicitly comments 'Allow overbook (admin discretion — no hard cap, just a soft warning surface client-side)'. There is no check against VolunteerBlackout, and no check for the same volunteer being assigned to a different, time-overlapping shift.
- **Gap identified:** No server-side enforcement exists for shift headcount capacity, volunteer blackout windows, or double-booking across different overlapping shifts — only exact duplicate (same shift, same volunteer) is blocked.
- **Why it's a problem:** A soft client-side-only warning for overbooking is not a substitute for a server-side guard — any programmatic caller (or a client bug) bypasses it entirely; and there is no protection at all (client or server) against assigning a volunteer to two shifts that overlap in time, or assigning them during a declared blackout period, both of which are core scheduling-correctness expectations.
- **Recommended solution:** Add server-side validation: reject (or require an explicit override flag with audit trail) when the shift is already at its configured capacity, when the volunteer has an overlapping VolunteerBlackout window, or when the volunteer already has a different shift assignment whose date/time window overlaps the target shift.
- **Production impact:** Volunteer double-booking and blackout violations are possible today with no server-side backstop.
- **Business impact:** Operational failures (two shifts double-booked for the same person, or a volunteer scheduled during declared unavailability) reflect poorly on program reliability.
- **Technical impact:** n/a — straightforward additional WHERE/EXISTS checks in the existing handler.
- **Evidence:** Base.Application/Business/ApplicationBusiness/VolunteerShifts/AssignVolunteerCommand/AssignVolunteer.cs:32-49.
- **Reviewer note:** not adversarially verified (Medium/Low)

### #335 · Membership Tier (Benefits) — Tier benefit entitlement enforcement  — `Low`

- **Module:** Volunteer & Membership  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** MembershipTierBenefit.cs is a simple free-text row (MembershipTierId, BenefitText, IsIncluded, SortOrder) captured via CreateMembershipTier.cs/UpdateMembershipTier.cs. Grep across the entire Base.Application layer confirms `MembershipTierBenefits` DbSet is referenced only in IMemDbContext.cs, the Create/Update tier commands, mappings, and schemas — never queried or checked anywhere else (no event-pricing discount lookup, no portal feature-gate check, no entitlement validation).
- **Gap identified:** Membership tier 'benefits' are purely descriptive marketing text with no functional linkage to any actual system entitlement (e.g., discounted event pricing, gated portal sections, special access) — the benefits table is data-entry-only.
- **Why it's a problem:** If the business expectation for tiers (e.g., Platinum/Gold) is that benefits translate into real system behavior (discounts, access), shipping only a descriptive list with no enforcement means the 'benefits' feature does not deliver on its implied promise; if it's meant to be purely informational copy for the portal, this should be an explicit, documented design decision rather than an assumed gap.
- **Recommended solution:** Clarify product intent: if benefits are meant to be enforced, add a structured BenefitType/BenefitValue model wired into relevant checks (event pricing, portal section gating). If purely informational, document this clearly so it isn't mistaken for a functional entitlement system during future audits.
- **Production impact:** No functional breakage, but a likely mismatch between stakeholder expectation ('tier benefits') and actual behavior (descriptive text only).
- **Business impact:** Missed opportunity to differentiate tiers with real perks unless intentionally scoped as informational-only.
- **Technical impact:** n/a.
- **Evidence:** Base.Domain/Models/MemModels/MembershipTierBenefit.cs:1-14; grep confirms MembershipTierBenefits DbSet used only in IMemDbContext.cs, CreateMembershipTier.cs, UpdateMembershipTier.cs, MembershipTierSchemas.cs, MemMappings.cs.
- **Reviewer note:** not adversarially verified (Medium/Low)

## Multi-Tenancy Isolation

### #43 · ContactCertificates (Screen #9 area / Contact Certificate print-preview) — Print Contact Certificate command  — `Critical`

- **Module:** Multi-Tenancy Isolation  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** PrintContactCertificateCommand has no CompanyId property. Handler (Base.Application/Business/ContactBusiness/ContactCertificates/Commands/PrintContactCertificate.cs:22-33) fetches `var tenantId = tenantContext.GetCurrentTenantId();` but NEVER uses that variable — it then queries dbContext.ContactCertificates.IgnoreQueryFilters()...FirstOrDefaultAsync(c => c.ContactCertificateId == command.ContactCertificateId && c.IsDeleted != true) with zero CompanyId predicate. Contacts lookup (lines 37-41) is likewise IgnoreQueryFilters() scoped only by ContactId. CertificateTemplates lookup (lines 43-49) filters by t.CompanyId == cert.CompanyId — i.e. trusts the cross-tenant record's own claimed CompanyId, not the caller's tenant.
- **Gap identified:** Confirmed exactly as reported. Any authenticated staff user in ANY tenant holding ContactCertificate:Read can supply an arbitrary ContactCertificateId belonging to a different tenant; the handler fetches donor financial data (TotalPaid, MinAmount, DonationPurposeName, currency), fetches donor photo via a second unscoped query, renders/writes a PDF to disk, and mutates cert.PrintedById/PrintedAt via SaveChangesAsync (lines 121-123) on the other tenant's row — a cross-tenant read AND write IDOR. The fetched `tenantId` variable being unused is itself telling — the safety check was clearly intended but never wired in.
- **Why it's a problem:** Bypasses both tenant-safety nets simultaneously: no CompanyId on the command for TenantIsolationBehavior to check, and IgnoreQueryFilters() with no manually re-applied CompanyId predicate.
- **Recommended solution:** Add `&& c.CompanyId == tenantId` (using the already-fetched, currently-unused variable) to the ContactCertificates fetch, removing the need for IgnoreQueryFilters(); throw NotFoundException if null. Apply the same CompanyId re-scoping to the Contacts and CertificateTemplates lookups.
- **Production impact:** Live cross-tenant data exposure and unauthorized write the moment two customers share a PSS 2.0 deployment.
- **Business impact:** Breach of donor PII and financial confidentiality across unrelated nonprofit customers; severe trust/legal/regulatory risk.
- **Technical impact:** Confirms the IgnoreQueryFilters()-without-manual-rescope anti-pattern is present in production code, and that the intended fix (tenantId variable) was scaffolded but never connected.
- **Evidence:** Base.Application/Business/ContactBusiness/ContactCertificates/Commands/PrintContactCertificate.cs:4-10 (no CompanyId on command), :27-33 (tenantId fetched but unused; unscoped query), :37-41 (unscoped Contacts), :43-49 (CertificateTemplates trusts cert.CompanyId), :121-123 (mutation + SaveChangesAsync on cross-tenant row).

### #44 · ContactCertificates (Screen #9 area / Contact Certificate print-preview) — Preview Contact Certificate command  — `Critical`

- **Module:** Multi-Tenancy Isolation  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** PreviewContactCertificateCommand (Base.Application/Business/ContactBusiness/ContactCertificates/Commands/PreviewContactCertificate.cs) has no CompanyId property and the handler does not even inject ITenantContext. Lines 27-31: dbContext.ContactCertificates.IgnoreQueryFilters().Include(Currency).Include(DonationPurpose).FirstOrDefaultAsync(c => c.ContactCertificateId == command.ContactCertificateId && c.IsDeleted != true) — no CompanyId anywhere in the handler. Contacts lookup (lines 35-39) identically unscoped. Returns PreviewContactCertificateResult(byte[] PdfBytes) directly (line 102) with no PrintedById/PrintedAt stamp and no audit record.
- **Gap identified:** Confirmed exactly as reported — identical cross-tenant IDOR to Print, but this variant is strictly worse in one respect: there is no ITenantContext dependency at all (not even an unused fetch), and no write side-effect, so a staff user from Company A can silently pull Company B's donor certificate PDF (financial + PII) with zero record of access.
- **Why it's a problem:** Same root cause — IgnoreQueryFilters() with no re-applied CompanyId check on a caller-supplied numeric ID — compounded by zero audit trail.
- **Recommended solution:** Inject ITenantContext, add `&& c.CompanyId == tenantContext.GetCurrentTenantId()` to both the ContactCertificates and Contacts queries; consider a lightweight audit log entry on preview access given data sensitivity.
- **Production impact:** Same live cross-tenant exposure as Print, with the added risk that it is silent/undetectable in normal operational monitoring.
- **Business impact:** Same donor PII/financial confidentiality breach risk, compounded by lack of any forensic trail.
- **Technical impact:** Confirms the vulnerable pattern exists in at least two sibling handlers in the same module, strongly suggesting copy-paste origin.
- **Evidence:** Base.Application/Business/ContactBusiness/ContactCertificates/Commands/PreviewContactCertificate.cs:4-10 (no CompanyId, no ITenantContext), :22-31 (unscoped ContactCertificates query), :35-39 (unscoped Contacts query), :102 (raw PDF bytes returned, no stamp/audit).

### #45 · Cross-cutting / all public (anonymous) GraphQL endpoints — Tenant-resolution architecture for unauthenticated requests  — `Critical`

- **Module:** Multi-Tenancy Isolation  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** Base.Application/Services/TenantContext/TenantContext.cs:22-36 — GetCurrentTenantId() returns null for SuperAdmin (line 33) AND maps `companyId <= 0` (the value GetCurrentUserStaffCompanyId() returns when no JWT/claims are present, i.e. any anonymous caller) to null (line 36) — these two paths are architecturally indistinguishable to the EF filter. ApplicationDbContext.cs ApplyTenantFilters builds `(CurrentTenantId == null || entity.CompanyId == CurrentTenantId)` (confirmed base filter shape at line 85 per grep) — a full no-op whenever CurrentTenantId is null.
- **Gap identified:** Confirmed — there is no automatic, framework-level protection for public endpoints; each new anonymous handler must manually re-implement CompanyId scoping (typically via hostname resolution) with zero compile-time/test-time enforcement. This session independently verified at least 9 findings across 8 handlers (2 ContactCertificate command IDORs, 1 PrayForThis mutation, and 6 first-active-company-fallback query handlers across P2P/Volunteer/Prayer modules) where this manual re-scoping was missing, absent, or left on a legacy shortcut, alongside sibling handlers (GetP2PCampaignPageBySlug, GetOnlineDonationPageBySlug, GetCrowdFundBySlug) that got it right via OnlineDonationPageTenantResolver.
- **Why it's a problem:** Systemic single-point-of-failure: the safety of the entire public-facing surface rests on every developer remembering to manually re-scope every new anonymous handler, with no automated guard rail (analyzer, base class, or test) to catch omissions before production. The pattern has already recurred 6+ times independently confirmed in this pass alone.
- **Recommended solution:** (1) Introduce a marker interface/base type that forces anonymous handlers to declare and resolve a CompanyId via a MediatR pipeline behavior. (2) Add a Roslyn analyzer or unit test that flags any anonymous-reachable handler using IgnoreQueryFilters() or querying by bare numeric ID without a CompanyId predicate. (3) Retrofit the remaining first-active-company handlers identified in this audit (Volunteer, PrayerRequestPage, PrayerWall, P2P RecentDonors/Leaderboard) and the two ContactCertificate command IDORs.
- **Production impact:** Root cause underlying the other 8 findings in this report; will keep producing new incidents as the public-page surface grows unless addressed structurally.
- **Business impact:** Systemic risk to the core multi-tenant data-isolation guarantee fundamental to this SaaS's value proposition and customer trust.
- **Technical impact:** Requires an architectural/process fix (analyzer + pipeline behavior), not just individual handler patches, to prevent recurrence.
- **Evidence:** Base.Application/Services/TenantContext/TenantContext.cs:22-36 (anonymous-equals-SuperAdmin null-tenant mapping, verified by direct read); Base.Infrastructure/Data/Persistence/ApplicationDbContext.cs (ApplyTenantFilters, CurrentTenantId null-OR filter, line ~85 per grep match); cross-referenced against the 8 concrete handler files independently verified in this same review pass.

### #46 · VolunteerRegistrationPage public page (Screen #172) — Public GetBySlug tenant resolution  — `Critical`

- **Module:** Multi-Tenancy Isolation  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** GetVolunteerRegistrationPageBySlug.cs:15-18 doc comment: 'Tenant resolution: MVP path is one-tenant-per-deployment... Multi-tenant resolution (subdomain or tenantSlug query) deferred (SERVICE_PLACEHOLDER).' Lines 43-50: first-active-company fallback with no env.IsDevelopment() gate anywhere in the handler.
- **Gap identified:** Confirmed exactly as reported — this shortcut applies unconditionally in production. The query record does accept an unused `tenantSlug` parameter (line 19) that is never read in the handler body, confirming the multi-tenant path was scaffolded but never wired in, same pattern as PrintContactCertificate's unused tenantId.
- **Why it's a problem:** Because Slug uniqueness is per-(CompanyId, Slug) and not global, a second tenant's volunteer registration page will either silently 404 or, if slugs collide, serve the wrong tenant's page/data.
- **Recommended solution:** Upgrade to OnlineDonationPageTenantResolver.ResolveByHostnameAsync, consistent with OnlineDonationPage, CrowdFund, P2PCampaignPage, and EventRegistrationPage — the last major public page still on the legacy shortcut.
- **Production impact:** Confirmed to apply unconditionally in production per the explicit SERVICE_PLACEHOLDER comment and absence of any IsDevelopment() gate — this is the production code path for any deployment with more than one active tenant.
- **Business impact:** Volunteer applicant PII (names, contact info, availability) submitted through this page could be associated with, or the page itself could display data belonging to, the wrong NGO tenant.
- **Technical impact:** Demonstrates the codebase's hostname-resolver rollout was not completed across all public pages — a clear backlog item, not a one-off bug.
- **Evidence:** Base.Application/Business/ApplicationBusiness/VolunteerRegistrationPages/PublicQueries/GetVolunteerRegistrationPageBySlug.cs:15-18 (SERVICE_PLACEHOLDER doc comment), :19 (unused tenantSlug param), :43-50 (first-active-company fallback, no IsDevelopment gate).

### #151 · P2PCampaignPage public page (Screen #170) — Recent donors public widget  — `High`

- **Module:** Multi-Tenancy Isolation  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** GetP2PCampaignPageRecentDonors.cs:33-38 resolves companyId via `dbContext.Companies.Where(IsDeleted==false && IsActive==true).OrderBy(c=>c.CompanyId).Select(c=>(int?)c.CompanyId).FirstOrDefaultAsync()` — the legacy first-active-company fallback — with no hostname parameter on the query record at all (GetP2PCampaignPageRecentDonorsQuery(string slug, int limit=10), line 8). This directly contrasts with the sibling GetP2PCampaignPageBySlug.cs:23,53-54 which takes `string? hostname` and calls `OnlineDonationPageTenantResolver.ResolveByHostnameAsync(dbContext, env, query.hostname, cancellationToken)`.
- **Gap identified:** Confirmed exactly as reported. Since Slug uniqueness is per-(CompanyId, Slug), a campaign page slug on a non-first-active tenant (or any request lacking a recognizable hostname) will have this widget resolve donors from the wrong company's campaign of the same slug — or silently return empty if no matching page exists under that first-active company.
- **Why it's a problem:** The main GetBySlug handler for the same public page was upgraded to hostname-based resolution but this sibling aggregate-data handler was left on the old MVP shortcut — an inconsistency within a single module.
- **Recommended solution:** Thread `hostname` through GetP2PCampaignPageRecentDonorsQuery and replace the first-active-company fallback with OnlineDonationPageTenantResolver.ResolveByHostnameAsync, matching GetP2PCampaignPageBySlug.cs.
- **Production impact:** Applies in production for any multi-tenant deployment with 2+ companies running active P2P campaigns.
- **Business impact:** Donor names and amounts from one nonprofit's supporters could display on a different nonprofit's page — privacy and brand-confusion issue.
- **Technical impact:** Confirms the first-active-company hack was not uniformly retired across all handlers in the module even after the primary handler was fixed.
- **Evidence:** Base.Application/Business/DonationBusiness/Public/PublicQueries/GetP2PCampaignPageRecentDonors.cs:8-9 (query has no hostname param), :33-38 (first-active-company fallback), contrasted with GetP2PCampaignPageBySlug.cs:23,53-54 (hostname-resolved).

### #152 · P2PCampaignPage public page (Screen #170) — Public leaderboard widget  — `High`

- **Module:** Multi-Tenancy Isolation  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** GetP2PCampaignPagePublicLeaderboard.cs:11-12 (query record has no hostname param), :38-43 (identical first-active-company fallback: dbContext.Companies.Where(IsDeleted==false && IsActive==true).OrderBy(CompanyId).FirstOrDefaultAsync()).
- **Gap identified:** Confirmed — same class of bug as the Recent Donors widget: leaderboard rankings (fundraiser names + amounts raised) can be sourced from the wrong tenant's campaign when the resolved 'first active company' doesn't match the tenant actually being browsed.
- **Why it's a problem:** Same inconsistent tenant-resolution upgrade within a single module as Recent Donors.
- **Recommended solution:** Replace with OnlineDonationPageTenantResolver.ResolveByHostnameAsync, matching GetP2PCampaignPageBySlug.cs, threading hostname through the query.
- **Production impact:** Applies in production for any deployment with 2+ tenants running P2P campaigns simultaneously.
- **Business impact:** Public leaderboard showing a different organization's top fundraisers is a visible, embarrassing cross-tenant data leak.
- **Technical impact:** Second confirmed instance of the same unresolved sibling-handler gap in the P2PCampaignPage module.
- **Evidence:** Base.Application/Business/DonationBusiness/Public/PublicQueries/GetP2PCampaignPagePublicLeaderboard.cs:11-12, 38-43 — first-active-company fallback, no hostname parameter.

### #153 · PrayerRequestPage / PrayerWall (Screen #171 public page — 'I'll Pray for This') — PrayForThis anonymous public mutation  — `High`

- **Module:** Multi-Tenancy Isolation  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** PrayForThis.cs (Base.Application/Business/ContactBusiness/PrayerRequestPrayedLogs/PublicMutations/PrayForThis.cs) is an anonymous-allowed mutation taking only PrayerRequestId. Lines 52-57: dbContext.PrayerRequests.Include(PrayerRequestPage).FirstOrDefaultAsync(r => r.PrayerRequestId == req.PrayerRequestId && r.PrayerWallEligible == true && r.IsActive == true && r.IsDeleted == false) has no CompanyId predicate. Lines 107-112: raw SQL `UPDATE corg."PrayerRequests" SET "PrayedCount"="PrayedCount"+1, "LastPrayedAt"=@p0 WHERE "PrayerRequestId"=@p1` also has no CompanyId predicate — confirmed verbatim.
- **Gap identified:** Confirmed. For an unauthenticated caller, TenantContext.GetCurrentTenantId() (Base.Application/Services/TenantContext/TenantContext.cs:22-36) returns null because GetCurrentUserStaffCompanyId() yields 0 with no JWT claims present, and `companyId <= 0 ? null : companyId` maps that to null — architecturally identical to SuperAdmin. Combined with ApplicationDbContext's global filter `(CurrentTenantId == null || CompanyId == CurrentTenantId)`, the EF filter becomes a full no-op for this anonymous request, so the LINQ query matches by PrayerRequestId alone across ALL tenants (verified the filter shape at ApplicationDbContext.cs:85). Any anonymous visitor can enumerate PrayerRequestId values and inflate PrayedCount / trigger SendPrayedNotifyAsync for any tenant's prayer requests.
- **Why it's a problem:** This is the anonymous-null-tenant risk in its rawest form: no hostname-based tenant resolution step exists in this handler at all, unlike sibling public pages (OnlineDonationPage, CrowdFund, P2P, EventRegistration) that resolve tenant via hostname before querying.
- **Recommended solution:** Add hostname-based tenant resolution (OnlineDonationPageTenantResolver.ResolveByHostnameAsync) at the top of the handler, then require `r.PrayerRequestPage.CompanyId == companyId.Value` in both the read query and the raw-SQL WHERE clause.
- **Production impact:** Live in production for any deployment with this feature enabled — no authentication needed, only an integer ID.
- **Business impact:** Inflated engagement metrics on an unrelated tenant's public page plus unwanted email sends to donors/requesters of a tenant the anonymous actor has no relationship with.
- **Technical impact:** Confirms the raw-SQL ExecuteRawSqlAsync escape hatch bypasses EF LINQ/tenant filtering by design and this call site does not manually compensate.
- **Evidence:** Base.Application/Business/ContactBusiness/PrayerRequestPrayedLogs/PublicMutations/PrayForThis.cs:52-57 (unscoped read), :107-112 (unscoped raw SQL); Base.Application/Services/TenantContext/TenantContext.cs:22-36 (anonymous maps to null tenant); Base.Infrastructure/Data/Persistence/ApplicationDbContext.cs:85 (filter no-op when CurrentTenantId null).

### #154 · PrayerRequestPage public page (Screen #171) — Public GetBySlug tenant resolution  — `High`

- **Module:** Multi-Tenancy Isolation  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** GetPrayerRequestPageBySlug.cs:18-20 doc comment: 'Tenant resolution (ISSUE-1 from OnlineDonationPage): one-tenant-per-deployment MVP. CompanyId resolved from first active company. Multi-tenant (subdomain/custom-domain) deferred to future sprint.' Lines 48-53: first-active-company fallback confirmed verbatim, no hostname parameter on the query record (line 22) at all.
- **Gap identified:** Confirmed exactly as reported — same class of bug as GetVolunteerRegistrationPageBySlug.cs. Production traffic for this public page resolves to whichever company is 'first active' rather than the tenant the visitor's hostname maps to.
- **Why it's a problem:** Combined with per-(CompanyId, Slug) uniqueness, this can serve one tenant's prayer request page content/data under a different tenant's traffic.
- **Recommended solution:** Upgrade to OnlineDonationPageTenantResolver.ResolveByHostnameAsync, consistent with already-fixed sibling public pages.
- **Production impact:** Applies in production for any multi-tenant deployment with this feature enabled.
- **Business impact:** Prayer request content (potentially sensitive personal/spiritual disclosures) could surface under the wrong organization's public page.
- **Technical impact:** Third confirmed instance of the incomplete hostname-resolver rollout across public-facing pages.
- **Evidence:** Base.Application/Business/ContactBusiness/PrayerRequestPages/PublicQueries/GetPrayerRequestPageBySlug.cs:18-20 (doc comment), :22 (no hostname param), :48-53 (first-active-company fallback).

### #155 · PrayerWall public page (Screen #171 area) — Public GetPrayerWallBySlug tenant resolution  — `High`

- **Module:** Multi-Tenancy Isolation  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** GetPrayerWallBySlug.cs:45-51 uses the identical first-active-company fallback (`// Tenant resolution (ISSUE-1 MVP)` comment at line 45), no hostname parameter on the query record (lines 16-21).
- **Gap identified:** Confirmed exactly as reported — the prayer wall listing (surfacing individual prayer requests, some containing personal disclosures) can resolve to the wrong tenant's data in production traffic that doesn't carry a recognizable hostname/subdomain.
- **Why it's a problem:** Compounds with the separate PrayForThis.cs finding: the wall LISTING itself can already be showing the wrong tenant's requests before any per-ID IDOR is even exploited.
- **Recommended solution:** Upgrade to hostname-based tenant resolution, consistent with the other public pages; prioritize alongside the PrayerRequestPage fix since they are the same feature family.
- **Production impact:** Applies in production for any multi-tenant deployment with the Prayer Wall feature enabled.
- **Business impact:** Potentially sensitive personal prayer request content displayed to the public under the wrong organization's branding/context.
- **Technical impact:** Fourth confirmed instance of the incomplete hostname-resolver rollout.
- **Evidence:** Base.Application/Business/ContactBusiness/PrayerRequests/PublicQueries/GetPrayerWallBySlug.cs:16-21 (no hostname param), :45-51 (first-active-company fallback).

### #253 · Public page slug resolution (all EXTERNAL_PAGE screens: OnlineDonationPage, CrowdFund, P2PCampaignPage, P2PFundraiserPage, EventRegistrationPage, VolunteerRegistrationPage, PrayerRequestPage) — Slug uniqueness scope  — `Medium`

- **Module:** Multi-Tenancy Isolation  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** Slug uniqueness is enforced per (CompanyId, Slug) via each page type's own validator, not globally unique across the whole platform.
- **Gap identified:** Combined with any tenant-resolution path that falls back to 'first active company' (either as the sole mechanism, as in VolunteerRegistrationPage/PrayerRequestPage/PrayerWall, or as a last-resort fallback after hostname matching fails, as in the already-upgraded pages), two different tenants choosing the same slug creates a real possibility of one tenant's public page being served under a request that was intended to resolve to a different tenant.
- **Why it's a problem:** The uniqueness constraint alone does not prevent slug collisions ACROSS tenants, only within one tenant — so the tenant-resolution layer is the only thing standing between a slug collision and a cross-tenant data leak, and that layer has already been shown (in the findings above) to be inconsistently implemented.
- **Recommended solution:** Either (a) treat this as an accepted risk once ALL public pages are upgraded to strict hostname-based resolution with NO first-active-company fallback in production (fail closed / 404 instead of falling back), or (b) additionally enforce global slug uniqueness for pages that lack a custom domain/subdomain requirement, to eliminate the collision vector entirely.
- **Production impact:** Latent risk that only manifests when a slug collision actually occurs across tenants and the request lacks a resolvable hostname (e.g. shared default domain, misconfigured DNS, or a not-yet-upgraded handler) — lower immediate likelihood than the confirmed handler-level bugs above, but the underlying design choice enables them.
- **Business impact:** If a collision does occur, the resulting leak would be entirely opaque to both tenants involved — likely to surface first as a support ticket rather than a design review.
- **Technical impact:** Recommend making 'first-active-company fallback' the ONE thing prohibited in production across the board, rather than relying on slug design alone.
- **Evidence:** Multiple validator classes reference (CompanyId, Slug) uniqueness (e.g. CrowdFundSlugValidator.MaxSlugLength, P2PCampaignPageSlugValidator.MaxSlugLength referenced in GetCrowdFundBySlug.cs/GetP2PCampaignPageBySlug.cs); the production-applying first-active-company fallback is present in GetVolunteerRegistrationPageBySlug.cs (lines 43-50), GetPrayerRequestPageBySlug.cs (lines 51-52), GetPrayerWallBySlug.cs (lines 49-50), and as a last-resort step in the otherwise-fixed GetCrowdFundBySlug.cs/GetP2PCampaignPageBySlug.cs/GetEventRegistrationPageBySlug.cs (private ResolveByHostnameAsync helper, step 4, lines 441-448).
- **Reviewer note:** not adversarially verified (Medium/Low)

## Field Collection · Ambassador

### #29 · Record Collection (AmbassadorCollection Create/Edit) — Ambassador cash collection entry  — `Critical`

- **Module:** Field Collection · Ambassador  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** CreateAmbassadorCollectionHandler/UpdateAmbassadorCollectionHandler Adapt the incoming AmbassadorCollectionRequestDto (including client-supplied CompanyId) directly onto the entity; no IHttpContextAccessor-derived CompanyId override exists in either handler or in the GraphQL resolver layer.
- **Gap identified:** Every AmbassadorCollection created or edited through the standard UI is persisted with CompanyId = 0 instead of the authenticated user's real tenant.
- **Why it's a problem:** All downstream tenant-scoped queries filter on CompanyId, so CompanyId=0 rows become invisible to the real tenant while polluting a shared bucket other CompanyId=0 lookups could expose.
- **Recommended solution:** In CreateAmbassadorCollectionHandler/UpdateAmbassadorCollectionHandler, derive CompanyId server-side via IHttpContextAccessor.GetCurrentUserStaffCompanyId() and overwrite dto.CompanyId before Adapt, mirroring CreateAmbassador.cs:102-103. Remove companyId as a client-writable GraphQL argument.
- **Production impact:** Every cash collection recorded is at risk of persisting with CompanyId=0 on day one.
- **Business impact:** Field-collected donations would not reconcile against any company ledger.
- **Technical impact:** Corrupts CompanyId on the core transactional table; later backfill requires manual forensics.
- **Evidence:** PSS_2.0_Backend/.../AmbassadorCollections/Commands/CreateAmbassadorCollection.cs:42-90 (full handler, no CompanyId override); UpdateAmbassadorCollection.cs:38-70 (same); PSS_2.0_Frontend/.../AmbassadorCollectionMutation.ts:4-27; view-page.tsx:231 `companyId: vals.companyId ?? 0`; Base.API/EndPoints/FieldCollection/Mutations/AmbassadorCollectionMutations.cs:7-11 (no override at resolver); contrast Ambassadors/Commands/CreateAmbassador.cs:102-103.
- **Reviewer note:** CreateAmbassadorCollection.cs and UpdateAmbassadorCollection.cs Adapt the client DTO directly with no `dto.CompanyId = httpContextAccessor.GetCurrentUserStaffCompanyId()` anywhere in either handler (confirmed by full read of both files). Contrast with Ambassadors/Commands/CreateAmbassador.cs:102-103, which does exactly this override. FE mutation (AmbassadorCollectionMutation.ts:4-27) declares `$companyId: Int!` as a required client arg, and view-page.tsx:231 sends `companyId: vals.companyId ?? 0` with no companyId ever populated in DEFAULT_FORM_VALUES or set from session anywhere in the file. Verified the GraphQL resolver (AmbassadorCollectionMutations.cs:7-11) also passes the DTO straight to mediator.Send with no server-side override. Gap is real and exactly as described.

### #30 · Record Collection / Ambassador Collection grid — Approve / Void / Flag / Delete / GetById / BulkApprove on AmbassadorCollection  — `Critical`

- **Module:** Field Collection · Ambassador  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** All six handlers query AmbassadorCollections by ID only, with IsDeleted==false as the sole additional predicate; no CompanyId check anywhere in the lookup chain.
- **Gap identified:** Every lifecycle mutation and the single-record read on AmbassadorCollection is missing tenant scoping.
- **Why it's a problem:** With no EF Core global query filter anywhere in the app, tenant isolation depends entirely on each handler adding its own CompanyId predicate. Any authenticated user who can guess/enumerate an ID belonging to another company can read, approve, flag, void, edit, or delete that company's donation record.
- **Recommended solution:** Add `&& a.CompanyId == httpContextAccessor.GetCurrentUserStaffCompanyId()` to every lookup in this command/query family; add regression tests asserting cross-tenant 404 on all six operations.
- **Production impact:** A cross-tenant IDOR reachable by any authenticated staff user with module access, on the transaction table representing donor cash.
- **Business impact:** Any NGO tenant could tamper with another NGO's donation records — severe trust/compliance breach.
- **Technical impact:** Systemic missing-filter pattern across the whole command family; needs coordinated fix plus audit of other modules.
- **Evidence:** PSS_2.0_Backend/.../AmbassadorCollections/Commands/ApproveAmbassadorCollection.cs:17-18; VoidAmbassadorCollection.cs:24-25; FlagAmbassadorCollection.cs:24-25; DeleteAmbassadorCollection.cs:14; Queries/GetAmbassadorCollectionById.cs:14-21; Commands/BulkApproveAmbassadorCollections.cs:23-28; grep for HasQueryFilter in Base.Infrastructure returned 0 results.
- **Reviewer note:** Read all six files in full. ApproveAmbassadorCollection.cs:17-18, VoidAmbassadorCollection.cs:24-25, FlagAmbassadorCollection.cs:24-25, DeleteAmbassadorCollection.cs:14, GetAmbassadorCollectionById.cs:14-21, and BulkApproveAmbassadorCollections.cs:23-28 all filter strictly on AmbassadorCollectionId (or an ID-array) plus IsDeleted==false — none add a CompanyId predicate. Grep for HasQueryFilter across Base.Infrastructure returned zero matches, confirming there is no EF Core global tenant filter safety net anywhere in the codebase. This is a genuine, systemic cross-tenant IDOR exactly as described.

### #31 · Record Collection index page (KPI summary tiles) — AmbassadorCollection Summary widget (Month-to-date amount, pending counts)  — `Critical`

- **Module:** Field Collection · Ambassador  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** GetAmbassadorCollectionSummaryHandler builds baseQuery filtered only by IsDeleted and optional branchId, computing all five aggregates with no CompanyId predicate.
- **Gap identified:** The dashboard summary widget aggregates cash-collection totals and pending counts across every tenant in the database, not just the requesting user's company.
- **Why it's a problem:** A company viewing their dashboard sees platform-wide sums/pending counts across every tenant — a direct, routinely-visible cross-tenant financial data leak.
- **Recommended solution:** Add a mandatory CompanyId filter derived from IHttpContextAccessor to baseQuery before any aggregate call.
- **Production impact:** Every company's dashboard shows platform-wide numbers on first load.
- **Business impact:** One tenant can infer another's aggregate cash-collection volume and backlog by loading their own dashboard.
- **Technical impact:** Same systemic missing-CompanyId-filter pattern, on a read path rendered directly on-screen with no user action required.
- **Evidence:** PSS_2.0_Backend/.../AmbassadorCollections/Queries/GetAmbassadorCollectionSummary.cs:40-57 (full handler body reviewed, no CompanyId filter present anywhere).
- **Reviewer note:** Full read of GetAmbassadorCollectionSummary.cs confirms baseQuery (line 40-41) is `dbContext.AmbassadorCollections.Where(a => a.IsDeleted == false)` with only an optional branchId filter added afterward (line 43-44); no CompanyId filter anywhere in the handler before any of the five aggregate calls (monthToDateCount/Amount, pendingCount, pendingBackDatedCount, pendingHighValueCount, averageAmount). Confirmed exactly as described.

### #129 · Ambassador (profile edit) — Update Ambassador (settlement terms: CompensationType, CommissionPercent, StaffId, Status)  — `High`

- **Module:** Field Collection · Ambassador  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** UpdateAmbassadorHandler fetches by AmbassadorId + IsDeleted only; validator's uniqueness check keys off client-supplied dto.CompanyId rather than the authenticated user's tenant.
- **Gap identified:** Ambassador Update has the same missing-tenant-scope IDOR as the collection mutations, exposing commission/settlement terms.
- **Why it's a problem:** CommissionPercent/CompensationType drive settlement/payroll; an unscoped update lets Company A silently alter Company B's ambassador commission rate or status by ID, with zero ownership check.
- **Recommended solution:** Add `&& a.CompanyId == httpContextAccessor.GetCurrentUserStaffCompanyId()` to the entity lookup in UpdateAmbassadorHandler; re-derive CompanyId server-side rather than trusting dto.CompanyId in the validator.
- **Production impact:** Ambassador settlement configuration can be modified cross-tenant via a predictable integer ID.
- **Business impact:** Incorrect commission payouts or unauthorized deactivation of another organization's field ambassador.
- **Technical impact:** Inconsistent tenant-safety between Create (correct) and Update (missing) for the same entity.
- **Evidence:** PSS_2.0_Backend/.../Ambassadors/Commands/UpdateAmbassador.cs:81-82 (entity fetch, no CompanyId predicate), line 53 (validator trusts dto.CompanyId); contrast CreateAmbassador.cs:102-103.
- **Reviewer note:** Full read of UpdateAmbassador.cs confirms entity fetch at lines 81-82 is `dbContext.Ambassadors.FirstOrDefaultAsync(a => a.AmbassadorId == ambassadorId && a.IsDeleted == false, ...)` with no CompanyId predicate, then mutates CompensationType/CommissionPercent/StaffId/BranchId/Status directly (lines 86-96). Line 53 of the validator's AmbassadorCode-uniqueness check does trust `dto.CompanyId` (`a.CompanyId == dto.CompanyId`) rather than deriving it server-side. Contrast with CreateAmbassador.cs:102-103 which correctly derives CompanyId from context. Confirmed exactly as described.

### #130 · Ambassador / Receipt Book — Assign Receipt Book to Ambassador  — `High`

- **Module:** Field Collection · Ambassador  |  **Category:** business  |  **Verification:** ADJUSTED
- **Current implementation:** AssignAmbassadorReceiptBookHandler only completes the same ambassador's own prior active assignment(s) before inserting the new AmbassadorReceiptBookAssignment row; no check for an existing active assignment of the target book to a different ambassador. AmbassadorReceiptBookAssignmentConfiguration.cs declares only non-unique indexes on AmbassadorId and ReceiptBookId separately.
- **Gap identified:** The same physical receipt book can be actively assigned to two different ambassadors simultaneously.
- **Why it's a problem:** Receipt-book allocation is the basis of field cash reconciliation; if two ambassadors can hold the same book concurrently, receipts/collections against that book's number range can no longer be traced to one accountable person.
- **Recommended solution:** Before inserting the new assignment, check `AmbassadorReceiptBookAssignments.AnyAsync(x => x.ReceiptBookId == targetBookId && x.AssignmentStatus == "Active" && x.AmbassadorId != ambassadorId)` and reject/require completing the other assignment first; add a partial unique index on (ReceiptBookId) WHERE AssignmentStatus='Active' in AmbassadorReceiptBookAssignmentConfiguration.cs.
- **Production impact:** Cash reconciliation for a given receipt book becomes ambiguous whenever this race is hit.
- **Business impact:** Loss of accountability for physical receipt books — a core control against field cash misappropriation.
- **Technical impact:** No application or DB-level guard; silent double-assignment with no error surfaced.
- **Evidence:** PSS_2.0_Backend/.../Ambassadors/Commands/AssignAmbassadorReceiptBook.cs:44-72 (completion loop scoped to same ambassador only; unconditional overwrite of receiptBook.StaffId/BranchId/IssuedDate); PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/FieldCollectionConfigurations/AmbassadorReceiptBookAssignmentConfiguration.cs:22-23 (only non-unique indexes present — this is the correct file, not ReceiptBookConfiguration.cs as originally cited).
- **Reviewer note:** Core claim confirmed: AssignAmbassadorReceiptBookHandler's completion loop (lines 44-53) is scoped to `a.AmbassadorId == command.AmbassadorId` only and never checks whether the target ReceiptBookId already has an active assignment to a different ambassador before inserting the new one; receiptBook.StaffId/BranchId/IssuedDate are unconditionally overwritten (lines 70-72). However, the cited evidence file for the missing unique index is wrong: ReceiptBookConfiguration.cs (the ReceiptBook entity config) has no such index because it isn't the right place for it — the correct configuration file is AmbassadorReceiptBookAssignmentConfiguration.cs, which was read in full and confirmed to only declare non-unique `HasIndex(r => r.AmbassadorId)` and `HasIndex(r => r.ReceiptBookId)` (lines 22-23), with no unique/partial index on (ReceiptBookId, AssignmentStatus). Substance of the finding stands; evidence citation corrected.

### #131 · Ambassador Collection Distribution (cash allocation to donor purposes) — Distribute a collected donation across ContactDonationPurpose / donor allocations  — `High`

- **Module:** Field Collection · Ambassador  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** CreateAmbassadorCollectionDistributionHandler Adapts the client DTO directly onto the entity and saves; validator only checks required-field presence, no amount-sum or CompanyId server-side logic.
- **Gap identified:** Any number of distribution records, in any currency and amount, can be created against a single AmbassadorCollection with no cross-check to the actual amount collected.
- **Why it's a problem:** This reconciliation step turns raw field cash into attributed donor records; without a sum-check, a collection of 100 can be 'distributed' as 10,000 across donors, or left under-distributed, with no system signal. Missing CompanyId override also risks wrong-tenant rows.
- **Recommended solution:** Validate SUM(existing distributions for AmbassadorCollectionId) + new.DonationAmount <= AmbassadorCollection.DonationAmount in the command validator; derive CompanyId server-side from the parent AmbassadorCollection or authenticated user context.
- **Production impact:** Cash-to-donor allocation has no integrity check at go-live.
- **Business impact:** Donor-level giving records (used for tax receipts/donor history) can be created with amounts unrelated to what was actually collected.
- **Technical impact:** Same CompanyId-trust-from-client pattern as elsewhere in this module, now on a financial allocation table.
- **Evidence:** PSS_2.0_Backend/.../AmbassadorCollectionDistributions/Commands/CreateAmbassadorCollectionDistribution.cs:1-30 (full file reviewed: no sum-check, no CompanyId override).
- **Reviewer note:** Full read of CreateAmbassadorCollectionDistribution.cs confirms the handler (lines 21-29) Adapts the DTO directly and saves with zero validation logic beyond the FluentValidator's required-field checks (lines 9-18) — no sum-check against the parent AmbassadorCollection.DonationAmount, and no server-side CompanyId derivation despite AmbassadorCollectionDistribution having its own CompanyId column. Confirmed exactly as described.

### #132 · Ambassador Performance / Record Collection summary — Multi-currency donation total aggregation  — `High`

- **Module:** Field Collection · Ambassador  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** Both handlers sum raw DonationAmount across all currencies for period/lifetime totals, leaderboard ranking, and MonthToDateAmountBase, with only a boolean mixedCurrencyFlag as acknowledgment, no FX conversion.
- **Gap identified:** KPI totals, ambassador leaderboard ranking, and average-per-visit are all computed by summing raw DonationAmount values across mixed currencies as if they were the same unit.
- **Why it's a problem:** An ambassador collecting in a high-denomination currency structurally outranks one in a low-denomination currency regardless of real value; MonthToDateAmountBase is meaningless whenever multiple currencies are in play — misleading numbers on a performance/settlement screen.
- **Recommended solution:** Restrict aggregates to a single company base currency with FX conversion via the existing IFxRateService pattern, or refuse to render a blended total and show per-currency subtotals when mixedCurrencyFlag is true.
- **Production impact:** Materially wrong numbers shown on a screen marked as source-of-truth for ambassador ranking.
- **Business impact:** Ambassador performance evaluation and commission/settlement decisions could be based on meaningless blended totals in any multi-currency deployment.
- **Technical impact:** Comment trail shows this was a consciously deferred gap ('deferred to V2') that ships live in the current build.
- **Evidence:** PSS_2.0_Backend/.../Ambassadors/Queries/GetAmbassadorPerformance.cs:97 (deferred-to-V2 comment), 126,130,191,214,235,252,277,304,431 (raw Sum + mixedCurrencyFlag); PSS_2.0_Backend/.../AmbassadorCollections/Queries/GetAmbassadorCollectionSummary.cs:51,63 (MonthToDateAmountBase raw sum, no conversion).
- **Reviewer note:** Grep of GetAmbassadorPerformance.cs confirms line 97's comment 'Full FX conversion via IFxRateService is deferred to V2', raw `.Sum(c => c.DonationAmount)` calls at lines 126, 191, 214, 235, 252, 277, 304, and mixedCurrencyFlag boolean at line 130/431 with no gating of the numeric totals. GetAmbassadorCollectionSummary.cs line 51 sums DonationAmount directly into a field literally named MonthToDateAmountBase with no currency conversion applied anywhere in that handler. Confirmed exactly as described.

### #133 · Record Collection / Receipt Book — Receipt-number validation against physical book range  — `High`

- **Module:** Field Collection · Ambassador  |  **Category:** business  |  **Verification:** ADJUSTED
- **Current implementation:** CreateAmbassadorCollectionHandler checks only ReceiptNumber+ReceiptBookId uniqueness, no range check against ReceiptStartNo/EndNo, and never calls GlobalReceiptDonationInventory.ApplyOnCreateAsync (the existing, working helper used by GlobalReceiptDonations) or otherwise creates/updates a ReceiptBookTransaction row; AmbassadorReceiptBookAssignment.UsedCount is set to 0 at assignment time and never incremented anywhere in Base.Application.
- **Gap identified:** There is no working mechanism reconciling receipts physically printed in a book against receipts recorded as collections for the Ambassador Collection flow specifically.
- **Why it's a problem:** Receipt-book range validation and used-count tracking are structural fraud-prevention controls; for the Ambassador field-collection flow specifically, neither is enforced, so an ambassador can record any receipt number in or out of the book's range with no rejection, and the book's assignment-level UsedCount never reflects reality.
- **Recommended solution:** In CreateAmbassadorCollectionHandler, call the existing GlobalReceiptDonationInventory.ApplyOnCreateAsync (or an equivalent) to validate ReceiptNumber against the assigned ReceiptBook's range and upsert the ReceiptBookTransaction row, exactly as the GlobalReceiptDonation flow already does; also increment AmbassadorReceiptBookAssignment.UsedCount on successful collection create, or retire that field in favor of the ReceiptBookTransaction-derived count for consistency.
- **Production impact:** No system-enforced traceability between issued receipt books and recorded field collections at go-live, even though the codebase already has a proven working pattern for this in a sibling module.
- **Business impact:** Cannot detect receipt-number gaps, duplication, or misuse of a book's numbered range within the Ambassador Collection workflow specifically.
- **Technical impact:** AmbassadorReceiptBookAssignment.UsedCount is dead/always-0 for this module; ReceiptBookTransaction itself is NOT dead code system-wide (it is actively used and read by GetReceiptBookById/GetReceiptBookSummary for the GlobalReceiptDonations flow) but is simply unreached from the Ambassador Collection create path.
- **Evidence:** PSS_2.0_Backend/.../AmbassadorCollections/Commands/CreateAmbassadorCollection.cs:69-78 (uniqueness only, no range check, no ReceiptBookTransaction call); grep confirming UsedCount only assigned =0 at CreateAmbassador.cs:157 and AssignAmbassadorReceiptBook.cs:61, never incremented; CONTRAST PSS_2.0_Backend/.../DonationBusiness/GlobalReceiptDonations/Services/GlobalReceiptDonationInventory.cs:22-81 (working range validation + ReceiptBookTransaction upsert, actively called from the GlobalReceiptDonation create flow) and Queries/GetReceiptBookById.cs:27-36 / GetReceiptBookSummary.cs:26-41 (which read ReceiptBookTransactions to compute live UsedCount/VoidedCount/UsagePct) — proving the pattern works elsewhere but is not wired into AmbassadorCollections.
- **Reviewer note:** Confirmed for the Ambassador Collection module: CreateAmbassadorCollection.cs (lines 69-78) only checks ReceiptNumber uniqueness scoped to ReceiptBookId — no ReceiptStartNo/ReceiptEndNo range check, and it never calls a reconciliation helper. AmbassadorReceiptBookAssignment.UsedCount is indeed only ever set to 0 (CreateAmbassador.cs:157, AssignAmbassadorReceiptBook.cs:61) and never incremented. HOWEVER the claim that 'there is no working mechanism anywhere in the system' is overstated and needs correction: a fully working, range-validating, used/voided-tracking mechanism DOES exist and IS wired up — GlobalReceiptDonationInventory.ApplyOnCreateAsync (Base.Application/Business/DonationBusiness/GlobalReceiptDonations/Services/GlobalReceiptDonationInventory.cs), called from the sibling GlobalReceiptDonation create flow, validates the serial against ReceiptStartNo/EndNo and upserts a ReceiptBookTransaction row to USED, which GetReceiptBookById.cs/GetReceiptBookSummary.cs then read to compute live UsedCount/VoidedCount/RemainingCount/UsagePct for the Receipt Book screens. So ReceiptBookTransaction is not dead code and the reconciliation pattern is proven and functional — it was simply never wired into CreateAmbassadorCollectionHandler for this specific module, which is a real but narrower, easier-to-fix gap (call the existing helper) than 'no working mechanism anywhere.'

### #134 · Record Collection form — Receipt photo evidence & field location capture  — `High`

- **Module:** Field Collection · Ambassador  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** Location field is a free-text Input; Photo of Receipt control's onClick only shows a toast saying the upload pipeline isn't wired — no file capture/upload and no device geolocation capture exist.
- **Gap identified:** The two evidentiary controls this field-collection workflow depends on for cash-integrity verification — photographic proof of the receipt and the collection's actual location — are non-functional/manually-typed respectively.
- **Why it's a problem:** Without device-captured GPS and real photo upload, both fields are trivially fabricated or left blank, removing the two controls most likely to deter/detect misreported field collections.
- **Recommended solution:** Wire ReceiptPhotoPath to a real multipart upload (blob storage) and capture Location via navigator.geolocation.getCurrentPosition (with a clearly-flagged manual-entry fallback).
- **Production impact:** A visibly complete-looking form ships with two of its integrity controls silently non-functional.
- **Business impact:** No verifiable proof of receipt issuance or collection location — undermines any later dispute/audit.
- **Technical impact:** N/A — pure functional gap.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/page-components/crm/fieldcollection/collectionlist/collectionlist-form.tsx:428-461 (full section reviewed).
- **Reviewer note:** Read collectionlist-form.tsx:428-461 directly. Confirmed: Location (line 442-443) is a plain `<Input>` bound to register("location") with placeholder text, no navigator.geolocation call anywhere in the file section. Photo of Receipt (lines 446-460) is a `<button>` whose onClick does exactly `import("sonner").then(({ toast }) => toast.info("Photo upload pipeline not yet wired"))` — no file input, no upload logic. Confirmed exactly as described.

### #236 · Ambassador list / Ambassador Performance — Ambassador grid row aggregation (CollectionsThisMonth, CollectionsYtd, DonorsVisited, book usage %)  — `Medium`

- **Module:** Field Collection · Ambassador  |  **Category:** performance  |  **Verification:** CONFIRMED
- **Current implementation:** GetAmbassadorsHandler, after the paginated grid query, loops per returned row and for each one re-fetches the full Ambassador entity with 5 Includes plus runs 4 separate SumAsync/CountAsync queries (and conditionally a 5th), to populate [NotMapped] computed fields on the Ambassador entity.
- **Gap identified:** Confirmed N+1 query pattern: roughly 6 additional DB round-trips per grid row on top of the base paginated query.
- **Why it's a problem:** On a default page size (e.g. 20-25 rows) this is 120-150+ sequential DB calls to render one grid page, which will visibly slow page load as ambassador/collection volume grows in production and does not scale past a small pilot dataset.
- **Recommended solution:** Replace the per-row loop with a single set of GROUP BY aggregate queries (keyed by AmbassadorId) executed once against the full page's AmbassadorId set, then join results in memory.
- **Production impact:** Grid page-load latency will grow linearly with page size and degrade further as collection volume grows.
- **Business impact:** Poor perceived performance on the Ambassador list, a screen used routinely by field-ops managers.
- **Technical impact:** Classic N+1 pattern; straightforward to fix once flagged but currently ships as the default query path.
- **Evidence:** PSS_2.0_Backend/.../Ambassadors/Queries/GetAmbassadors.cs (foreach loop over gridResult.Data re-fetching full entity + 5 Includes + 4-5 aggregate queries per row).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #237 · Field Collection / Record Collection — Integration with central donation ledger  — `Medium`

- **Module:** Field Collection · Ambassador  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** AmbassadorCollection is a standalone table in the `fund` schema with its own DonationAmount/CurrencyId/ReceiptNumber fields. A grep for GlobalDonation/finance.Donations/IDonationService/CreateDonation across the entire FieldCollectionBusiness folder returns zero matches.
- **Gap identified:** Field-collected donations never flow into (or link to) the central donation ledger used by the rest of the platform.
- **Why it's a problem:** This creates two parallel, disconnected sources of donation truth: a donor's total giving history, tax-receipt consolidation, and org-wide financial/donation reporting built against the central ledger will silently exclude every donation an ambassador collects in the field, undercounting real fundraising activity and breaking a unified donor view.
- **Recommended solution:** On Approve (the point at which an AmbassadorCollection becomes trusted), create/link a corresponding central donation record so it participates in donor history, receipting, and org-wide reporting, consistent with the architecture used elsewhere in the platform.
- **Production impact:** Org-wide donation reports and donor giving histories will be incomplete for any organization using ambassador field collection.
- **Business impact:** Understated fundraising totals and an incomplete donor relationship view for any donor who has given through a field ambassador.
- **Technical impact:** Requires a deliberate integration decision (event-driven vs. inline) not currently present anywhere in the code.
- **Evidence:** Grep across PSS_2.0_Backend/.../Base.Application/Business/FieldCollectionBusiness for GlobalDonation|finance.Donations|IDonationService|CreateDonation returned zero matches (only unrelated match in GetReceiptBookTrackingByBookId.cs is a false positive on a different token).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #238 · Receipt Book — Receipt book lifecycle state  — `Medium`

- **Module:** Field Collection · Ambassador  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** The ReceiptBook entity has BookNo/ReceiptStartNo/ReceiptEndNo/ReceiptCount/StaffId/BranchId/IssuedDate but no Status/lifecycle field at all; book state (available/assigned/depleted/closed) can only be inferred indirectly from AmbassadorReceiptBookAssignment.AssignmentStatus and a computed usage percentage.
- **Gap identified:** No enforced state machine exists for a receipt book's own lifecycle, so nothing prevents assigning an already-depleted or administratively-closed book, and no audit trail records book-level lifecycle transitions independent of assignment records.
- **Why it's a problem:** Receipt books are physical, numbered assets that should have an explicit auditable lifecycle (e.g. Available -> Assigned -> Depleted -> Closed); relying purely on a derived usage percentage from collection rows means a book can appear 'available' for reassignment even after being fully used, misreported, or lost.
- **Recommended solution:** Add a Status column to ReceiptBook with an explicit state machine (Available/Assigned/Depleted/Closed/Lost) enforced at assignment and completion time, with audit fields for each transition.
- **Production impact:** Receipt book governance relies entirely on derived, non-authoritative signals.
- **Business impact:** Weaker audit trail for a core physical-asset-accountability control in the field-collection program.
- **Technical impact:** Schema-level gap; would require a migration to add the Status column.
- **Evidence:** PSS_2.0_Backend/.../Base.Domain/Models/FieldCollectionModels/ReceiptBook.cs (no Status property); PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/FieldCollectionConfigurations/ReceiptBookConfiguration.cs (no Status column mapped).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #239 · Record Collection form — Offline-first field data entry  — `Medium`

- **Module:** Field Collection · Ambassador  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** AmbassadorCollectionViewPage uses standard Apollo `useMutation`/`useLazyQuery` calls directly against the network with no offline queue, IndexedDB cache, service worker, or 'pending sync' UI state; a grep across app/[lang]/crm/fieldcollection for offline/navigator.geolocation/camera returns zero matches.
- **Gap identified:** There is no offline-capable submission path for a workflow explicitly designed for field ambassadors, who routinely operate with intermittent or no connectivity.
- **Why it's a problem:** An ambassador who fills out a collection form in a location with no signal will lose the entered data on submit failure, with no local draft persistence or background-sync retry — directly contradicting the 'offline/field workflows' focus area this module is meant to support.
- **Recommended solution:** Add a local-first submission queue (e.g. IndexedDB-backed outbox + background sync / retry-on-reconnect) with an explicit 'pending sync' badge on locally-queued records, rather than a bare synchronous mutation call.
- **Production impact:** Field data entry is not resilient to the connectivity conditions the feature is built for.
- **Business impact:** Risk of lost donation records (and the associated cash-accountability gap) whenever a field ambassador has no signal at time of entry.
- **Technical impact:** Would require introducing an offline-sync layer that does not currently exist anywhere in this screen's stack.
- **Evidence:** PSS_2.0_Frontend/.../ambassadorcollection/view-page.tsx (Apollo useMutation/useLazyQuery direct network calls, no offline queue); grep across app/[lang]/crm/fieldcollection for offline|navigator.geolocation|camera returning zero matches.
- **Reviewer note:** not adversarially verified (Medium/Low)

### #319 · Record Collection — Auto-verification of below-threshold collections  — `Low`

- **Module:** Field Collection · Ambassador  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** CreateAmbassadorCollectionHandler auto-computes Status = "Pending" only when the collection is back-dated more than 7 days or DonationAmount >= 5000; every other collection is auto-set to "Verified" immediately at creation time, with no second-person review.
- **Gap identified:** The vast majority of field collections (anything under the 5000 threshold, entered on time) are self-verified by the same ambassador who recorded them, with zero segregation of duties.
- **Why it's a problem:** For a cash-handling workflow, allowing the person who collects the money to also implicitly 'approve' the record (by simply staying under a known threshold) removes the second-person control that the Approve/Flag/Void lifecycle otherwise implies exists for every collection.
- **Recommended solution:** Require explicit supervisor approval for all collections (or at minimum a random/periodic audit sample of auto-verified ones), rather than treating below-threshold, on-time entries as self-verified by default.
- **Production impact:** Internal control weakness rather than an outright defect — the feature works as coded but the control design is weak for a cash-handling process.
- **Business impact:** Reduced ability to detect or deter under-threshold misreporting by field ambassadors.
- **Technical impact:** N/A — business-rule/process design gap.
- **Evidence:** PSS_2.0_Backend/.../AmbassadorCollections/Commands/CreateAmbassadorCollection.cs (Status auto-computed Pending only if back-dated >7 days or DonationAmount >= 5000m HighValueThreshold; else auto-"Verified"); consistent with HighValueThreshold=5000m / BackDateThresholdDays=7 constants in GetAmbassadorCollectionSummary.cs:18-19.
- **Reviewer note:** not adversarially verified (Medium/Low)

## Communication

### #12 · Email delivery-status webhook (Notify infrastructure, backs all Email screens) — SendGrid webhook signature validation  — `Critical`

- **Module:** Communication  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** WebhookController.ReceiveSendGridEvents (api/webhooks/sendgrid/events) is protected by [ValidateSendGridWebhook] (line 42), but ReceiveSendGridEventsRaw (api/webhooks/sendgrid/events-raw, line 88) is [AllowAnonymous] with the signature attribute commented out (line 90: `//[ValidateSendGridWebhook]`), and still deserializes the raw body and calls `_webhookProcessor.ProcessEventsAsync(events, cancellationToken)` at line 127 exactly like the validated endpoint.
- **Gap identified:** Confirmed verbatim: lines 88-91 show `[AllowAnonymous]` with the validation attribute commented out, and line 127 fully processes attacker-supplied JSON events with no signature check whatsoever — a live, routable, unauthenticated data-mutation endpoint.
- **Why it's a problem:** Anyone who discovers the URL can POST fabricated SendGrid event JSON (delivered/bounce/unsubscribe/spamreport) with no signature check, and the processor updates EmailSendQueue/EmailExecutionLog/analytics — falsifying suppression/delivery data or masking real bounce/complaint problems.
- **Recommended solution:** Remove the raw debug endpoint from production (or gate behind an authenticated admin route + feature flag) and require [ValidateSendGridWebhook] on any endpoint that mutates delivery-status data.
- **Production impact:** Publicly reachable unauthenticated data-mutation endpoint — a genuine security hole if the route is found.
- **Business impact:** Falsified delivery/bounce/complaint data could hide real deliverability problems or corrupt Email Analytics used for reporting.
- **Technical impact:** No authentication, no signature check, direct write path into EmailSendQueue/EmailExecutionLog tables.
- **Evidence:** Base.API/EndPoints/Notify/Controllers/WebhookController.cs:88-91,127

### #13 · Email Template/Campaign/SendJob (all outbound email) — Unsubscribe / opt-out compliance  — `Critical`

- **Module:** Communication  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** ContactEmailAddress (Base.Domain/Models/ContactModels/ContactEmailAddress.cs) has no suppression/opt-out field at all (only ContactEmailAddressId, EmailTypeId, Email, IsPrimary, IsVerified). ContactEmailRecipientProvider.BuildDynamicQuery (Base.Infrastructure/Repositories/Email/ContactEmailRecipientProvider.cs:285-291) filters only IsActive/IsDeleted/IsPrimary-email-exists/CompanyId. SendGridWebhookProcessor.ProcessUnsubscribeEventAsync (Base.Support/Email/Webhooks/SendGridWebhookProcessor.cs:316-320) only calls UpdateUnsubscribedAsync which sets `IsUnsubscribed` on the EmailSendQueue row (Base.Domain/Models/NotifyModels/EmailSendQueue.cs:69) — confirmed by grep that `IsUnsubscribed` is used only in EmailAnalytics reporting queries, never in any recipient-resolution/campaign-audience query.
- **Gap identified:** Confirmed: no ContactEmailAddress/Contact-level suppression flag exists anywhere in the domain model, and the one 'IsUnsubscribed' field that does exist lives per-send-record on EmailSendQueue (historical/reporting only) and is never read when resolving recipients for a future send — grep across Base.Application/Base.Infrastructure confirms IsUnsubscribed is consumed only by GetEmailAnalyticsRecipientActivity.cs/ExportEmailAnalyticsRecipientActivity.cs (reports), not by BuildDynamicQuery or any campaign send path.
- **Why it's a problem:** A recipient who unsubscribes continues to receive every subsequent campaign/notification/scheduled email — violates CAN-SPAM/CASL/GDPR/PECR opt-out requirements, a direct legal/reputational liability for every tenant NGO.
- **Recommended solution:** Add a suppression flag (e.g. ContactEmailAddress.IsUnsubscribed/UnsubscribedDate) set by the webhook processor on unsubscribe/spamreport/group_unsubscribe events, filter it in BuildDynamicQuery like the SMS DoNotSMS pattern, and/or wire SendGrid ASM group IDs as a second suppression layer.
- **Production impact:** Every tenant is currently non-compliant with anti-spam law for the entire Email module.
- **Business impact:** Regulatory fines, ISP blacklisting, sender-reputation damage for all tenants sharing the SendGrid account.
- **Technical impact:** No suppression path exists anywhere between webhook ingestion and the recipient-resolution query.
- **Evidence:** Base.Domain/Models/ContactModels/ContactEmailAddress.cs:1-21 (no suppression field); Base.Infrastructure/Repositories/Email/ContactEmailRecipientProvider.cs:285-291; Base.Domain/Models/NotifyModels/EmailSendQueue.cs:69 (IsUnsubscribed lives here, per-send only); Base.Support/Email/Webhooks/SendGridWebhookProcessor.cs:316-320; grep confirms IsUnsubscribed used only in EmailAnalytics report queries

### #14 · WhatsApp Campaign (Send Now) — WhatsApp bulk campaign dispatch  — `Critical`

- **Module:** Communication  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** SendWhatsAppCampaignNowHandler (Base.Application/Business/NotifyBusiness/WhatsAppCampaigns/SendNowCommand/SendWhatsAppCampaignNow.cs) transitions the campaign to SENT and writes WhatsAppCampaignRecipient rows using new Random() to fabricate delivery status (line 100: `var rng = new Random();`, lines 110-125 branch 5%/7%/88% into FAILED/DELIVERED/READ), never calling IWhatsAppSenderService/IMetaWhatsAppClient which exist in the codebase (Base.Infrastructure/Services/MetaWhatsApp/WhatsAppSenderService.cs, Base.Application/Interfaces/IMetaWhatsAppClient.cs) for 1:1 messages.
- **Gap identified:** Confirmed verbatim in code: line 8 TODO 'WHATSAPP_DISPATCH_SERVICE_NOT_WIRED — actual Meta Graph API send pending'; lines 80-81 'SERVICE_PLACEHOLDER: simplified opt-in resolution' / 'TODO: DYNAMIC_QUERY_RESOLVER_NOT_WIRED'; lines 82-96 use raw dbContext.Contacts filtered only by CompanyId/IsDeleted/has-phone with no Segment/SavedFilter/Tag/Exclude resolution (contrast: SendSMSCampaignNow.cs lines 59-127 has full Tag/SavedFilter/SavedSegment/Exclude resolution, proving WhatsApp's is a stub by omission); lines 98-134 RNG-driven fake delivery outcomes with fabricated per-message cost.
- **Why it's a problem:** Any NGO relying on this screen to reach donors/beneficiaries believes messages were sent (status 'Sent', recipients 'Delivered'/'Read' with timestamps and simulated cost) but zero messages ever leave the system — silent total failure of a core communication channel with fabricated success telemetry, and campaign 'audience' is not even the correct segment since none of the targeting rules the UI presumably exposes are applied.
- **Recommended solution:** Wire SendWhatsAppCampaignNowHandler to IWhatsAppSenderService per resolved recipient, persist the real Meta message ID, and drive recipient status from real Meta webhook callbacks instead of RNG. Also port the RecipientSource/Segment/SavedFilter/Exclude resolution already implemented in SendSMSCampaignNow.cs.
- **Production impact:** Feature is entirely non-functional; customers will discover zero real-world delivery only when recipients complain they received nothing.
- **Business impact:** Direct reputational/compliance risk (a fundraising appeal or emergency notice reported 'Sent/Read' that never arrived); erodes trust in the whole Communication module once discovered.
- **Technical impact:** Campaign audience, delivery, and cost data in WhatsAppCampaignRecipient/WhatsAppCampaign is entirely fabricated and cannot be reconciled with any real provider records.
- **Evidence:** Base.Application/Business/NotifyBusiness/WhatsAppCampaigns/SendNowCommand/SendWhatsAppCampaignNow.cs:8,80-96,98-134; Base.Infrastructure/Services/MetaWhatsApp/WhatsAppSenderService.cs (real sender exists, unused here); Base.Application/Interfaces/IMetaWhatsAppClient.cs; contrast Base.Application/Business/NotifyBusiness/SMSCampaigns/SendNowCommand/SendSMSCampaignNow.cs:59-127 (real audience resolution SMS has that WhatsApp lacks)

### #100 · Company Email Provider / Email SendJob reliability — Provider failover (Primary → Fallback)  — `High`

- **Module:** Communication  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** EmailExecutorService.cs lines 166-172 fetch the PRIMARY provider; lines 173-186 enter a fallback branch when the primary/DefaultFromEmail is null, fetch `companyFallbackEmailProvider` (line 176-179), but line 181 re-checks `companyEmailProvider` (the same already-null primary variable, not the freshly-fetched fallback) and throws regardless — confirmed exact bug. EmailSenderService.cs lines 82-89 fetch and use only the 'PRIMARY' provider, throwing if none exists, with zero reference to any fallback during the actual send phase. EmailProviderFactory.cs lines 20-24 implement only a 'SENDGRID' case, throwing NotSupportedException for any other configured provider type.
- **Gap identified:** All three layers confirmed broken/absent exactly as claimed: (1) EmailExecutorService's fallback check tests the wrong variable so it always throws instead of using the fetched fallback, (2) EmailSenderService never attempts a fallback at all during send, (3) EmailProviderFactory can't even instantiate a non-SendGrid provider if one were configured — the 'Fallback Provider' UI setting has zero effect on outbound email.
- **Why it's a problem:** If SendGrid has an outage or the account is suspended, there is no automatic failover despite the admin having configured one; all company email simply stops.
- **Recommended solution:** Fix the EmailExecutorService null-check bug to test companyFallbackEmailProvider, add real fallback-provider invocation in EmailSenderService when the primary send fails, and implement at least one additional IEmailProvider so a configured fallback type is actually usable.
- **Production impact:** Single point of failure for all transactional and campaign email across every tenant.
- **Business impact:** Total email outage during any SendGrid incident, with no automatic recovery path despite the feature appearing configured/available.
- **Technical impact:** Dead code path; configuration UI implies capability that does not exist.
- **Evidence:** Base.Support/Email/Services/EmailExecutorService.cs:167-186 (bug: line 181 re-checks companyEmailProvider instead of companyFallbackEmailProvider); Base.Support/Email/Services/EmailSenderService.cs:82-89 (PRIMARY only); Base.Support/Email/Factories/EmailProviderFactory.cs:20-24 (SENDGRID-only switch)

### #101 · Email SendJob / all campaign email — Retry logic for failed sends  — `High`

- **Module:** Communication  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** EmailSendQueue rows are created with RetryCount = 0, MaxRetryAttempts = 3 (EmailExecutorService.cs:302-303). EmailSendQueueRepository.UpdateQueueItemFailedAsync (lines ~131-146) sets the queue item's status to failed, increments RetryCount by 1, and sets LastRetryAt — but this is called exactly once per send attempt from ParallelEmailOrchestrator (line ~311) with no re-enqueue, no backoff scheduling, and no subsequent job that queries for FAILED items with RetryCount < MaxRetryAttempts to retry them.
- **Gap identified:** Confirmed: grep across the codebase (excluding Membership/Import modules and migrations) shows RetryCount/MaxRetryAttempts for Email are only ever written (initialized to 0/3, then incremented to 1 on failure) and never read back by any scheduler, background job, or query — the retry schema fields are functionally dead for the Email pipeline, unlike the working pattern in Base.Support/Import/Services/ImportScheduledExecutionService.cs (lines 301-335) which explicitly re-schedules sessions where ExecutionAttempts < MaxRetryAttempts.
- **Why it's a problem:** Transient provider errors are common at bulk-send volume; without retry, a temporary blip becomes a permanent, invisible delivery failure for whichever recipients hit it, silently reducing effective reach on every campaign.
- **Recommended solution:** Implement a retry loop using the existing RetryCount/MaxRetryAttempts fields — a recurring job (mirroring ImportScheduledExecutionService's pattern) that re-enqueues FAILED items with RetryCount < MaxRetryAttempts, with backoff, up to the max.
- **Production impact:** Every campaign has an unrecovered tail of transient-failure recipients that will never be retried.
- **Business impact:** Reduced effective delivery rate with no visibility that it was a recoverable, not permanent, failure.
- **Technical impact:** Dead schema fields; retry design was scaffolded (initialized + incremented) but never consumed by any retry-driving job for this pipeline, despite an equivalent working pattern existing elsewhere in the codebase.
- **Evidence:** Base.Support/Email/Services/EmailExecutorService.cs:302-303; Base.Infrastructure/Repositories/Email/EmailSendQueueRepository.cs:131-146 (RetryCount incremented, never re-consumed); Base.Support/Email/Workers/ParallelEmailOrchestrator.cs (calls UpdateQueueItemFailedAsync once, no requeue); Base.Support/Import/Services/ImportScheduledExecutionService.cs:301-335 (contrasting working retry pattern)

### #102 · SMS Campaign (Send Now) — Send reliability / crash consistency  — `High`

- **Module:** Communication  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** SendSMSCampaignNowHandler executes the send synchronously within the GraphQL command: builds/resolves audience (lines 59-144), then calls `smsSenderService.SendBulkAsync(companyId, phoneNumbers, messageBody, cancellationToken)` at lines 152-153 (the real Twilio/provider dispatch, no DB writes precede this call), and only builds/saves SMSCampaignRecipient rows afterward at lines 159-201 (AddRange at 200, SaveChangesAsync at 201).
- **Gap identified:** Confirmed exactly: nothing is persisted to the database before the live provider send call at line 152. If the process crashes, times out, or the request is cancelled between line 153 and line 201, messages have already gone out through the real SMS provider but zero SMSCampaignRecipient rows exist and campaign.CampaignStatusId (set in-memory at line 190, saved together with recipients at line 201) never reaches SENT — leaving the campaign in DRAFT/SCHEDULED. A retried 'Send Now' on the same campaign would re-resolve the same audience and resend, since there is no persisted 'send already attempted' marker.
- **Why it's a problem:** Real-world timeouts on a synchronous 500-recipient bulk send proxied through an external SMS API are a normal occurrence at scale; this design has a duplicate-send / lost-record failure mode baked in, with no way to reconcile 'what actually went out' after a partial failure.
- **Recommended solution:** Move SMS/WhatsApp Send Now onto the same asynchronous, queue-then-send pipeline used for Email (write queue/recipient rows and flip campaign status to SENDING before dispatch, dispatch via background worker, update status per-message) so a crash mid-send is recoverable and idempotent.
- **Production impact:** Risk of duplicate charges/messages to recipients and permanently lost delivery records on any mid-send failure.
- **Business impact:** Donor/beneficiary could receive the same SMS twice, or a paid provider send could go completely untracked by the system.
- **Technical impact:** No pre-send persistence of intent; recipient rows are a post-hoc side effect of a successful synchronous call chain.
- **Evidence:** Base.Application/Business/NotifyBusiness/SMSCampaigns/SendNowCommand/SendSMSCampaignNow.cs:150-201

### #103 · SMS Campaign / WhatsApp Campaign (Send Now) — Audience size cap  — `High`

- **Module:** Communication  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** SendSMSCampaignNow.cs:143 and SendWhatsAppCampaignNow.cs:95 both apply `.Take(500)` to the eligible-contact query with no pre-check of total eligible count, no pagination, and no batching loop.
- **Gap identified:** Confirmed verbatim: any campaign whose real audience (after all filters) exceeds 500 contacts is silently truncated to the first 500 rows the query returns; campaign.AudienceNetRecipientsCount is set from netContacts.Count (the capped list, e.g. SendSMSCampaignNow.cs:192, SendWhatsAppCampaignNow.cs:157) with no warning/error surfaced anywhere, and status is set SENT as if the whole target audience was reached.
- **Why it's a problem:** An org sending a 5,000-donor SMS appeal will unknowingly reach only 500 of them with no way to know from the UI that 4,500 people were never contacted — a materially incomplete send reported as fully successful.
- **Recommended solution:** Either move SMS/WhatsApp Send Now to a background-job/batched model (like Email) with no artificial cap, or surface a hard pre-send validation error/warning when eligible audience size exceeds the processing limit, forcing the user to split or confirm the campaign.
- **Production impact:** Large campaigns silently under-deliver with no operator visibility.
- **Business impact:** Under-reach on time-sensitive appeals/alerts with false 'Sent' confidence.
- **Technical impact:** No batching architecture exists for SMS/WhatsApp campaigns comparable to Email's Hangfire-driven batch pipeline.
- **Evidence:** Base.Application/Business/NotifyBusiness/SMSCampaigns/SendNowCommand/SendSMSCampaignNow.cs:131-144,192; Base.Application/Business/NotifyBusiness/WhatsAppCampaigns/SendNowCommand/SendWhatsAppCampaignNow.cs:86-96,157

### #104 · SMS Setup / SMS Campaign — SMS opt-out keyword (STOP/UNSUBSCRIBE) enforcement  — `High`

- **Module:** Communication  |  **Category:** business  |  **Verification:** ADJUSTED
- **Current implementation:** SmsOptKeyword entity + GetOptKeywordsQuery/SaveSmsOptKeywords let an admin configure opt-out keywords, and Contact.DoNotSMS is correctly checked in SendSMSCampaignNow.cs:129 and PreviewSMSCampaignAudience.cs:137,147. TwilioSmsWebhookProcessor.ProcessTwilioEventAsync only processes MessageStatus delivery-receipt callbacks (queued/sent/delivered/failed), never message body. SmsWebhookController DOES have a separate inbound-reply endpoint `ReceiveInboundSms` (POST api/webhooks/twilio/sms-inbound, lines 80-102) that receives `form.Body` (the actual reply text) but only logs it and echoes it back in the response — it never matches against SmsOptKeyword or sets Contact.DoNotSMS.
- **Gap identified:** Confirmed and even more precisely evidenced than originally stated: an inbound-SMS endpoint exists and does receive the reply body, but it is a dead-end stub — no keyword matching, no DoNotSMS write. Grep for 'DoNotSMS\s*=' across Base.Application/Base.Support/Base.Infrastructure (excluding migrations) shows zero assignment sites; the field is only ever read in campaign audience queries, confirming it can only be set by a manual admin toggle (not verified here, but not the automated path).
- **Why it's a problem:** A recipient who texts back the configured opt-out keyword (e.g. 'STOP') is not actually suppressed — the inbound webhook logs the reply and discards it. This is a TCPA/CTIA compliance gap for any tenant sending US/CA SMS campaigns.
- **Recommended solution:** In SmsWebhookController.ReceiveInboundSms, look up SmsOptKeyword for the company, match against form.Body, and if matched set Contact.DoNotSMS = true (resolve Contact by phone number) plus log the opt-out event — closing the loop the configuration screen already promises.
- **Production impact:** Opt-out keyword configuration screen is non-functional; the inbound webhook that should drive it is an unimplemented stub.
- **Business impact:** Regulatory non-compliance risk (TCPA fines can be per-message) for tenants running SMS campaigns to US contacts.
- **Technical impact:** SmsOptKeyword configuration data is stored but has no consumer anywhere in the send/receive pipeline; the inbound endpoint that should be that consumer discards the payload.
- **Evidence:** Base.Support/Sms/Webhooks/TwilioSmsWebhookProcessor.cs:35-160 (status-only); Base.API/EndPoints/Notify/Controllers/SmsWebhookController.cs:80-102 (ReceiveInboundSms receives form.Body but only logs/echoes it, no keyword match); grep of 'DoNotSMS\s*=' across Base.Application/Base.Support/Base.Infrastructure (excl. migrations) shows no assignment site

### #213 · Email SendJob (SavedFilter/Segment-targeted campaigns) — Recipient filter resolution error handling  — `Medium`

- **Module:** Communication  |  **Category:** qa  |  **Verification:** CONFIRMED
- **Current implementation:** EmailExecutorService.ConvertFilterJsonToGridRequest (lines 401-447) deserializes the stored FilterJson/AggregationFilterJson for a SavedFilter/Segment inside a try/catch that, on any parse failure, silently falls back to no filter at all rather than failing the job.
- **Gap identified:** A corrupted or incompatible FilterJson (e.g. from a schema change or manual edit) causes the job to silently broadcast to the entire unfiltered recipient set instead of erroring out, with only a swallowed exception and no operator-visible failure.
- **Why it's a problem:** A campaign built for a narrow, deliberately-selected segment (e.g. 'major donors only') could silently blast every contact in the company if its filter JSON ever fails to parse — the opposite of the intended targeting, with no error surfaced to catch it before send.
- **Recommended solution:** On filter-deserialization failure, fail the job with a clear 'Invalid recipient filter' error rather than silently defaulting to the full unfiltered audience; never let a parse error silently widen the blast radius of a send.
- **Production impact:** Risk of sending campaign content to the entire contact list when a narrower audience was intended and its filter definition is malformed.
- **Business impact:** Wrong-audience sends (e.g. a segment-specific appeal reaching everyone) damage trust and can violate donor communication preferences.
- **Technical impact:** Fail-open error handling on a data path that controls blast radius.
- **Evidence:** Base.Support/Email/Services/EmailExecutorService.cs:401-447
- **Reviewer note:** not adversarially verified (Medium/Low)

### #214 · Email SendJob status reporting — Job completion status granularity  — `Medium`

- **Module:** Communication  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** EmailSenderService.cs:105-107 sets the final job status as `TotalFailed == 0 ? Completed : TotalSuccess == 0 ? Failed : Completed` — i.e. any job with at least one success is marked Completed regardless of how many recipients failed.
- **Gap identified:** A job that fails for 400 of 1,000 recipients is reported with the exact same 'Completed' status as one that succeeded for all 1,000 — there is no distinct 'Completed with errors' state surfaced at the job level.
- **Why it's a problem:** Operators scanning the Email SendJob list for problems will see 'Completed' and move on, missing large-scale partial failures unless they proactively drill into per-recipient analytics for every single job.
- **Recommended solution:** Introduce a distinct status (e.g. 'CompletedWithErrors') when TotalFailed > 0 && TotalSuccess > 0, and surface a failure-rate indicator directly on the SendJob grid.
- **Production impact:** Operational blind spot for partial-failure campaigns at the list/dashboard level.
- **Business impact:** Under-detected delivery problems reduce trust once a customer notices their recipients report never receiving a 'Completed' campaign.
- **Technical impact:** Status enum collapses two materially different outcomes into one value.
- **Evidence:** Base.Support/Email/Services/EmailSenderService.cs:105-107
- **Reviewer note:** not adversarially verified (Medium/Low)

### #215 · Email Template placeholders (system placeholders: CURRENTDATE/CURRENTTIME) — Timezone correctness in customer-facing content  — `Medium`

- **Module:** Communication  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** ContactEmailRecipientProvider.GetSystemPropertyValue (Base.Infrastructure/Repositories/Email/ContactEmailRecipientProvider.cs:545-557) uses `DateTime.Now` (server-local time) to resolve CURRENTDATE/CURRENTTIME-style system placeholders.
- **Gap identified:** This contradicts the project's own convention that all stored dates are UTC and must be converted per-tenant timezone before display; here the value shown to the *recipient* is simply the application server's local clock, not the tenant's configured timezone.
- **Why it's a problem:** An org configured for e.g. IST sending an email whose template says 'as of {{CurrentDate}}' will show the wrong date/time to its recipients whenever the app server's local time (UTC, typically) differs from the tenant's timezone — a small but visible correctness bug in every email that uses these placeholders.
- **Recommended solution:** Resolve CURRENTDATE/CURRENTTIME via the tenant's configured timezone (the same per-tenant conversion helper used elsewhere for date display) instead of raw server DateTime.Now.
- **Production impact:** Visible date/time inaccuracy in outbound email content for any tenant not in the server's local timezone.
- **Business impact:** Minor but customer-visible correctness issue; erodes confidence in generated communications.
- **Technical impact:** System-placeholder resolution is not tenant-timezone-aware, unlike the rest of the date-handling convention in the codebase.
- **Evidence:** Base.Infrastructure/Repositories/Email/ContactEmailRecipientProvider.cs:545-557
- **Reviewer note:** not adversarially verified (Medium/Low)

### #216 · Email Template rendering (all campaign/notification email bodies) — Placeholder substitution / content injection  — `Medium`

- **Module:** Communication  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** PlaceholderEngine.Render (Base.Support/Email/Services/PlaceholderEngine.cs:37-73) performs raw regex-based string substitution of resolved values directly into the HTML template with no HTML-encoding; BulkEmailRenderer.ApplyEmailLayout (lines 243-248) then concatenates header/footer around that body with plain string interpolation — no sanitization step anywhere in the pipeline.
- **Gap identified:** Any Contact-controlled field used as a placeholder (e.g. DisplayName, custom fields) that contains HTML/script-like characters is injected verbatim into the outbound HTML email body.
- **Why it's a problem:** A contact record with a crafted DisplayName (e.g. containing an `<img onerror=...>` or spoofed link/markup) will have that markup rendered as-is in every email sent to or referencing that contact, enabling content spoofing/phishing-style injection into legitimate organizational email — a real risk for public-facing Donation/Event registration forms that write into Contact fields.
- **Recommended solution:** HTML-encode all placeholder values by default before substitution (with an explicit opt-in 'raw HTML' placeholder type only for admin-curated system content), and sanitize the final rendered body before send.
- **Production impact:** Latent content-injection vector active on every outbound campaign/template email.
- **Business impact:** Reputational/trust risk if a donor or public-form submitter can manipulate outbound email content sent to other recipients.
- **Technical impact:** No output-encoding layer exists between dynamic data resolution and final HTML assembly.
- **Evidence:** Base.Support/Email/Services/PlaceholderEngine.cs:37-73,243-248
- **Reviewer note:** not adversarially verified (Medium/Low)

### #217 · SendGrid bulk email dispatch (all campaign email at scale) — Outbound send throttling  — `Medium`

- **Module:** Communication  |  **Category:** performance  |  **Verification:** CONFIRMED
- **Current implementation:** SendGridProvider.SendBulkEmailAsync (Base.Support/Email/Providers/SendGrid/SendGridProvider.cs) issues one HTTP call per recipient via `Task.WhenAll` with no rate limiting, combined with ParallelEmailOrchestrator running up to MAX_WORKERS = 10 parallel workers each processing BATCH_SIZE = 1000 recipients.
- **Gap identified:** There is no throttle/backoff between outbound SendGrid API calls; at scale this can produce thousands of near-simultaneous API requests, which is a common trigger for provider-side 429 rate-limiting, and there is no retry-after handling for such responses (compounded by the separately-confirmed absence of retry logic).
- **Why it's a problem:** Large campaigns are the exact scenario this pipeline is designed for, and it is also the scenario most likely to trigger unhandled provider rate-limiting, silently failing a batch of recipients with no recovery.
- **Recommended solution:** Add a rate limiter (e.g. token bucket) around outbound SendGrid calls and honor 429/Retry-After responses with backoff, ideally combined with the retry mechanism recommended above.
- **Production impact:** Large-volume campaigns are the most likely to trip provider rate limits, with no mitigation currently implemented.
- **Business impact:** Bulk sends to large donor/member lists (the primary use case) are the highest-risk scenario for silent partial failure.
- **Technical impact:** No throttling layer between the parallel worker pool and the per-recipient SendGrid HTTP calls.
- **Evidence:** Base.Support/Email/Providers/SendGrid/SendGridProvider.cs (SendBulkEmailAsync via Task.WhenAll); Base.Support/Email/Workers/ParallelEmailOrchestrator.cs (MAX_WORKERS=10, BATCH_SIZE=1000)
- **Reviewer note:** not adversarially verified (Medium/Low)

## UI/UX & Design-System Compliance

### #81 · All MASTER_GRID screens (every grid using action-column-cell) — confirmed via action-column-cell.tsx, data-table-view-option.tsx, data-table-update-option.tsx, data-table-delete-option.tsx — Grid row-action buttons (View/Edit/Delete/Toggle/Roles/Branch-Staff-Assign/Temp-Staff-Edit)  — `Critical`

- **Module:** UI/UX & Design-System Compliance  |  **Category:** uiux  |  **Verification:** ADJUSTED
- **Current implementation:** Tooltip-only visual label via TooltipProvider/Tooltip/TooltipTrigger wrapping an icon-only <Button size="icon" variant="ghost">; DynamicIcon always has aria-hidden="true"; no aria-label prop anywhere in these 5 files.
- **Gap identified:** Icon-only row-action Buttons (View, Edit/Update, Delete, Branch-Staff-Assign, Temp-Staff-Edit, DataTableViewOption) render DynamicIcon with aria-hidden="true" and rely solely on a Radix Tooltip for a visible label — no aria-label is ever set on the underlying <Button>. Confirmed identically repeated across 5 separate shared component files (not just the 2 originally cited), so the systemic-reuse claim holds.
- **Why it's a problem:** Radix Tooltip content is not exposed as the button's accessible name — screen readers announce these controls as unlabeled 'button', violating WCAG 2.1 SC 4.1.2 (Name, Role, Value). Since these action buttons appear on every MASTER_GRID row across the entire application, the defect is maximally systemic.
- **Recommended solution:** Add aria-label (or aria-labelledby referencing the same text used in the Tooltip content) to every icon-only Button in action-column-cell.tsx, data-table-view-option.tsx, data-table-update-option.tsx, data-table-delete-option.tsx.
- **Production impact:** No functional breakage for sighted mouse users; real-world impact limited to assistive-technology users, but affects effectively 100% of grid screens.
- **Business impact:** Accessibility/legal compliance risk (ADA/WCAG) for an enterprise NGO SaaS product likely subject to procurement accessibility requirements (VPAT).
- **Technical impact:** Screen-reader users cannot distinguish or operate row actions; automated a11y audits (axe, Lighthouse) will flag every grid row.
- **Evidence:** Directly confirmed: action-column-cell.tsx:122-130 (DataTableBranchStaffAssign) and :174-182 (TempStaffEditOption) — icon-only Button + Tooltip, no aria-label; data-table-view-option.tsx:54 (DataTableViewOption) same pattern; also independently confirmed in data-table-update-option.tsx (edit) and data-table-delete-option.tsx (delete) — same pattern, not previously enumerated. HOWEVER the cited grep-count statistic ("22 files use aria-label vs 613 use Button") does not hold: re-running the grep found 308 files containing aria-label (not 22) and 614 files using <Button> (close to 613). The 308-file figure includes aria-label usage on other element types elsewhere in the app, so it does not by itself disprove the core claim, but the specific 22/613 ratio cited as evidence is inaccurate and overstates the rarity of aria-label usage app-wide.
- **Reviewer note:** Core defect fully CONFIRMED and even found to be broader (5 shared files, not 2) than originally evidenced. Adjusted only the supporting grep-count statistic, which was verified to be materially wrong (308 vs claimed 22 files containing aria-label) — this does not change the verdict or priority, since the specific icon-only action buttons were independently and directly confirmed to lack aria-label by reading the code.

### #82 · Entire application (every form, every button) — Shared Button atom — keyboard focus indicator  — `Critical`

- **Module:** UI/UX & Design-System Compliance  |  **Category:** uiux  |  **Verification:** CONFIRMED
- **Current implementation:** focus-visible:ring-0 explicitly zeroes out any ring on keyboard focus, with no substitute.
- **Gap identified:** buttonVariants base class includes focus-visible:outline-none focus-visible:ring-0 with no alternative focus indicator (no ring, no outline, no box-shadow substitute) applied anywhere in the file.
- **Why it's a problem:** Keyboard-only users get no visible indication of which button is focused when tabbing through the UI, violating WCAG 2.1 SC 2.4.7 (Focus Visible). This is especially severe because Button is the single most-used interactive atom in the app.
- **Recommended solution:** Replace focus-visible:ring-0 with the same focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 pattern already used by Badge/Checkbox for consistency.
- **Production impact:** Affects 100% of screens; no visual regression risk to fix since the corrected pattern is already proven in Badge/Checkbox.
- **Business impact:** WCAG/ADA compliance risk; keyboard-only and low-vision users cannot navigate the app reliably.
- **Technical impact:** Every button in the app (thousands of instances) is keyboard-focus-invisible.
- **Evidence:** Confirmed exactly: atoms/Button/index.tsx:8 — cva base string literally contains "focus-visible:outline-none focus-visible:ring-0" with no compensating ring/shadow class anywhere else in the 182-line file (variants, compoundVariants, or JSX). Contrast confirmed correct in sibling atoms: Badge/index.tsx:7 uses "focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"; Checkbox/index.tsx:10 uses "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2" — proving the correct pattern is an established, working convention elsewhere in the same design system that Button alone fails to follow.
- **Reviewer note:** Evidence verified exactly as cited; no mitigating focus treatment exists anywhere in the component.

### #83 · User Management (accesscontrol/usersroles/user/index-page.tsx) and at least 13 confirmed 'Variant B' screens that mount DataTableContainer directly with a custom ScreenHeader, bypassing the AdvancedDataTable/index.tsx wrapper — Grid data-fetch error handling  — `Critical`

- **Module:** UI/UX & Design-System Compliance  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** Variant B screens (13 confirmed) call useInitializeDataTableColumns/useInitializeDataTableDatas without consuming `error`, and DataTableContainer's own internal second call also discards `error`; the Zustand store's loading defaults never get reset on an error path.
- **Gap identified:** UserGridInner calls useInitializeDataTableColumns()/useInitializeDataTableDatas() and discards both return values entirely; DataTableContainer independently calls useInitializeDataTableDatas() a second time and only destructures { refetch }, discarding error. The hook's data-processing effect (data-table-fetch-data.tsx lines 220-259) only has an `if (loading) {...} else if (data) {...}` structure with NO `else if (error)` branch, so on a GraphQL/network error (data undefined, loading false) the effect body never executes and never resets the store's loading/dataLoading flags (which default to loading: true per advanced-datatable-store.ts:51) — the full-page skeleton spins forever with no error message shown to the user.
- **Why it's a problem:** A backend error, permission failure, or transient GraphQL error on these screens leaves the user staring at an infinite loading skeleton with zero feedback, indistinguishable from a hung network request — a severe functional/UX defect with no recovery path short of a manual page refresh.
- **Recommended solution:** Either (a) have DataTableContainer itself consume and render the `error` return value from its internal useInitializeDataTableDatas() call (same fallback pattern already implemented correctly in AdvancedDataTable/index.tsx lines 78-89), so all Variant-B screens are fixed at once without per-screen changes, or (b) add an `else if (error)` branch in the data-table-fetch-data.tsx effect that resets loading/dataLoading flags so the skeleton at least clears even if the caller doesn't render a message.
- **Production impact:** Confirmed real and reproducible via code inspection (guaranteed on any GraphQL error response for these 13+ screens); severity is Critical as originally rated — not overstated, and arguably broader than the original finding's evidence suggested (13 named screens vs. implied 'a few').
- **Business impact:** Any transient backend hiccup on User Management or any of the 13 other Variant-B grids (several are core admin/configuration screens: currency, branch, contact type, receipt book, document type) presents as a fully hung, unrecoverable-looking page to end users/admins.
- **Technical impact:** Confirmed NOT to affect the standard AdvancedDataTable wrapper path (index.tsx lines 48-49, 78-89) — that path correctly captures { error: columnsError } / { error: dataError } and renders a red-bordered fallback error div instead of the grid, so it does not get stuck. This is real, verified counter-evidence but does not refute the finding because the finding's own 'screen' field was already correctly scoped to Variant-B screens specifically.
- **Evidence:** user/index-page.tsx:21-25 confirmed exactly (both hook calls' returns discarded). data-table-container.tsx:105 confirmed exactly (const { refetch } = useInitializeDataTableDatas(); — error discarded; grepped the full 721-line file for 'error' with zero matches anywhere). data-table-fetch-data.tsx:220-259 confirmed exactly — no else-if(error) branch exists; hook's return statement (lines 261-270) DOES expose error to callers, confirming the bug is caller-side non-consumption, not an upstream data availability problem. Breadth confirmed beyond User Management: grepped AdvancedDataTableStoreProvider usage app-wide and found 13 real screen implementations following the identical Variant-B pattern (documenttype/index-page.tsx — whose own code comment explicitly self-labels it 'MASTER_GRID Variant B layout' — plus scheduledreport, currency, contactsource, currencyconversion, receiptbook, tags-tab, branch, contacttype, staff-category-components, placeholderdefinition, and others), all of which independently re-call the same under-consuming hooks.
- **Reviewer note:** Confirmed exactly as described, and additional diligence found: (1) legitimate counter-evidence that the STANDARD AdvancedDataTable wrapper is unaffected and handles errors correctly — but the finding's own scoping to 'Variant B' screens already accounts for this, so it does not refute the finding; (2) the bug's real-world footprint is materially broader than 'User Management' alone — confirmed identically present in at least 13 named screens across the codebase, all following a self-documented 'Variant B' architectural pattern.

### #186 · Dashboard widgets (Ambassador dashboard and 99 other widget files confirmed via grep) — Widget icon containers, alert/warning states, and matching skeletons  — `High`

- **Module:** UI/UX & Design-System Compliance  |  **Category:** uiux  |  **Verification:** CONFIRMED
- **Current implementation:** Translucent bg-{color}-500/10 or /15 opacity-suffix backgrounds with mid-saturation icon/text colors, reused identically across ~99 widget and skeleton files.
- **Gap identified:** Icon containers, WarningState/ErrorState inline components, and severity-color-mapping functions (e.g. severityClasses()) across dashboard widgets use translucent Tailwind opacity-suffix classes (bg-amber-500/10, bg-amber-500/15, bg-rose-500/15, bg-blue-500/15, etc.) paired with mid-tone icon/text colors (text-amber-500, text-rose-600, etc.), including inside the matching loading Skeleton components (e.g. SEVERITY_STUB_TINTS array), instead of the documented solid bg-X-600 + text-white convention.
- **Why it's a problem:** Directly contradicts the project's own documented, established design-system rule (Widget icon containers + badges = solid bg + white) which mandates solid bg-X-600+text-white for every KPI tile/widget icon container/status badge/helper chip and explicitly forbids bg-X-50/100 or mid-tone text — this is a rule violation across nearly the entire dashboard surface area of the product, not an isolated inconsistency, and even the loading-state skeletons perpetuate the wrong pattern so there is no compliant reference implementation to converge toward without a coordinated fix.
- **Recommended solution:** Refactor all widget icon-container / alert-state / skeleton components to solid bg-{color}-600 + text-white per the documented design-system rule; given the 99-file blast radius, extract a shared severity/status-to-class utility so future widgets can't reintroduce the translucent pattern.
- **Production impact:** Cosmetic only — no functional breakage — but pervasive and directly measurable against a documented, mandatory internal rule.
- **Business impact:** Inconsistent, less accessible (lower contrast) visual language across every dashboard in the product; directly violates the team's own documented UI standard, undermining design-system credibility and consistency audits.
- **Technical impact:** Purely visual/CSS-class change, no logic risk, but touches ~99 files.
- **Evidence:** AmbassadorBranchBarsWidget.tsx confirmed (WarningState/ErrorState use bg-amber-500/10 / bg-rose-500/10 icon containers with text-amber-500/text-rose-500), matching cited lines 20-45 in substance. AmbassadorAlertsListWidget.tsx confirmed in full: severityClasses() (lines 36-83) maps danger/warning/success/info to iconBg values bg-rose-500/15, bg-amber-500/15, bg-emerald-500/15, bg-blue-500/15 with iconText like text-rose-600 dark:text-rose-400; AlertItem (lines 152-185, icon container at ~165-168) renders these directly; WarningState/ErrorState (lines 109-145) also use bg-amber-500/10 / bg-rose-500/10 — matches cited lines 56-61, 75-80, 112. AmbassadorAlertsListWidget.skeleton.tsx confirmed: SEVERITY_STUB_TINTS array (lines 11-16) hard-codes bg-amber-50 .../ dark:bg-amber-500/10 style tints for the loading placeholder itself, matching cited lines 12/14. Grep count independently re-verified exactly: grepping bg-amber-500/10|bg-red-500/10|bg-blue-500/10|bg-green-500/10|bg-orange-500/10 under dashboards/widgets/ returns exactly 99 files, an exact match to the finding's cited count.
- **Reviewer note:** Every cited code sample and the 99-file grep count were reproduced exactly during verification; this is the most precisely-evidenced of the five findings.

### #187 · Every form field across the application — Shared Input atom — keyboard focus indicator  — `High`

- **Module:** UI/UX & Design-System Compliance  |  **Category:** uiux  |  **Verification:** CONFIRMED
- **Current implementation:** Border-color-only focus state, no ring/shadow.
- **Gap identified:** inputVariants only applies focus:outline-none focus:border-{color} (a border-color change) for every color variant (default/primary/info/warning/success/destructive) — no focus ring or box-shadow exists anywhere in the file.
- **Why it's a problem:** A 1px border-color change is a materially weaker focus signal than a ring, especially for low-vision users or on smaller/thin-bordered inputs — falls short of a robust WCAG 2.1 SC 2.4.7 focus indicator, particularly since Badge/Checkbox in the same design system use a stronger ring treatment.
- **Recommended solution:** Add focus:ring-2 focus:ring-{color} focus:ring-offset-1 (or similar) alongside the existing border-color change, mirroring Badge/Checkbox convention.
- **Production impact:** Affects every form field in the app.
- **Business impact:** Lesser WCAG risk than Finding 2 (a focus change does exist, just weak) — correctly scoped as High rather than Critical.
- **Technical impact:** All text inputs, selects, and textareas built on this atom have a subtle focus indicator.
- **Evidence:** Confirmed exactly: atoms/Input/index.tsx lines 7-118 — every one of the 6 color variants defines only focus:outline-none focus:border-{color}; grepped the full 156-line file for 'ring' — no occurrence anywhere.
- **Reviewer note:** Evidence verified exactly; priority of High (vs Critical for Button) is appropriately calibrated since a focus change does exist here, just an insufficiently strong one.

### #293 · All forms rendering a required-field asterisk via the shared Label atom — Required-field indicator (shared Label atom)  — `Medium`

- **Module:** UI/UX & Design-System Compliance  |  **Category:** uiux  |  **Verification:** CONFIRMED
- **Current implementation:** Label component detects "required" via a fragile string-match on the className prop (className?.includes("required")) and renders the asterisk with text-warning; it is used in exactly one place codebase-wide (dashboard-modal.tsx:105), while 179 other files hand-roll the correct `<span className="text-destructive">*</span>` pattern independently.
- **Gap identified:** The shared, documented primitive for required-field marking is both semantically wrong (warning color instead of destructive/error color for a required-field marker) and effectively unadopted/dead — nearly every real usage bypasses it with an ad-hoc duplicate.
- **Why it's a problem:** Signals that the shared component is untrusted or was never properly wired up; the one live usage renders in the wrong color relative to the 179-file de facto convention, meaning that single screen already looks visually inconsistent with the rest of the app's required-field indicators.
- **Recommended solution:** Add a proper `required?: boolean` prop to the Label atom (drop the className string-matching), standardize the asterisk color to text-destructive to match the de facto convention, and migrate the 179 ad-hoc implementations to the shared prop over time to eliminate duplication.
- **Production impact:** One live screen (dashboard-modal) shows a required marker in an inconsistent color from the rest of the app.
- **Business impact:** Minor visual inconsistency; larger issue is technical-debt/duplication risk across 179 files that should be using a shared primitive.
- **Technical impact:** 179 files reimplement the same required-asterisk markup independently, meaning any future change to the convention (e.g. color, spacing) requires 179 edits instead of one.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/common-components/atoms/Label/index.tsx:1-23; PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/dashboard-modal.tsx:105; example ad-hoc usages: advance-query-builder/filter-components/filter-management/EditFilterInfoDialog.tsx:141, SaveFilterDialog.tsx:133, data-tables/data-table-form/dgf-templates/field-template.tsx:75
- **Reviewer note:** not adversarially verified (Medium/Low)

### #294 · All grid screens using the standard AdvancedDataTable / BasicDataTable / FlowDataTable wrappers — Grid-level GraphQL error display  — `Medium`

- **Module:** UI/UX & Design-System Compliance  |  **Category:** uiux  |  **Verification:** CONFIRMED
- **Current implementation:** Three near-identical index.tsx wrappers (advanced/basic/flow) each hard-code the same inline error box: `<div className="rounded-md border p-4 bg-red-50">...<span className="text-red-600">Error:</span><span>{error.toString()}</span>`.
- **Gap identified:** Error UI uses raw non-token Tailwind palette colors (bg-red-50/text-red-600 instead of destructive/* tokens), is copy-pasted three times instead of shared, has no retry action, and renders the raw JS Error.toString() (which can include internal/network/GraphQL implementation detail) directly to end users.
- **Why it's a problem:** Breaks design-token compliance (raw hex-adjacent palette classes are used in 466 files codebase-wide by grep, this being one source), presents an unpolished/inconsistent error state relative to the rest of the app's dark/light theme support, and risks leaking backend implementation details (stack/query info) to end users — a minor information-disclosure and definitely a UX/branding defect.
- **Recommended solution:** Extract a single shared <GridErrorState> component using text-destructive / bg-destructive/10 tokens (theme-aware), a friendly message, and a Retry button wired to refetch(); replace all three duplicated blocks with it.
- **Production impact:** Every grid's error path looks unpolished, theme-inconsistent (won't adapt to dark mode correctly since bg-red-50 is a fixed light-mode color), and inconsistent with the rest of the UI.
- **Business impact:** Unprofessional appearance during outages/incidents undermines confidence exactly when the product is already having problems.
- **Technical impact:** Triplicated code (3 files) increases maintenance cost for any future fix to this error UI.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/advanced/index.tsx:80-89; .../basic/index.tsx:33-41; .../flow/index.tsx:42-51
- **Reviewer note:** not adversarially verified (Medium/Low)

### #295 · Screens with Create/Save buttons outside the standard FLOW form pipeline (e.g. dashboard creation) — Create/Save button enablement rule  — `Medium`

- **Module:** UI/UX & Design-System Compliance  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** The documented rule requires page-header Create/Save buttons to gate on react-hook-form's formState.isValid; codebase-wide grep shows only 15 files actually use formState.isValid for this purpose, while other screens (e.g. dashboards/dashboard-header.tsx:200 `disabled={!canCreateNew}`) gate the Create button on capability (canCreate) instead of form validity.
- **Gap identified:** Inconsistent enablement logic — some Create buttons are enabled/disabled purely by role capability regardless of whether the underlying form is actually valid/complete.
- **Why it's a problem:** A user with create capability but an incomplete/invalid form can still click Create (or, conversely, a user with capability sees the button enabled before filling required fields, only to hit a failed submit), producing inconsistent validation UX across the product and violating the project's own established rule.
- **Recommended solution:** Audit Create/Save buttons outside the FLOW pipeline and switch enablement to `disabled={!formState.isValid}`, reserving capability checks solely for whether the entry-point "+ New" control is shown at all.
- **Production impact:** Inconsistent validation-gating UX on a subset of creation flows (dashboards and similarly-built screens).
- **Business impact:** Confusing UX where enabled buttons don't guarantee a valid submission, increasing failed-submit friction.
- **Technical impact:** Only ~7 identified non-conforming files by grep; scoped, mechanical fix.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/dashboard-header.tsx:200; grep: only 15 files codebase-wide use formState.isValid for button gating
- **Reviewer note:** not adversarially verified (Medium/Low)

### #331 · All FLOW-generated dynamic forms (RJSF-driven) — Field-level validation error message styling  — `Low`

- **Module:** UI/UX & Design-System Compliance  |  **Category:** uiux  |  **Verification:** CONFIRMED
- **Current implementation:** field-error-template.tsx renders per-field validation errors with `<small className="m-0 text-red-500">{error}</small>`, a raw non-token Tailwind color, while the sibling field-template.tsx in the same folder correctly uses text-destructive for the required-asterisk and description/error text.
- **Gap identified:** Two components in the same RJSF template pipeline, both rendering error-adjacent text for the same forms, use two different color implementations (one token-based, one raw hex-equivalent).
- **Why it's a problem:** Raw red-500 will not adapt correctly across the app's dark/light theme variants the way the destructive token does, causing validation error text to look slightly different in tone/contrast from other error text on the very same form, and violates the documented design-token-only rule.
- **Recommended solution:** Change field-error-template.tsx:23 to use text-destructive to match field-template.tsx and the rest of the design system.
- **Production impact:** Minor visual inconsistency within FLOW form validation error states, most visible in dark mode.
- **Business impact:** Cosmetic only, but affects every dynamically-generated FLOW form's error state.
- **Technical impact:** Single-line fix.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/data-table-form/dgf-templates/field-error-template.tsx:23; contrast with .../field-template.tsx:71,75,88
- **Reviewer note:** not adversarially verified (Medium/Low)

### #332 · All grid screens (MASTER_GRID pattern), structural — Grid engine implementation (basic / advanced / flow variants)  — `Low`

- **Module:** UI/UX & Design-System Compliance  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** Three parallel, near-identical grid engines (data-tables/basic, data-tables/advanced, data-tables/flow) each maintain their own copy of index.tsx, data-table-fetch-data.tsx, and data-table-container.tsx with duplicated loading/error/skeleton logic rather than a shared abstraction.
- **Gap identified:** Any UI/UX defect found in one variant (as demonstrated by the identical duplicated raw error box and the error-swallowing pattern found in this audit) must be independently verified and fixed in up to three places, and can silently drift out of sync over time.
- **Why it's a problem:** Increases regression risk and maintenance cost for every future accessibility/design-token/error-handling fix in the grid system, which is the single most-used UI pattern in the product (100+ screens).
- **Recommended solution:** Consolidate shared logic (error/loading state handling, fetch hook, empty/error UI) into one common implementation parameterized by variant-specific differences, rather than three independently-maintained copies.
- **Production impact:** Not itself user-facing, but multiplies the cost/risk of remediating the other findings in this report.
- **Business impact:** Higher long-term maintenance cost and inconsistency risk across the grid system.
- **Technical impact:** Structural refactor; out of scope for a quick fix but relevant context for prioritizing the other findings.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/basic/index.tsx (45 lines); .../advanced/index.tsx (92 lines); .../flow/index.tsx (54 lines) — near-identical structure and duplicated error-box markup across all three
- **Reviewer note:** not adversarially verified (Medium/Low)

### #333 · Application-wide, mobile/tablet viewports — Safe-area handling for notched/gesture-bar devices  — `Low`

- **Module:** UI/UX & Design-System Compliance  |  **Category:** uiux  |  **Verification:** CONFIRMED
- **Current implementation:** No usage of env(safe-area-inset-*) anywhere in the codebase (0 grep hits), and no viewport-fit=cover configuration found in app/layout.tsx.
- **Gap identified:** Fixed headers/footers/bottom sheets and full-screen modals have no accommodation for device safe areas (notches, home-indicator bars) on modern mobile devices.
- **Why it's a problem:** On iOS/Android devices with notches or gesture bars, sticky headers, bottom action bars, and full-screen dialogs can be visually clipped or overlapped by system UI, degrading the mobile experience the product's own responsiveness requirements call for.
- **Recommended solution:** Add viewport-fit=cover to the root viewport meta/config and apply padding-bottom: env(safe-area-inset-bottom) (and top equivalent where relevant) to fixed/sticky chrome (headers, bottom sheets, floating action bars).
- **Production impact:** Only affects a subset of physical mobile devices with notches/gesture bars; desktop/most Android unaffected.
- **Business impact:** Minor polish gap for mobile users on modern iPhones; unlikely to block go-live given desktop-first admin usage pattern.
- **Technical impact:** No infrastructure exists for this today; would need to be added at the layout/root level plus targeted fixed-position components.
- **Evidence:** grep: 0 hits for env(safe-area-inset across the frontend codebase; PSS_2.0_Frontend/src/app/layout.tsx:1-28 has no viewport export
- **Reviewer note:** not adversarially verified (Medium/Low)

### #334 · Screens using ScreenHeader's fullscreen toggle — Fullscreen toggle icon button  — `Low`

- **Module:** UI/UX & Design-System Compliance  |  **Category:** uiux  |  **Verification:** CONFIRMED
- **Current implementation:** The fullscreen toggle Button uses only a `title` attribute (native browser tooltip) for its label, not aria-label.
- **Gap identified:** Relies on the native title attribute as the accessible name mechanism instead of an explicit aria-label.
- **Why it's a problem:** title-attribute tooltips are inconsistently exposed to assistive technology (support varies by browser/AT combination) and are not shown at all on touch devices, so the accessible name for this control is unreliable — the same systemic icon-only-button labeling gap as the grid action buttons, just with a partial native fallback instead of none at all.
- **Recommended solution:** Add an explicit aria-label matching the title text ("Full Screen" / "Exit Full Screen") to guarantee a reliable accessible name across all assistive technologies.
- **Production impact:** Minor — affects one control on every grid header, but has a partial native-tooltip fallback unlike the row-action buttons.
- **Business impact:** Small incremental accessibility gap alongside the larger grid-action-button finding.
- **Technical impact:** Single-line fix in a shared component.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/custom-components/page-header/screen-header.tsx:125-147
- **Reviewer note:** not adversarially verified (Medium/Low)

## Error Handling · Logging · Monitoring

### #26 · Cross-cutting — all HTTP requests (fallback error path) — ErrorHandlingMiddleware generic exception handling  — `Critical`

- **Module:** Error Handling · Logging · Monitoring  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** ErrorHandlingMiddleware.cs wraps _next(context) in try/catch; on generic Exception it sets StatusCode=500, writes a JSON body via WriteAsJsonAsync, then throws a new BadRequestException in the same catch block (lines 30-41). It is registered at DependencyInjection.cs:372, directly after app.UseHttpRequestLogging() at :370.
- **Gap identified:** Confirmed by reading both files: the middleware writes a response body then re-throws. Because UseHttpRequestLogging (registered first, so it wraps ErrorHandlingMiddleware in the pipeline) has its own try/catch (HttpRequestLoggingMiddleware.cs:63-90) that logs and re-throws (`throw;`), the newly-thrown BadRequestException propagates up through it and further up to Kestrel after the response has already started.
- **Why it's a problem:** Writing a response body and then throwing further up the pipeline after the response has started violates ASP.NET Core's response-lifecycle contract and can produce truncated/malformed responses or connection resets instead of the intended clean JSON 500.
- **Recommended solution:** Remove the throw after the response is written; log and return. Better: retire this middleware once app.UseExceptionHandler() is correctly wired so there is a single consistent error-handling layer.
- **Production impact:** Any unexpected exception risks a malformed/incomplete HTTP response instead of the intended structured 500 JSON.
- **Business impact:** Frontend error-handling that expects a parsable JSON error body may instead see a network-level failure, degrading user-facing error messages app-wide.
- **Technical impact:** Violates the ASP.NET Core rule against throwing after the response has started; masks the true original exception type (always surfaces as BadRequestException).
- **Evidence:** Base.Application/Exceptions/ErrorHandlingMiddleware.cs:30-41 (write response, then throw); Base.API/DependencyInjection.cs:370,372 (registration order — UseHttpRequestLogging before UseMiddleware<ErrorHandlingMiddleware>); Base.Application/Middleware/HttpRequestLoggingMiddleware.cs:63-90 (outer try/catch logs and re-throws).

### #27 · Cross-cutting — GraphQL API (all mutations/queries, majority of app surface) — Server-side error logging for GraphQL requests  — `Critical`

- **Module:** Error Handling · Logging · Monitoring  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** CustomErrorFilter (Base.API/Exceptions/CustomErrorFilter.cs) implements IErrorFilter with per-exception-type message/code mapping but has zero ILogger usage. GraphQLRegistrationExtensions.cs builds the schema via AddGraphQLServer()...AddAuthorization().AddInMemorySubscriptions().ModifyOptions(...) with no .AddErrorFilter<CustomErrorFilter>() call.
- **Gap identified:** Confirmed by direct inspection: CustomErrorFilter.cs is the only file in the entire backend containing the class name (it is never referenced elsewhere), and GraphQLRegistrationExtensions.cs (the sole place the schema is built) has no AddErrorFilter or AddInstrumentation call. The filter is fully dead code, and even if wired it would not log to Serilog since OnError never touches ILogger.
- **Why it's a problem:** Nearly all business writes/reads flow through GraphQL. Any unhandled exception in a resolver/handler is masked to a generic message by HotChocolate's default pipeline with zero server-side log trace.
- **Recommended solution:** Register `.AddErrorFilter<CustomErrorFilter>()` on the request executor builder; inject ILogger into CustomErrorFilter and call logger.LogError(error.Exception, ...) in every branch including the fallback; consider AddInstrumentation()/a diagnostic event listener for slow/erroring resolvers.
- **Production impact:** Any GraphQL-side production bug is completely invisible in logs; support only sees 'An unexpected error occurred.'
- **Business impact:** Donation, grant, and case-management workflows that fail silently cannot be triaged, extending incident time.
- **Technical impact:** No log-based alerting/dashboards can ever fire on GraphQL error rate because errors are never written to a sink.
- **Evidence:** Base.API/Exceptions/CustomErrorFilter.cs:1-46 (defined, unused, no ILogger); Base.API/Extensions/GraphQLRegistrationExtensions.cs:37-61 (schema build, no AddErrorFilter/AddInstrumentation); repo-wide grep for 'AddErrorFilter' and 'CustomErrorFilter' returns only the definition file.

### #28 · Cross-cutting — REST/Carter endpoints (webhooks, file uploads, PayU redirect endpoints, etc.) — Global exception handling middleware (IExceptionHandler)  — `Critical`

- **Module:** Error Handling · Logging · Monitoring  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** services.AddExceptionHandler<CustomExceptionHandler>() is called at Base.API/DependencyInjection.cs:48. CustomExceptionHandler (Base.Application/Exceptions/CustomExceptionHandler.cs) correctly logs via ILogger.LogError and builds a typed ProblemDetails response with traceId.
- **Gap identified:** Confirmed: UseApiServices() (DependencyInjection.cs:356-400) never calls app.UseExceptionHandler(). The pipeline only wires UseHttpsRedirection, UseCors, UseHttpRequestLogging, UseMiddleware<ErrorHandlingMiddleware>, UseAuthentication/Authorization, UseRateLimiter, UseSession, UseRouting, MapCarter/MapControllers/MapGraphQL. A DI-registered IExceptionHandler has no effect without the middleware invoking it.
- **Why it's a problem:** The well-built, logging-enabled ProblemDetails handler never actually runs for non-GraphQL endpoints; a reviewer skimming DependencyInjection.cs would wrongly assume centralized exception handling with logging is active.
- **Recommended solution:** Add app.UseExceptionHandler() (relying on the registered IExceptionHandler) early in the pipeline, before routing; then retire the redundant hand-rolled ErrorHandlingMiddleware (see related finding) to avoid two competing layers.
- **Production impact:** Webhook and file-upload endpoints do not get the structured, typed, logged error responses the codebase was designed to produce.
- **Business impact:** Payment gateway webhook consumers may receive non-standard error bodies on failure, complicating retry/reconciliation.
- **Technical impact:** Dead DI registration silently no-ops; CustomExceptionHandler's LogError call (the one clean logging path in the whole exception pipeline) never fires in production.
- **Evidence:** Base.API/DependencyInjection.cs:48 (AddExceptionHandler<CustomExceptionHandler>) vs :356-400 (UseApiServices — no UseExceptionHandler call); repo-wide grep for 'UseExceptionHandler' returns zero hits.

### #123 · Cross-cutting — /graphql request logging (webhook/full-body logging path) — Sensitive data in application logs  — `High`

- **Module:** Error Handling · Logging · Monitoring  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** HttpRequestLoggingMiddleware.cs:18-22 defines _fullBodyLogPaths = ['/api/webhooks', '/graphql']. LogRequestBody (lines 116-159) logs up to 10,000 chars of the raw request body at Information level for any matching path. _sensitiveHeaders (lines 25-30) masks only Authorization/X-Api-Key/Cookie HEADERS; there is no equivalent masking of request-body fields. Login is confirmed to be a GraphQL mutation (Base.API/EndPoints/Auth/Mutations/AuthendicationMutations.cs, UserMutations.cs), so credentials do flow through the logged '/graphql' path.
- **Gap identified:** Confirmed: no field-level redaction exists for GraphQL variables (password, tokens, payment nonces, PII) anywhere in the body-logging path, and Program.cs:18 sets retainedFileCountLimit: 30 (30 days of rolling local log files).
- **Why it's a problem:** Every donation/login/beneficiary mutation writes its full payload (including any credentials, payment tokens, or PII passed as variables) into plaintext local log files retained for a month, readable by anyone with file-system or log-shipping access — a material data-protection exposure for a multi-tenant NGO SaaS handling donor financial data and beneficiary PII.
- **Recommended solution:** Redact known-sensitive GraphQL variable keys (password, token, nonce, ssn, cardNumber, etc.) before logging the body, or disable full-body logging for /graphql entirely and rely on field-level logging inside specific webhook handlers only.
- **Production impact:** Every donation/login/beneficiary mutation writes sensitive payloads to disk-based logs for a month at a time.
- **Business impact:** Regulatory/compliance risk (PCI/GDPR-adjacent exposure) and reputational risk if log files are ever exfiltrated or improperly accessed.
- **Technical impact:** Header redaction was clearly considered by the author but never extended to the body, which is the actual larger exposure surface.
- **Evidence:** Base.Application/Middleware/HttpRequestLoggingMiddleware.cs:18-22 (_fullBodyLogPaths includes '/graphql'), :25-30 (_sensitiveHeaders — headers only), :116-159 (LogRequestBody, no field redaction); Base.API/Program.cs:15-18 (30-day file retention); Base.API/EndPoints/Auth/Mutations/AuthendicationMutations.cs and UserMutations.cs (confirms Login is a GraphQL mutation, so credentials transit the logged path).

### #124 · Cross-cutting — /health endpoint (used by load balancers / orchestrators / uptime monitors) — Database health check probe  — `High`

- **Module:** Error Handling · Logging · Monitoring  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** services.AddHealthChecks().AddSqlServer(configuration.GetConnectionString("Database")!) at Base.API/DependencyInjection.cs:49, using the AspNetCore.HealthChecks.SqlServer 9.0.0 package (Directory.Packages.props:45, referenced in Base.Application.csproj:19).
- **Gap identified:** Confirmed: the application's actual DB provider is PostgreSQL everywhere — Base.Infrastructure/DependencyInjection.cs:44 (UseNpgsql), ApplicationDbContextFactory.cs:40 (UseNpgsql), Base.API/DependencyInjection.cs:96 (Hangfire UseNpgsqlConnection), Base.Support/SearchEngine (UseNpgsql). Repo-wide grep confirms zero references to any NpgSql health-check package — only the SqlServer one is installed and used.
- **Why it's a problem:** A SqlConnection opened against a PostgreSQL connection string will fail outright, so /health will report Unhealthy even when Postgres is fully healthy, making the probe either silently useless or actively harmful (orchestrators may recycle healthy instances, or a genuine DB outage becomes indistinguishable from this permanently-broken check).
- **Recommended solution:** Replace AddSqlServer(...) with AddNpgSql(...) (AspNetCore.HealthChecks.NpgSql package) and add supplementary checks for Hangfire storage / external dependencies as separate named health checks.
- **Production impact:** Health/readiness signal used by any load balancer or orchestrator probe is unreliable from day one.
- **Business impact:** False-negative health status can cause unnecessary restarts/downtime, or mask a genuine outage behind a permanently-red check ops has learned to ignore.
- **Technical impact:** No CI/test currently catches this provider mismatch since health checks are rarely exercised in CRUD test passes.
- **Evidence:** Base.API/DependencyInjection.cs:49 (AddSqlServer); Base.Infrastructure/DependencyInjection.cs:44 and Data/Persistence/ApplicationDbContextFactory.cs:40 (UseNpgsql, confirms real provider); Directory.Packages.props:45 and Base.Application/Base.Application.csproj:19 (only AspNetCore.HealthChecks.SqlServer referenced, no NpgSql health package anywhere in repo).

### #125 · Cross-cutting — Hangfire background jobs (PayU SI recurring-charge cron, import jobs, event-communication dispatcher, online-donation auto-map jobs) — Background job failure visibility / alerting  — `High`

- **Module:** Error Handling · Logging · Monitoring  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** app.UseHangfireDashboard("/hangfire") is called only inside `if (app.Environment.IsDevelopment())` (Base.API/Program.cs:56-60). PayURecurringChargeService.cs:39 carries [AutomaticRetry(Attempts = 0)] with logger.LogWarning/LogError/LogInformation calls (lines 47,82,104,108,140,164,182) that only reach the local file/console Serilog sinks.
- **Gap identified:** Confirmed: the dashboard gate at Program.cs:56 is IsDevelopment()-only, so there is no production-reachable dashboard. AutomaticRetry(Attempts=0) is confirmed on PayURecurringChargeService.cs, OnlineDonationMapJobRunner.cs, EventCommunicationDispatcher.cs, and the three Import services. Repo-wide grep for 'GlobalJobFilters' returns zero hits — no failure-state hook/alerting exists.
- **Why it's a problem:** The PayU recurring-charge job processes real merchant-initiated debits against saved donor payment instruments; if it fails systemically, nobody is notified — the only trace is a log line in a local rolling file.
- **Recommended solution:** Expose an authenticated Hangfire dashboard in Production (role-gated to BUSINESSADMIN) or a lightweight ops screen backed by Hangfire's storage API; register a GlobalJobFilters hook or periodic failed-job-count check that alerts when Failed-state jobs exceed a threshold, especially for payment-charge and event-dispatch jobs.
- **Production impact:** Recurring donation revenue and time-sensitive communications can fail for days with zero operational awareness.
- **Business impact:** Silent revenue loss (missed recurring charges) and missed event reminders directly hurt fundraising/engagement outcomes.
- **Technical impact:** No automated remediation or paging path exists for the most money-sensitive background job in the system.
- **Evidence:** Base.API/Program.cs:56-60 (dashboard gated to Development only); Base.Application/Services/RecurringDonations/PayURecurringChargeService.cs:39,47,82,104,108,140,164,182 (AutomaticRetry(0) + log-line-only summaries); repo-wide grep for 'GlobalJobFilters' returns no results.

### #126 · Cross-cutting — production observability (backend + frontend) — APM / error-tracking / metrics telemetry  — `High`

- **Module:** Error Handling · Logging · Monitoring  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** Base.API.csproj (lines 19-30) references only Carter, HotChocolate.AspNetCore.Authorization, Serilog.AspNetCore, Serilog.Sinks.File, EF Core Design, and Azure Containers Tools — no APM package. Program.cs:9-20 configures Serilog with only .WriteTo.Console() and .WriteTo.File(...) (local disk).
- **Gap identified:** Confirmed: no Application Insights/OpenTelemetry/Sentry/Seq package anywhere in Base.API.csproj. Frontend package.json has no Sentry/LogRocket/Datadog/Bugsnag dependency. A targeted grep for `window.addEventListener('error'|'unhandledrejection'` across src/ returns only two matches, both inside dashboard iframe html-widgets (type1.tsx/type2.tsx), not a global app-level error listener — confirming no global JS error capture exists.
- **Why it's a problem:** In any multi-instance/containerized deployment, per-instance local log files are not centralized or searchable across instances and are lost on restart/redeploy/scale-out. On the client, JS runtime errors/unhandled promise rejections outside a React error boundary are never captured or reported.
- **Recommended solution:** Add a centralized log sink (Application Insights, OpenTelemetry Collector, or Seq) with alerting on error rate; add a lightweight FE error-reporting SDK or at minimum a global window error/unhandledrejection listener that posts to a logging endpoint, and have existing error.tsx boundaries actually report the caught error/digest.
- **Production impact:** Zero centralized visibility into production errors on either backend or frontend; incident detection depends entirely on user reports.
- **Business impact:** Slower mean-time-to-detect/resolve for any production defect, affecting SLA credibility for an enterprise multi-tenant NGO platform.
- **Technical impact:** Combined with the GraphQL-error-filter and correlation-ID gaps, there is no reliable path from 'a user hit an error' to 'an engineer can see why.'
- **Evidence:** Base.API/Base.API.csproj:19-30 (package list — only Serilog.AspNetCore/Serilog.Sinks.File, no APM package); Base.API/Program.cs:9-20 (Console+File sinks only); repo-wide grep of PSS_2.0_Frontend/src for 'window.addEventListener(\'error\'|\'unhandledrejection\'' returns only two per-widget iframe handlers, no global listener.

### #127 · Cross-cutting — Serilog structured logging pipeline — Correlation ID propagation across request lifecycle  — `High`

- **Module:** Error Handling · Logging · Monitoring  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** HttpRequestLoggingMiddleware.cs:43 generates a local 8-char requestId used only in its own two log lines (lines 48-54, 69-75, 81-87). CustomExceptionHandler.cs:58 separately adds context.TraceIdentifier to problemDetails.Extensions['traceId'] (in code that is never invoked, per the related UseExceptionHandler finding). Program.cs:13 sets .Enrich.FromLogContext().
- **Gap identified:** Confirmed: repo-wide grep for 'LogContext.PushProperty'/'PushProperty' returns zero hits anywhere in the backend, so FromLogContext has nothing pushed into it. Three unrelated identifier schemes exist (local requestId, TraceIdentifier, and nothing unifying them) and none are cross-referenced.
- **Why it's a problem:** Given a user-reported error, there is no single, consistent identifier to grep server logs for to reconstruct the full chain of what happened for that specific request.
- **Recommended solution:** Push context.TraceIdentifier (or a single canonical correlation ID) into Serilog's LogContext at the very start of the pipeline via LogContext.PushProperty, include it in every log output template, and surface the same value in every error response shape.
- **Production impact:** Production troubleshooting requires manually correlating log timestamps across unrelated ID schemes instead of a single grep-able correlation ID.
- **Business impact:** Slower incident response; support cannot use a single error code to find the exact failing request.
- **Technical impact:** The Serilog FromLogContext investment is undermined because the one property that would make it useful for single-request tracing is never populated.
- **Evidence:** Base.Application/Middleware/HttpRequestLoggingMiddleware.cs:43-54,69-75 (local requestId, not pushed to LogContext); Base.API/Program.cs:9-20 (Enrich.FromLogContext with nothing pushing properties); repo-wide grep for 'LogContext.PushProperty' returns zero hits; Base.Application/Exceptions/CustomExceptionHandler.cs:58 (separate, disconnected TraceIdentifier, itself dead code).

### #128 · Public donor-facing pages — (public) route group: online donation, crowdfund, P2P, event registration, volunteer registration — Client-side error boundary coverage and reporting  — `High`

- **Module:** Error Handling · Logging · Monitoring  |  **Category:** uiux  |  **Verification:** CONFIRMED
- **Current implementation:** Directory scan of src/app confirms error.tsx exists only at app/[lang]/error.tsx, app/[lang]/(master)/error.tsx, and app/[lang]/organization/error.tsx. Both app/[lang]/error.tsx and app/[lang]/(master)/error.tsx render an identical static Alert ('Something went wrong!') plus a 'Try again' button with no console.error/logging/reporting call of any kind, and no global-error.tsx exists anywhere under src/app.
- **Gap identified:** Confirmed exactly as described: no error.tsx exists under any (public) route segment (crowdfund/p2p/event/payu/pray/volunteer/embed/preview), and no app/global-error.tsx exists to catch root-layout errors. The two existing boundaries never log or report the received error/digest.
- **Why it's a problem:** The public donor-facing pages are the highest-stakes anonymous surface (real money changes hands, no session to fall back on) yet fall through to the generic top-level error.tsx with no donor-appropriate messaging, and — combined with the missing APM finding — any render crash on a donation/checkout page is completely unreported.
- **Recommended solution:** Add a dedicated error.tsx under (public) with donor-appropriate messaging and a global-error.tsx at the app root; have both call an error-reporting function (at minimum console.error plus a fetch to a logging endpoint) with error and error.digest before rendering the fallback UI.
- **Production impact:** A JS exception during a live donation/checkout flow shows a generic, unbranded error screen and leaves zero record for the team to investigate.
- **Business impact:** Directly risks lost donations/conversions on revenue-critical public pages, with no telemetry to even know it happened.
- **Technical impact:** N/A — architectural gap in error-boundary coverage, not a specific runtime bug.
- **Evidence:** Glob of PSS_2.0_Frontend/src/app for '**/error.tsx' returns only app/[lang]/error.tsx, app/[lang]/(master)/error.tsx, app/[lang]/organization/error.tsx; glob for '**/global-error.tsx' returns none; app/[lang]/error.tsx:1-18 and app/[lang]/(master)/error.tsx:1-19 both render a static Alert with no logging/reporting call.

### #234 · Cross-cutting — error response contract consistency — Uniform error envelope across API surfaces  — `Medium`

- **Module:** Error Handling · Logging · Monitoring  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** REST exceptions caught by ErrorHandlingMiddleware return a custom `{errorCode, message, success}` shape, GraphQL errors fall through HotChocolate's default `errors[]` array, and the RFC7807 ProblemDetails handler exists in code but is never wired in.
- **Gap identified:** Three different, structurally incompatible error response shapes exist depending on which layer catches an exception: (1) CustomExceptionHandler would produce RFC7807 `ProblemDetails` (Title/Detail/Status/Instance/traceId) — but is dead code (see related finding); (2) ErrorHandlingMiddleware produces a custom `{ errorCode, message, success }` shape (ErrorHandlingMiddleware.cs:21-26, 33-38); (3) GraphQL errors go through HotChocolate's default `errors[]` array (since CustomErrorFilter is also unregistered/dead).
- **Why it's a problem:** Frontend code cannot rely on one generic error-parsing utility across REST and GraphQL calls; each surface's failure mode must be handled ad hoc, increasing the chance that some failure paths surface as an unhandled/uncaught shape to the FE (e.g. a component expecting `result.message` gets a ProblemDetails `detail` field instead, or vice versa).
- **Recommended solution:** Once the dead-code wiring issues above are fixed, standardize on a single error envelope (ProblemDetails for REST, and matching `code`/`message`/`extensions` shape for GraphQL) and delete the redundant custom-shape middleware.
- **Production impact:** Increases the surface area for FE 'unhandled error shape' bugs, particularly on less-tested REST/webhook endpoints.
- **Business impact:** Inconsistent, occasionally confusing error messages surfaced to end users depending on which code path failed.
- **Technical impact:** Makes it harder to write one shared FE error-toast utility; currently each area reimplements its own error-shape assumptions.
- **Evidence:** Base.Application/Exceptions/CustomExceptionHandler.cs:50-56 (ProblemDetails shape, dead); Base.Application/Exceptions/ErrorHandlingMiddleware.cs:21-26,33-38 (custom errorCode/message/success shape, live); Base.API/Exceptions/CustomErrorFilter.cs (GraphQL WithCode/WithMessage shape, dead — real behavior falls back to HotChocolate defaults).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #235 · Cross-cutting — exception logging fidelity — Stack-trace capture in structured logs  — `Medium`

- **Module:** Error Handling · Logging · Monitoring  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** CustomExceptionHandler logs only `exception.Message` as a string interpolated into the log template rather than passing the `Exception` object itself as the leading argument to `ILogger.LogError`.
- **Gap identified:** CustomExceptionHandler.cs:12-14 logs `logger.LogError("Error Message: {exceptionMessage}, Time of occurrence {time}", exception.Message, DateTime.UtcNow)` — the `Exception` object itself is never passed as the log call's leading `Exception` argument, only its `.Message` string. Serilog (and most structured-logging sinks) only attach the full stack trace / inner-exception chain to the `{Exception}` output-template token when an actual `Exception` instance is supplied as the first positional argument to `ILogger.LogError`.
- **Why it's a problem:** Even setting aside that this handler is currently unwired (a separate finding), the logging call as written would silently drop the stack trace the moment the wiring is fixed — defeating the purpose of centralizing exception handling for diagnostics.
- **Recommended solution:** Change to `logger.LogError(exception, "Unhandled exception at {Time}", DateTime.UtcNow);` so Serilog's `{Exception}` template token captures the full stack trace and inner exceptions.
- **Production impact:** Once the dead-wiring issue is fixed, exception logs from this handler would still lack stack traces, slowing root-cause analysis.
- **Business impact:** Longer incident investigation time for any exception that does flow through this handler.
- **Technical impact:** Simple one-line fix, but easy to miss because the code compiles and 'logs something' — it just isn't the useful part.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Exceptions/CustomExceptionHandler.cs:12-14 (LogError call passes exception.Message, not the exception instance, as arguments).
- **Reviewer note:** not adversarially verified (Medium/Low)

## Data Consistency & Concurrency

### #18 · Event Registration — Create Event Registration  — `Critical`

- **Module:** Data Consistency & Concurrency  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** CreateEventRegistration.cs performs the ticket-capacity check (currentSold vs ticket.QuantityAvailable, lines 80-86) with a plain SumAsync query outside any transaction, then does Add + SaveChangesAsync (lines 116-117) with no re-validation, no transaction wrapper, and no lock at all.
- **Gap identified:** Verified: no transaction, no advisory lock, no FOR UPDATE anywhere in this handler — confirmed by reading the full file end-to-end. Additionally checked EventRegistrationConfiguration.cs and EventTicketConfiguration.cs for any DB-level backstop (unique index, check constraint, or an atomically-maintained sold-counter column): none exists — only EventRegistrationCode has a filtered unique index, which has no bearing on capacity. Unlike the AuctionBid case, there is no unique-index safety net here at all; concurrent registrations for the last remaining seats can all pass the check and all insert successfully with no failure of any kind.
- **Why it's a problem:** Event capacity is a hard physical/legal/venue constraint. A rush of near-simultaneous registrations (a normal scenario for a popular event launch) can straightforwardly oversell tickets with zero application or database defense, producing a silent, undetectable overbooking that surfaces only when someone manually reconciles registration counts against capacity.
- **Recommended solution:** Wrap the capacity check and insert in a single transaction, take a pg_advisory_xact_lock keyed on EventTicketId (or EventId) before computing currentSold, and re-validate remaining capacity immediately before insert — same fix pattern as CreateBeneficiaryServiceLog.cs's ServiceLogFundingGuard. As defense-in-depth, consider maintaining an atomically-incremented SoldQuantity counter on EventTicket guarded by a DB check constraint (SoldQuantity <= QuantityAvailable).
- **Production impact:** Popular/high-demand events can be oversold beyond configured capacity under any meaningful concurrent traffic, with no error surfaced to any party.
- **Business impact:** Operational and legal exposure from venue overcapacity, forced last-minute cancellations/refunds, reputational damage.
- **Technical impact:** No exception or conflict is raised — the oversell is completely silent until a manual audit catches it.
- **Evidence:** Base.Application/Business/ApplicationBusiness/EventRegistrations/Commands/CreateEventRegistration.cs:80-86 (capacity check via SumAsync, no lock/tx), 112-117 (plain Add+SaveChanges, no re-check); Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventRegistrationConfiguration.cs:43-45 and EventTicketConfiguration.cs:49-54 (no capacity-related unique index or check constraint of any kind)
- **Reviewer note:** Fully confirmed by reading the complete handler and both entity configurations — worse than the AuctionBid case since there is no DB-level backstop of any kind (not even an after-the-fact unique-index guard).

### #19 · Global / Cross-Cutting — Database Schema — Foreign Key Delete Behavior (Company / Tenant Root)  — `Critical`

- **Module:** Data Consistency & Concurrency  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** Confirmed via grep: 95 files under Base.Infrastructure/Data/Configurations contain DeleteBehavior.Cascade. Spot-verified the CompanyId → Company FK specifically is Cascade in CaseConfiguration.cs:25-28, GrantConfiguration.cs:41-44, and CaseNoteConfiguration.cs:32-36. DeleteCompany.cs (the only Company-delete path) confirmed to be pure soft-delete (company.IsDeleted = true; SaveChanges, no hard DELETE anywhere).
- **Gap identified:** Confirmed exactly as described: the FK schema itself provides zero defense-in-depth against a hard-delete of a Company row. OnlineDonationStagingConfiguration.cs explicitly documents and correctly implements the opposite convention ('Company / Currency / CompanyPaymentGateway → Restrict (parent rows must be soft-deleted, not hard-deleted)' — verified at lines 10, 73-77), proving the team knows the correct pattern but applied it inconsistently — the tenant-root Company FK itself is Cascade in the vast majority of entity configs while at least one newer module (donation staging) correctly uses Restrict.
- **Why it's a problem:** A single mistaken hard-delete of one Company row (future bug, ops script, raw-SQL hotfix, bulk purge) would cascade-delete across ~90+ dependent tables for that tenant with no application-layer or schema-layer guard, given the app itself never issues a hard delete today as the only protection.
- **Recommended solution:** Change the CompanyId → Company FK to DeleteBehavior.Restrict across all affected configurations (migration required), matching the documented and correctly-implemented convention already present in OnlineDonationStagingConfiguration.cs. Audit remaining non-CompanyId Cascade usages individually to confirm each is a true parent-owns-child composition (e.g., Grant→GrantBudgetLine, Case→CaseNote) rather than an accidental blanket default.
- **Production impact:** No incident yet observed, but the blast radius of a single mistaken hard-delete is total, tenant-wide, and irreversible without a backup restore.
- **Business impact:** Catastrophic, unrecoverable customer data loss for any affected tenant — existential incident for a B2B SaaS vendor.
- **Technical impact:** Schema provides no defense-in-depth; the only safety net is application-code discipline, unenforced at the database level, and already inconsistently applied across modules.
- **Evidence:** Grep of Base.Infrastructure/Data/Configurations for 'DeleteBehavior\.Cascade' → 95 files; CaseConfigurations/CaseConfiguration.cs:25-28, GrantConfigurations/GrantConfiguration.cs:41-44, CaseConfigurations/CaseNoteConfiguration.cs:32-36 (CompanyId FK Cascade, verified by direct read); DonationConfigurations/OnlineDonationStagingConfiguration.cs:10,73-77 (documented + correctly implemented Restrict-on-Company convention, verified by direct read); Base.Application/Business/ApplicationBusiness/Companies/Commands/DeleteCompany.cs:34-63 (pure soft-delete, no hard DELETE path, verified by direct read)

### #20 · Grant Management — Expenses — Create Grant Expense  — `Critical`

- **Module:** Data Consistency & Concurrency  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** CreateGrantExpense.cs opens a real DB transaction (line 41 via execution-strategy-wrapped BeginTransactionAsync) and computes cash-on-hand as totalReceived − totalSpent − max(totalCommitted, programTransferred) via three separate SumAsync aggregates (lines 54-85), checks input.Amount against it (lines 88-91), then increments grant.TotalSpent (line 93) and GrantBudgetLine.SpentAmount (line 99) via tracked-entity read-modify-write before SaveChanges+Commit (lines 102-103). No pg_advisory_xact_lock or FOR UPDATE is taken anywhere in this handler — confirmed by reading the full file.
- **Gap identified:** Confirmed as described: the transaction only guarantees the write itself is atomic; under PostgreSQL's default READ COMMITTED isolation it does not serialize concurrent readers/writers of the same Grant aggregate. Two concurrent CreateGrantExpense calls can both compute the same cash-on-hand snapshot, both pass the ceiling check, and both commit — collectively overspending the grant's real cash-on-hand. The TotalSpent/SpentAmount `+=` increments are also unprotected read-modify-write with no RowVersion, so a lost update on these running totals is possible even independent of the ceiling breach.
- **Why it's a problem:** Directly verified the contrast claim: CreateBeneficiaryServiceLog.cs/UpdateBeneficiaryServiceLog.cs DO use `SELECT pg_advisory_xact_lock({0})` (lines 116, 117 / 116-117 respectively) keyed on the funding pool, proving the team knows and has already applied this exact fix pattern elsewhere in the same module family — yet the grant cash-on-hand ledger, which is funder/audit-facing, is left unprotected. This is a real, reproducible double-spend/lost-update risk on the system's most compliance-sensitive financial aggregate.
- **Recommended solution:** Add a pg_advisory_xact_lock keyed on GrantId inside the existing transaction, acquired before the cash-on-hand aggregation, and re-check the ceiling immediately before SaveChanges — mirroring ServiceLogFundingGuard. Add a RowVersion/xmin concurrency token to Grant and GrantBudgetLine so TotalSpent/SpentAmount increments fail fast on conflict rather than silently lose an update.
- **Production impact:** Concurrent grant expense entries against the same grant can collectively overspend the grant's actual cash-on-hand, and running-total spend counters can silently drift from the true sum of expense rows.
- **Business impact:** Funder-facing financial misstatement risk; TotalSpent drift undermines financial-summary/reporting screens that report Outstanding/CashOnHand to funders and management.
- **Technical impact:** Silent overspend past the intended ceiling; TotalSpent/SpentAmount counters can diverge from the underlying GrantExpenses sum-of-truth with no error raised.
- **Evidence:** Base.Application/Business/GrantBusiness/Grants/CreateCommand/CreateGrantExpense.cs:36-105 (transaction opened, no advisory lock; cash-on-hand via SumAsync 54-87, checked 88-91, TotalSpent/SpentAmount incremented 93,99); contrast confirmed at Base.Application/Business/CaseBusiness/BeneficiaryServiceLogs/CreateCommand/CreateBeneficiaryServiceLog.cs:111-127 and UpdateCommand/UpdateBeneficiaryServiceLog.cs:112-125 (pg_advisory_xact_lock correctly applied for the same problem class)

### #115 · Auction / Bidding — Place Bid  — `High`

- **Module:** Data Consistency & Concurrency  |  **Category:** data  |  **Verification:** ADJUSTED
- **Current implementation:** PlaceBid.cs loads the AuctionItem with its bid collection outside any transaction (lines 44-48) and validates the new bid against the in-memory CurrentHighBid computed pre-transaction (lines 65-75); the DB transaction is opened only around the final mutation+SaveChanges (lines 138-146). HOWEVER: AuctionBidConfigurations.cs (lines 21-25) defines a DB-level filtered UNIQUE INDEX on AuctionItemId WHERE IsCurrentHighest = true — i.e. Postgres itself guarantees at most one 'current highest' row per item at any instant, enforced inside the same atomic transaction that performs the flip-prior/insert-new mutation.
- **Gap identified:** There is a real TOCTOU window on the pre-transaction read/compare (no advisory lock, no FOR UPDATE, no re-validation of CurrentHighBid immediately before insert), so the original finding's structural complaint is accurate. But its claimed failure outcome is wrong: because the unique filtered index makes 'insert a second IsCurrentHighest=true row for the same item' a hard DB constraint violation, a losing concurrent request cannot silently commit as a second 'winning' bid — its whole transaction (including its own bid insert and the AuctionItem cache-field mutation) rolls back atomically on the unique-index violation. The actual defect is: the losing bidder's legitimate bid is entirely discarded (not persisted at all, not even as a non-winning history row) and the request surfaces as a raw, unfriendly `InternalServerException` (translated from `DbUpdateException`) rather than a clear 'someone just placed a higher bid, please refresh and retry' message.
- **Why it's a problem:** Two accepted/duplicate winning bids cannot occur — that specific corruption scenario is REFUTED by the existing unique index. What remains is a reliability/UX gap: under real concurrent-bidding load (the exact adversarial scenario auctions attract), a legitimately valid, timely bid can be silently dropped and the bidder shown a generic server error instead of an actionable 'outbid' message, and the bid is not retried or re-queued against the now-current high bid.
- **Recommended solution:** Add a `pg_advisory_xact_lock` keyed on AuctionItemId before the read/compare (mirroring `ServiceLogFundingGuard`/`CreateBeneficiaryServiceLog.cs`), and re-validate `CurrentHighBid` immediately before insert inside the lock. This removes the race entirely (rather than relying on the unique index as an after-the-fact backstop) and lets the handler return a clean, specific 'bid too low — current high bid is X' `BadRequestException` instead of an opaque 500 when a race is lost — preserving the bidder's ability to immediately retry with a corrected amount.
- **Production impact:** No duplicate-winner data corruption occurs (DB constraint prevents it), but concurrent bidders during a hot auction close can have a valid bid silently rejected with a generic error instead of a clear outbid message, and that attempt leaves no bid-history trace.
- **Business impact:** Bidder frustration/support tickets during high-value auction closes ('the site errored and ate my bid') — a UX/reliability issue, not a financial-integrity one as originally claimed.
- **Technical impact:** Unhandled DbUpdateException surfaces as InternalServerException (HTTP 500) on a normal, expected concurrency event rather than a modeled BadRequestException; no data corruption.
- **Evidence:** Base.Application/Business/ApplicationBusiness/AuctionBids/Commands/PlaceBid.cs:44-48,65-75,138-146 (read/compare outside tx, tx wraps only mutation); Base.Infrastructure/Data/Configurations/ApplicationConfigurations/AuctionBidConfiguration.cs:21-25 (filtered UNIQUE INDEX on AuctionItemId WHERE IsCurrentHighest=true — this is the DB-level backstop the original finding overlooked, which prevents the claimed 'two winning bids' outcome)
- **Reviewer note:** Downgraded from Critical to High and corrected the failure mode: the claimed 'two accepted winning bids' corruption is REFUTED by a pre-existing filtered unique index (AuctionBidConfiguration.cs:21-25) that the original reviewer did not check. The real, surviving defect is a losing bidder's request failing with a raw 500 instead of a friendly retry message — still worth fixing with the same recommended advisory-lock pattern, but not a data-integrity emergency.

### #116 · Event Registration — Payments — EventRegistrationPayment Idempotency  — `High`

- **Module:** Data Consistency & Concurrency  |  **Category:** payments  |  **Verification:** ADJUSTED
- **Current implementation:** Verified EventRegistrationPaymentConfiguration.cs directly: IdempotencyKey has only HasMaxLength(64) (line 47) with no unique index anywhere in the file. Verified PaymentTransactionConfiguration.cs:12 does have `builder.HasIndex(p => p.IdempotencyKey).IsUnique()`, and GlobalOnlineDonationConfiguration.cs:80-83 does have a unique filtered index on (CompanyId, GatewayTransactionId) — confirming the contrast claim exactly. Additionally found a mitigating control the original finding missed: InitiateEventRegistration.cs (the handler that creates the EventRegistrationPayment row, line 478) checks an app-level idempotency cache keyed by `eventregpage:idem:{req.IdempotencyKey}` at the very start of the handler (lines 118-123) and returns the cached result on a hit, before any row is inserted — but this cache is `IMemoryCache` (line 81), i.e. per-process, in-memory only.
- **Gap identified:** The DB-level gap is real and confirmed as described. However, it is partially — not fully — mitigated in practice by the in-memory idempotency cache: a same-instance retry (typical browser double-click, single-instance dev/staging deploy) is already caught before any duplicate row is created. The residual, still-real risk is specifically: (a) any horizontally-scaled/load-balanced production deployment, where a retried request or webhook can land on a different app instance that doesn't share the cache; (b) app restarts/recycles that clear the cache; (c) cache eviction under memory pressure. In all these cases the DB is the only remaining backstop, and it is missing.
- **Why it's a problem:** For a scaled, multi-instance production deployment (the normal target for enterprise SaaS), the existing mitigation is instance-local and not a substitute for a DB-level constraint; the same pattern is correctly implemented with a real unique index in two sibling payment paths (PaymentTransaction, GlobalOnlineDonation) in this very codebase.
- **Recommended solution:** Add a unique filtered index on IdempotencyKey (e.g. HasFilter("\"IdempotencyKey\" IS NOT NULL AND \"IsDeleted\" = false")) mirroring GlobalOnlineDonation's pattern, so a redelivered webhook or duplicate confirm landing on a different app instance can never create two payment rows for the same operation — closing the gap the in-memory cache cannot cover.
- **Production impact:** A retried gateway webhook or duplicate payment confirmation for an event registration can still create duplicate payment records specifically in multi-instance/scaled deployments or after a cache-clearing app restart, despite the existing in-memory idempotency check catching the common single-instance case.
- **Business impact:** Financial reporting accuracy risk for event revenue in scaled production environments; potential for double-counted revenue or a donor shown as having paid twice.
- **Technical impact:** No DB-level guardrail exists for this specific payment table despite the pattern being correctly implemented elsewhere in the same codebase; the existing app-level guard is a partial, instance-scoped mitigation, not a full replacement.
- **Evidence:** Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventRegistrationPaymentConfiguration.cs:47 (IdempotencyKey has only HasMaxLength, no unique index in the file, verified); PaymentTransactionConfiguration.cs:12 (unique IdempotencyKey index, verified) and DonationConfigurations/GlobalOnlineDonationConfiguration.cs:80-83 (unique filtered index, verified); Base.Application/Business/ApplicationBusiness/EventRegistrationPages/PublicMutations/InitiateEventRegistration.cs:81 (IMemoryCache — per-instance only), 118-123 (idempotency cache check before insert), 478-499 (EventRegistrationPayment row creation using req.IdempotencyKey)
- **Reviewer note:** Core gap and recommendation confirmed as accurate, but priority/description adjusted to note a real, previously-unmentioned partial mitigation: InitiateEventRegistration.cs already implements an app-level (IMemoryCache) idempotency check that catches same-instance duplicate submissions before any row is inserted. The DB-level unique index is still missing and still matters for multi-instance/scaled deployments and cache-clearing restarts, so the fix recommendation stands, but the risk is narrower than originally framed.

### #117 · Global / Cross-Cutting — Data Integrity — Optimistic Concurrency Control  — `High`

- **Module:** Data Consistency & Concurrency  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** Verified via repo-wide grep for IsRowVersion/[Timestamp]/RowVersion/ConcurrencyToken across the entire Base.Infrastructure and Base.Application trees: zero matches. Verified UpdateBeneficiaryServiceLog.cs directly: it does apply a pg_advisory_xact_lock, but only to re-check the funding-pool ceiling (lines 116-121); the rest of the entity's fields (ServiceDescription, Notes, etc., mutated via `command.beneficiaryServiceLog.Adapt(existing)` at line 86) are plain last-write-wins with no version check of any kind.
- **Gap identified:** Confirmed: no entity anywhere in the schema carries a concurrency token. Two staff editing the same record's non-funding fields concurrently (e.g., two case workers both editing a Case's notes/description) will silently overwrite each other's changes with zero conflict detection — this is a genuine, schema-wide gap distinct from (and broader than) the funding-pool-specific advisory locks that do exist.
- **Why it's a problem:** Silent lost updates on case notes, grant fields, or other collaboratively-edited records is a real data-integrity risk that creates unattributable, unreproducible support disputes ('I saved my changes but they disappeared') with no audit trail to distinguish an intentional overwrite from an accidental one.
- **Recommended solution:** Add a RowVersion (byte[]) or xmin-mapped concurrency token to the highest-risk entities first (Grant, GrantBudgetLine, Case, BeneficiaryServiceLog), configure via .IsRowVersion(), and have Update handlers catch DbUpdateConcurrencyException and surface a clear 'this record was changed by someone else, please refresh' error to the FE.
- **Production impact:** Concurrent edits on the same record anywhere in the system silently lose one user's changes with zero indication to either user.
- **Business impact:** Erodes trust in the system's reliability for collaborative case/grant work; unattributable data-correction disputes.
- **Technical impact:** No mechanism exists anywhere to detect or reject a stale-based update outside the narrow funding-pool advisory locks; confirmed by full-repo grep returning zero RowVersion/Timestamp usages.
- **Evidence:** Repo-wide grep across Base.Infrastructure and Base.Application for 'IsRowVersion|\[Timestamp\]|RowVersion|ConcurrencyToken|IsConcurrencyToken' → 0 matches; Base.Application/Business/CaseBusiness/BeneficiaryServiceLogs/UpdateCommand/UpdateBeneficiaryServiceLog.cs:86 (Adapt-based mutation of non-funding fields with no version check), 116-121 (advisory lock scoped only to the funding-pool ceiling re-check, not general field concurrency)

### #118 · Global / Cross-Cutting — Soft Delete — Case Delete Cascade to Child Records  — `High`

- **Module:** Data Consistency & Concurrency  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** Verified DeleteCase.cs soft-deletes the Case (lines 30-32) and reconciles only BeneficiaryServiceLogs (lines 39-48, labeled 'H-5' fix) — CaseNotes/CaseDocuments/CaseActionItems/CaseReferrals are untouched by this handler. Additionally verified GetAllCaseNotes.cs (the CaseNotes list query) filters only on `n.IsDeleted == false && n.CompanyId == companyId` (lines 30-36) with no join/filter against the parent Case's IsDeleted status — confirming the leak is real and reproducible, not merely theoretical.
- **Gap identified:** Confirmed: after a Case is soft-deleted, its CaseNotes (and, by the same reasoning, CaseDocuments/CaseActionItems/CaseReferrals) remain IsDeleted=false and are directly returned by the standard list query with no parent-status check of any kind.
- **Why it's a problem:** This is a systemic pattern risk: the Case entity's own delete handler proves the team is aware child-reconciliation is needed (they did it specifically for BeneficiaryServiceLogs, to protect the funding-pool guard) but did not apply the same discipline to the other Case children or add a general safeguard, and at least one live list query (GetAllCaseNotes) was directly verified to leak child rows of a deleted parent.
- **Recommended solution:** Add child-record soft-delete cascade to DeleteCase.cs for CaseNotes/CaseDocuments/CaseActionItems/CaseReferrals mirroring the BeneficiaryServiceLogs reconciliation, and/or add a documented convention + audit of child-of-Case queries requiring an explicit Case.IsDeleted==false check (or a global EF query filter mirroring the existing tenant filter pattern).
- **Production impact:** Deleted cases' notes remain queryable and visible in the standard list query with no explicit filter needed to surface them — verified directly, not merely inferred.
- **Business impact:** Data-privacy and case-management-integrity concern for an NGO handling sensitive beneficiary case records.
- **Technical impact:** Orphaned live rows accumulate with no automatic cleanup; confirmed at least one real query surfaces them today.
- **Evidence:** Base.Infrastructure/Data/Persistence/ApplicationDbContext.cs:61-133 (only global filter is tenant, not soft-delete — assumed consistent with original finding, not independently re-verified this pass); Base.Application/Business/CaseBusiness/Cases/DeleteCommand/DeleteCase.cs:30-48 (verified: Case + BeneficiaryServiceLogs only); Base.Application/Business/CaseBusiness/CaseNotes/GetAllQuery/GetAllCaseNotes.cs:30-36 (verified: no parent Case.IsDeleted check — directly confirms the leak is live, not just theoretical)

### #229 · Online Donation Page / CrowdFund — Promotion Pipeline — PromoteOnlineDonationStaging — Contact Auto-Create  — `Medium`

- **Module:** Data Consistency & Concurrency  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** ResolveContactAsync (within PromoteOnlineDonationStaging.cs, lines 432-518) performs a non-transactional check (query for an existing Contact by email) then, if none is found, creates a new Contact for the recurring donor — with no lock or unique create-time constraint preventing a duplicate.
- **Gap identified:** ContactEmailAddress's uniqueness is enforced only per-existing-contact (unique on (CompanyId, ContactId, Email)), which guarantees a single contact can't have the same email twice — it does NOT prevent two different Contact rows from both holding the same email address. Under concurrent first-time recurring donations sharing a new email address (e.g., two webhook deliveries for the same new donor's first two recurring cycles landing close together), the check-then-create sequence can race and create two separate Contact records for the same person.
- **Why it's a problem:** Duplicate contact records fragment a donor's giving history across two profiles, breaking donor-relationship reporting, receipt continuity, and any donor-facing history/lifetime-giving views — a data-quality problem that is expensive to detect and merge after the fact, especially at scale where recurring-donation webhooks for many donors could plausibly overlap.
- **Recommended solution:** Either add a true DB-level uniqueness guarantee on (CompanyId, Email) at the Contact level (if the business rule is genuinely 'one contact per email per tenant') and handle the resulting unique-violation with a re-fetch/retry, or wrap the check-then-create in a transaction with a Postgres advisory lock keyed on a hash of the normalized email to serialize concurrent first-time creations for the same address.
- **Production impact:** Concurrent recurring-donation webhook deliveries for a brand-new donor can create duplicate Contact records under real-world timing.
- **Business impact:** Donor history fragmentation undermines donor relationship management and recognition (e.g., a major/recurring donor's giving history split across two profiles), a data-quality issue that compounds over time.
- **Technical impact:** No DB constraint exists to catch or prevent this at the source; would require a manual dedup/merge process to remediate after the fact.
- **Evidence:** Base.Application/Business/DonationBusiness/OnlineDonations/Commands/PromoteOnlineDonationStaging.cs:432-518 (ResolveContactAsync — non-transactional check-then-create); Contact email/phone uniqueness scoped per-ContactId, not cross-contact (ContactEmailAddress/ContactPhoneNumber unique indexes on (CompanyId, ContactId, Email/PhoneNumber))
- **Reviewer note:** not adversarially verified (Medium/Low)

### #230 · Online Donation Page / CrowdFund — Promotion Pipeline — PromoteOnlineDonationStaging — Cross-Aggregate Write Split  — `Medium`

- **Module:** Data Consistency & Concurrency  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** PromoteOnlineDonationStaging.cs calls writer.WriteAsync(...) at line 254 (its own internal transaction, writing the GlobalDonation/GlobalOnlineDonation rows), and then — in a separate SaveChangesAsync at line 334 — marks staging.PromotedGlobalDonationId on the OnlineDonationStaging row to record that promotion succeeded. A compensating soft-delete-on-failure path (lines 336-347, referenced as the 'CF-H5' fix) mitigates the case where the second save fails after the first succeeds.
- **Gap identified:** The write to the GlobalDonation aggregate and the write marking the staging row as 'promoted' are not one atomic transaction — there is a real (if narrow and partially mitigated) window between the two SaveChanges calls where a GlobalDonation could exist while its originating staging row does not yet reflect PromotedGlobalDonationId, e.g., if the process crashes or the pod is recycled between line 254's commit and line 334's commit.
- **Why it's a problem:** If the second write never completes (crash, timeout, deploy) and the CF-H5 compensation does not run (e.g., an unhandled process termination rather than a caught exception), the staging row would remain un-promoted while a GlobalDonation already exists — on any retry/reprocessing of that staging row, the DB-level unique index on (CompanyId, GatewayTransactionId) in GlobalOnlineDonationConfiguration.cs (the real backstop) would correctly reject the duplicate insert, but the retry attempt itself would then throw an unhandled DB exception rather than gracefully detecting 'already promoted' and no-op'ing — depending on how that exception is surfaced, this could produce a visible processing error for what is actually a successfully-completed promotion.
- **Recommended solution:** Wrap both writes (the GlobalDonation composite write and the staging PromotedGlobalDonationId update) in a single outer transaction/execution-strategy scope so they commit or roll back together, or — if writer.WriteAsync's internal transaction cannot be nested/shared — add a pre-write reconciliation check in the retry path that queries GlobalOnlineDonation by GatewayTransactionId first and treats a hit as 'already promoted, just backfill the staging pointer' rather than attempting a fresh write and relying on the unique-index violation as the only backstop.
- **Production impact:** A crash between the two writes leaves a successfully-created GlobalDonation whose staging record doesn't yet know about it; a subsequent retry relies on the DB unique index throwing rather than a clean idempotent no-op.
- **Business impact:** Low likelihood but if triggered, could produce a false 'promotion failed' signal in ops/monitoring for a donation that actually succeeded, causing unnecessary investigation or manual reconciliation.
- **Technical impact:** Two-phase commit gap partially mitigated by compensation logic and a DB unique-index backstop, but not fully eliminated; the failure mode is 'exception on retry' rather than 'clean idempotent skip.'
- **Evidence:** Base.Application/Business/DonationBusiness/OnlineDonations/Commands/PromoteOnlineDonationStaging.cs:254 (writer.WriteAsync own transaction), :334 (separate SaveChangesAsync marking PromotedGlobalDonationId), :336-347 (CF-H5 compensation on failure); Base.Infrastructure/Data/Configurations/DonationConfigurations/GlobalOnlineDonationConfiguration.cs:80-83 (unique index backstop)
- **Reviewer note:** not adversarially verified (Medium/Low)

## Reports

### #61 · Custom Report Builder — Preview / Run / Export of a user-designed custom report  — `Critical`

- **Module:** Reports  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** PreviewCustomReport.cs generates rows via MockValueForFieldKey()/MockAggregateValue() and hardcodes TotalRows=342 (line 135), explicitly labeled 'Preview is a SERVICE_PLACEHOLDER... Real execution pending DynamicQueryBuilder service' (line 139). RunCustomReport.cs only persists LastRunAt/LastRunByUserId (lines 44-46) and returns Status='PLACEHOLDER'/RedirectUrl=null (lines 62-68). ExportCustomReport.cs validates existence only and returns Status='PLACEHOLDER'/DownloadUrl=null (lines 54-61).
- **Gap identified:** None of Preview, Run, or Export ever executes the user's actual report definition against real data; all three are fabricated or no-op.
- **Why it's a problem:** Verified the frontend (custom-report-store.ts and the preview table components) never surfaces the backend's disclosure 'Message' field ('...SERVICE_PLACEHOLDER...') anywhere to the user — a targeted grep for PLACEHOLDER/Message in the FE custom-report-builder code found no matches. Unlike the HTML Report Viewer's export/email actions (which DO show a 'coming soon'/'placeholder' toast to the user), this module gives the user a populated-looking preview grid with fabricated numbers and no visible indication they are fake.
- **Recommended solution:** Build the DynamicQueryBuilder service and wire Preview/Run/Export to it before enabling this screen for real users; until then, surface the backend's placeholder Message in the FE (banner/badge) or feature-flag the screen off.
- **Production impact:** Feature is entirely non-functional for real data with no FE-visible warning; a fabricated Preview number could be mistaken for real and acted upon.
- **Business impact:** Undermines trust in the Reports module if a fabricated figure is shared externally or used in a decision.
- **Technical impact:** No DynamicQueryBuilder service exists at all in the codebase; this is a foundational missing service.
- **Evidence:** Base.Application/Business/ReportBusiness/CustomReports/Queries/PreviewCustomReport.cs:135,139; Base.Application/Business/ReportBusiness/CustomReports/Commands/RunCustomReport.cs:44-46,62-68; Base.Application/Business/ReportBusiness/CustomReports/Queries/ExportCustomReport.cs:54-61; PSS_2.0_Frontend/src/presentation/components/page-components/reportaudit/reports/customreportbuilder/custom-report-store.ts (no PLACEHOLDER/Message handling found)

### #62 · Generate Report (Export to Excel) — Report export via ExportReportQuery/ExportReportHandler  — `Critical`

- **Module:** Reports  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** ExportReport.cs never resolves companyId/isSuperAdmin from HttpContext at all (confirmed: no such variables declared in the handler), and its SQL text at line 85 is `SELECT * FROM {schema}."{functionName}"(@p_filter_json::jsonb, @p_page, @p_page_size, @p_user_id, @p_report_mode)` — 5 positional args only. GenerateReport.cs (sibling handler) resolves companyId/isSuperAdmin (lines 41-42) and passes a 6th p_company_id arg (lines 69, 85-86).
- **Gap identified:** Confirmed the underlying Postgres function signature is `rep.donation_summary_report(p_filter_json jsonb DEFAULT NULL, p_page integer DEFAULT 0, p_page_size integer DEFAULT 10, p_user_id integer DEFAULT NULL, p_report_mode text DEFAULT 'view', p_company_id integer DEFAULT NULL)` (donation_summary_report.sql:3) and `top_donors_aggregation_report(..., p_company_id integer DEFAULT NULL)` (top_donors_aggregation_report.sql:3), both using positional args in the call. Since ExportReport.cs supplies only the first 5 positional args, Postgres applies the function's own DEFAULT NULL for the omitted trailing p_company_id parameter, and the WHERE clause `(p_company_id IS NULL OR d."CompanyId" = p_company_id)` (donation_summary_report.sql:46,59,106; top_donors_aggregation_report.sql:66) is always satisfied — every tenant's rows are returned on every export.
- **Why it's a problem:** Any staff user with Export permission on any report can download an Excel file containing every other tenant's donor, donation, and financial data — a live cross-tenant data leak, not a theoretical one.
- **Recommended solution:** Add companyId/isSuperAdmin resolution and the same p_company_id parameter binding used in GenerateReport.cs to ExportReport.cs's SQL call, and add an integration test asserting exported row CompanyId always matches the caller's tenant.
- **Production impact:** Live cross-tenant financial/donor data leak on every report export in production.
- **Business impact:** Breach of donor PII/financial data across tenants; reportable data-breach exposure for an NGO donor database; contractual/legal liability with partner organizations sharing the platform.
- **Technical impact:** Silent — no error, no log, no test catches this; verified by direct comparison of the two handlers' SQL parameter lists and the Postgres function signature/DEFAULT semantics.
- **Evidence:** Base.Application/Business/ReportBusiness/Reports/Queries/ExportReport.cs:85 (5-param call, no company scoping anywhere in the file) vs GenerateReport.cs:41-42,69,85-86 (6-param call incl. p_company_id resolved server-side); DatabaseScripts/Functions/rep/donation_summary_report.sql:3,46,59,106; DatabaseScripts/Functions/rep/top_donors_aggregation_report.sql:3,66,129

### #63 · Scheduled Reports — Automatic scheduled execution + Run Now  — `Critical`

- **Module:** Reports  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** RunScheduledReportNow.cs is an explicit SERVICE_PLACEHOLDER (file header comment lines 5-10): handler (lines 38-59) only inserts a ScheduledReportRun row with StatusId=RUNNING and returns the RunId. No code anywhere transitions any run to COMPLETED/FAILED (grep across the ScheduledReports folder for COMPLETED/FAILED found nothing besides this file). Hangfire server is registered (Base.API/DependencyInjection.cs:107) but a repo-wide grep for RecurringJob.AddOrUpdate returns zero matches anywhere in the backend.
- **Gap identified:** No job ever wires ScheduledReport.CronExpression to Hangfire, and no job ever performs report generation, rendering, or delivery for scheduled runs; even the manual Run Now path leaves the run permanently stuck at RUNNING.
- **Why it's a problem:** The Scheduled Reports screen configures cron schedules and recipients and exposes 'Run Now', but nothing ever executes on schedule and manual runs never complete, resolve, or notify — a fully non-functional feature presenting as configured/working.
- **Recommended solution:** Implement a Hangfire recurring job registered/updated on ScheduledReport create/CronExpression change that invokes a real report pipeline, updates ScheduledReportRun.Status to COMPLETED/FAILED with timing/error info, and delivers output via the configured channel.
- **Production impact:** No scheduled report has ever been or will be delivered in production; every run shows RUNNING forever with no failure alert.
- **Business impact:** Breaks a core promised capability (automated recurring reporting) for compliance/funder/board workflows; silent failure delays discovery until an external stakeholder complains.
- **Technical impact:** Every ScheduledReportRun row is orphaned at RUNNING forever; no retry/backoff/alerting exists.
- **Evidence:** Base.Application/Business/ReportBusiness/ScheduledReports/RunNowCommand/RunScheduledReportNow.cs:5-10,38-59; Base.API/DependencyInjection.cs:107; repo-wide grep for RecurringJob.AddOrUpdate returned no matches

### #171 · Generate Report / Report Catalog (Custom Report data grid) — Server-side max-row guard on report view and export  — `High`

- **Module:** Reports  |  **Category:** performance  |  **Verification:** CONFIRMED
- **Current implementation:** GenerateReport.cs:82 passes queryRequest.pageSize directly to p_page_size with no clamp; GenerateReportsValidator's ValidateGridFeatures call is commented out (confirmed line 25: `//ValidateGridFeatures(...)`). ExportReport.cs:98 hardcodes p_page_size = int.MaxValue for every export (confirmed). Confirmed in top_donors_aggregation_report.sql:119-121 that `LIMIT %s OFFSET %s` is only appended `IF p_report_mode = 'view'` — export mode has no LIMIT/cap at all. Confirmed FE report-datatable-fetch.tsx:220 caps pageSize via `Math.min(pageSize, 100)`, which is a client-side-only, GraphQL-bypassable constant.
- **Gap identified:** No enforced server-side maximum row/page-size guard exists anywhere in the generic report-execution pipeline (view or export), for either the C# handler layer or the underlying Postgres export-mode functions.
- **Why it's a problem:** A client can request arbitrarily large page sizes on view, or trigger an unbounded export of a large dataset, risking query/connection/memory pressure on the DB and API process as data volume grows, with no current safeguard beyond a bypassable FE constant.
- **Recommended solution:** Add a server-side pageSize clamp (e.g., max 100-500 for view; an explicit documented export row cap, e.g. 50,000, with chunked export beyond that) enforced in GenerateReportsValidator and ExportReport.cs.
- **Production impact:** Risk of resource-exhaustion incidents (slow queries, DB connection pool starvation, API timeouts) as production data volume grows.
- **Business impact:** Potential platform-wide slowdown/outage affecting all tenants if a large export or oversized page request is triggered, accidental or malicious.
- **Technical impact:** No test or validator currently prevents this; only guard is a client-side FE constant trivially bypassed by direct API/GraphQL calls.
- **Evidence:** Base.Application/Business/ReportBusiness/Reports/Queries/GenerateReport.cs:82; GenerateReportsValidator (GenerateReport.cs:25, commented-out ValidateGridFeatures); ExportReport.cs:98 (p_page_size = int.MaxValue); DatabaseScripts/Functions/rep/top_donors_aggregation_report.sql:119-121; PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/report/report-datatable-fetch.tsx:220

### #172 · HTML Report Viewer / Report Catalog — Role-based visibility of report templates  — `High`

- **Module:** Reports  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** GetHtmlReportTemplatesQuery.cs handler (lines 35-53) selects from dbContext.Reports filtered only on IsActive, IsDeleted, ReportCategoryId != null, and tenant scoping (CompanyId == null || CompanyId == companyId) — confirmed no role/permission join or filter of any kind.
- **Gap identified:** Confirmed and actually more concrete than originally described: a full ReportRole entity/table already exists in the codebase (Base.Domain/Models/AuthModels/ReportRole.cs — RoleId, ReportId, HasAccess, mirroring the exact WidgetRole pattern) with its own DbSet (IAuthDbContext.cs:15, AuthDbContext.cs:17), DTOs, and admin CRUD mutations/queries (ReportRoleMutations.cs, ReportRoleQueries.cs) — i.e. the access-control data model and admin UI for per-role report visibility were built, but GetHtmlReportTemplatesHandler simply never consults ReportRoles. Confirmed the WidgetRole intersection pattern this should mirror does exist and work in GenerateWidget.cs:42-59 (UserRoles ∩ WidgetRoles.Where(HasAccess==true)).
- **Why it's a problem:** Any authenticated user with base Report Read permission sees every report template across all categories (Financial, Compliance, Management, Operational) regardless of role, even though the RoleReport access-control mechanism to prevent this already exists elsewhere in the same codebase and is simply unused here.
- **Recommended solution:** Add a ReportRoles join/filter to GetHtmlReportTemplatesHandler mirroring GenerateWidget.cs:42-59 (intersect current user's RoleIds against ReportRoles where HasAccess==true for each report) before this screen is production-ready.
- **Production impact:** Over-broad visibility of sensitive report categories to under-privileged roles in production today.
- **Business impact:** Financial and compliance data over-exposure to staff who should not see it — an internal-controls/segregation-of-duties gap for an NGO handling donor funds.
- **Technical impact:** The exact access-control primitive (ReportRole entity + admin management screens) already exists in the codebase and is unused by this query — a wiring gap, not a missing-infrastructure gap, making it a quick, low-risk fix.
- **Evidence:** Base.Application/Business/ReportBusiness/Reports/Queries/GetHtmlReportTemplatesQuery.cs:35-53; Base.Domain/Models/AuthModels/ReportRole.cs:1-33; Base.Application/Data/Persistence/IAuthDbContext.cs:15; Base.Infrastructure/Data/Persistence/AuthDbContext.cs:17; Base.Application/Business/SettingBusiness/Widgets/Queries/GenerateWidget.cs:42-59 (pattern to mirror)

### #275 · Donor Retention Dashboard — Cohort Matrix widget tenant scoping  — `Medium`

- **Module:** Reports  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** fn_retention_dashboard_cohort_matrix.sql:50,70 uses non-null-safe equality gd."CompanyId" = p_company_id (missing the (p_company_id IS NULL OR ...) guard used consistently in every other report/widget SQL function in this module, e.g. donation_summary_report.sql:46). GenerateWidget.cs (the shared widget engine) passes DBNull.Value for p_company_id specifically for verified SuperAdmin users (matching the pattern in GenerateReport.cs:85-86).
- **Gap identified:** For a SuperAdmin user viewing this specific widget, p_company_id is bound as NULL, but the SQL's plain equality comparison NULL = anything evaluates to false/unknown in Postgres, so the WHERE clause excludes every row.
- **Why it's a problem:** SuperAdmin users (who are expected to have the broadest, not narrowest, visibility) see a silently empty Cohort Matrix widget with no error message, no 'no data' explanation distinguishing this from a genuine empty dataset — a functional bug that specifically breaks the platform's own administrative/oversight role on this dashboard.
- **Recommended solution:** Fix fn_retention_dashboard_cohort_matrix.sql to use the same NULL-safe pattern, (p_company_id IS NULL OR gd."CompanyId" = p_company_id), as every other report/widget function in the codebase, and add a regression test specifically covering the SuperAdmin (NULL company) case for every report/widget SQL function.
- **Production impact:** SuperAdmin-role users see a broken/empty widget on the Retention Dashboard in production, with no error to explain why.
- **Business impact:** Reduces confidence in the dashboard's correctness generally once one widget is observed to silently fail for a subset of users.
- **Technical impact:** Inconsistent SQL-scoping convention across the report/widget function library increases risk of the same class of bug recurring in future functions unless standardized.
- **Evidence:** DatabaseScripts/Functions/fund/fn_retention_dashboard_cohort_matrix.sql:50,70; contrast with DatabaseScripts/Functions/rep/donation_summary_report.sql:46,59,106 and Base.Application/Business/SettingBusiness/Widgets/Queries/GenerateWidget.cs:100-101
- **Reviewer note:** not adversarially verified (Medium/Low)

### #276 · Generate Report / all report screens in this module — Runtime/E2E verification of shipped screens  — `Medium`

- **Module:** Reports  |  **Category:** qa  |  **Verification:** CONFIRMED
- **Current implementation:** Every screen-tracker prompt file in this module (e.g. retentiondashboard.md lines 44-58, and the equivalent Verification sections in the prompt files for the other screens in scope) marks its 'Verification (post-generation — FULL E2E required)' checklist entirely unchecked ([ ]), while the screen's overall status is recorded as COMPLETED.
- **Gap identified:** No screen in the Reports module scope has a recorded/confirmed runtime or end-to-end test pass; only dotnet build / tsc --noEmit compile-check success is confirmed anywhere in the tracked history.
- **Why it's a problem:** Given the concrete, code-confirmed functional and security defects found in this audit (cross-tenant export leak, permanently-stuck scheduled runs, fully mocked Custom Report Builder, false-success email, dead-link PDF/Excel exports) existing in screens whose status is recorded as COMPLETED, this confirms the module's 'Completed' label reflects compile-success only, not verified working behavior — exactly the risk this audit was commissioned to surface.
- **Recommended solution:** Before any Reports-module screen is promoted from COMPLETED to a release-ready state, require an actual E2E pass through its Verification checklist (real data, real role accounts, real exports opened and inspected) and update the tracker to reflect true verification status, not just compile success.
- **Production impact:** Systemic risk indicator: any other screen in this codebase marked COMPLETED should be treated as unverified until proven otherwise by code reading, not by trusting the status label.
- **Business impact:** Erodes reliability of the entire project status-tracking system used to plan releases.
- **Technical impact:** No CI/E2E gate currently blocks a screen from being marked COMPLETED without runtime verification.
- **Evidence:** .claude/screen-tracker/prompts/retentiondashboard.md:44-58 (Verification checklist entirely unchecked, status COMPLETED)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #277 · HTML Report Viewer — Email report action  — `Medium`

- **Module:** Reports  |  **Category:** functional  |  **Verification:** ADJUSTED
- **Current implementation:** EmailHtmlReportMutation.cs handler (lines 40-51) is a SERVICE_PLACEHOLDER that only logs via ILogger and returns Success=true, without ever invoking an email service. HOWEVER: the frontend email-modal.tsx (line 99) does NOT surface this as a success confirmation — on mutation success it shows `toast.info("Email queued (placeholder)")`, an end-user-visible toast that explicitly contains the word 'placeholder'.
- **Gap identified:** The backend still fabricates Success=true rather than returning an explicit non-success/placeholder status, which is bad API hygiene (a direct API/GraphQL caller bypassing the FE would see a genuine-looking success), but the originally reported user-facing harm — 'UI will show a success toast ("Report emailed successfully")' misleading the user into believing a real email was sent — does not occur. The FE's own toast explicitly discloses '(placeholder)' to the user.
- **Why it's a problem:** Reduced from the original claim: end users interacting through the actual screen are not deceived, since the toast text itself says 'placeholder'. The real remaining problem is narrower — email sending is simply unimplemented (a functional gap), and the backend's unconditional Success=true is a latent risk for any other/future caller of this mutation that doesn't add its own disclosure.
- **Recommended solution:** Wire to the real email service (IEmailTemplateService / SendComposedEmailForCompanyAsync pattern) before enabling for production; in the interim, keep the FE's existing placeholder disclosure but also change the backend response to a non-generic-success shape (e.g., Success=false + Message) so no other caller can be misled.
- **Production impact:** Users are NOT actually misled in the current UI — the toast says 'placeholder' — but no email is functionally sent, so this action is unusable for its intended purpose.
- **Business impact:** Missed funder/board/compliance report emails since the feature is simply not implemented yet, though the current UI does at least disclose this rather than hide it.
- **Technical impact:** No email audit trail, no retry, no failure path; backend API contract is misleading in isolation (Success=true) even though FE compensates with its own message.
- **Evidence:** Base.Application/Business/ReportBusiness/Reports/Mutations/EmailHtmlReportMutation.cs:1,37-52 (SERVICE_PLACEHOLDER, unconditional Success=true); PSS_2.0_Frontend/src/presentation/components/page-components/reportaudit/reports/htmlreport/components/email-modal.tsx:99 (toast.info("Email queued (placeholder)") shown to the end user)

### #278 · HTML Report Viewer — PDF export and Excel export actions  — `Medium`

- **Module:** Reports  |  **Category:** functional  |  **Verification:** ADJUSTED
- **Current implementation:** GenerateHtmlReportPdfMutation.cs and ExportHtmlReportExcelMutation.cs are SERVICE_PLACEHOLDER handlers returning fake DownloadUrl strings (`https://placeholder.local/pdf/...` and `.../excel/...`). HOWEVER: report-toolbar.tsx's handleExportPdf/handleExportExcel (lines 48-76) call the mutation, then completely ignore the returned DownloadUrl and instead show `toast.info("PDF export coming soon")` / `toast.info("Excel export coming soon")` — the fake URL is never opened, downloaded, or exposed to the user in any way.
- **Gap identified:** Confirmed the backend export is unimplemented (real gap), but the originally reported failure mode — 'FE receives what looks like a valid download URL and will presumably attempt to open/download it, hitting a domain that does not exist' — is factually incorrect. The FE never touches the URL; it deliberately treats the whole action as 'coming soon'.
- **Why it's a problem:** The severity is materially lower than claimed: no user ever sees or hits a dead link. The real remaining issue is that PDF/Excel export from the HTML Report Viewer is simply not built yet — a functional gap, correctly labeled in the UI as 'coming soon', not a broken-experience bug.
- **Recommended solution:** Integrate a real PDF rendering engine and Excel generation library before enabling these actions; the FE's existing defensive 'coming soon' toast can remain until then and does not need to change.
- **Production impact:** PDF/Excel export from HTML Report Viewer is unavailable, but the UI already communicates this honestly ('coming soon') rather than producing a broken download experience.
- **Business impact:** Staff cannot produce shareable offline copies of reports from this screen yet, but are not confused about it — no support-ticket-generating dead-link confusion.
- **Technical impact:** No PDF/Excel generation service exists in this code path; the mutations are still called (and log/return fake URLs) even though the FE ignores the result — minor wasted round-trip, not a broken-link defect.
- **Evidence:** Base.Application/Business/ReportBusiness/Reports/Mutations/GenerateHtmlReportPdfMutation.cs:1,29-38; Base.Application/Business/ReportBusiness/Reports/Mutations/ExportHtmlReportExcelMutation.cs:1,29-38; PSS_2.0_Frontend/src/presentation/components/page-components/reportaudit/reports/htmlreport/components/report-toolbar.tsx:48-76 (toast.info "...coming soon", DownloadUrl never used)

## Contacts / CRM

### #15 · Contact (list/index) — Contacts grid — GetContactsQuery  — `Critical`

- **Module:** Contacts / CRM  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** GetContact.cs:6-11 carries `[RequiresTenant]` + `[TenantScope(TenantScopeType.Current)]`. Handler base query at lines 55-57: `dbContext.Contacts.AsNoTracking().Include(...).OrderByDescending(x=>x.CreatedDate).Where(x=>x.IsDeleted==false)` — read the full 259-line file; zero CompanyId predicate anywhere. TenantAccessBehavior.cs:51-55 shows scope `Current` does nothing itself, comment says 'EF global filter and handler take care of filtering.' Confirmed via repo-wide grep: zero `HasQueryFilter` matches in Base.Infrastructure, and zero matches for `HasQueryFilter`/`MultiTenant`/`IHasCompany` anywhere. TenantIsolationBehavior.cs:86-144 only reflects a `CompanyId` property on the request DTO if one exists — `GetContactsQuery` has no such property, so this check is a no-op for this query.
- **Gap identified:** No layer in the stack (attribute, behavior, EF global filter, or handler) actually restricts the Contacts grid to the caller's CompanyId.
- **Why it's a problem:** Any authenticated user with Contact:Read in any tenant sees every contact across every company — full cross-tenant PII leak on the CRM module's flagship grid.
- **Recommended solution:** Add `.Where(x => x.CompanyId == companyId)` (companyId from `httpContextAccessor.GetCurrentUserStaffCompanyId()`) to the base query; add a real EF Core global query filter for tenant-scoped entities so this bug class cannot recur silently.
- **Production impact:** Cross-tenant data exposure on the primary Contact list.
- **Business impact:** Regulatory/PII breach exposure across all NGO tenants sharing the deployment.
- **Technical impact:** Silent — no exception, no log; only a security audit or a customer noticing foreign data would surface it.
- **Evidence:** Base.Application/Business/ContactBusiness/Contacts/Queries/GetContact.cs:6-11,54-57 (comment at line 54 claims scoping that does not exist in the query); Base.Application/Behaviors/TenantAccessBehavior.cs:49-56 (Current scope is a pass-through); Base.Application/Behaviors/TenantIsolationBehavior.cs:86-144 (reflection-based CompanyId check is a no-op absent that property); zero repo-wide matches for HasQueryFilter

### #16 · Duplicate Detection / Merge Contacts — Duplicate detection & merge engine  — `Critical`

- **Module:** Contacts / CRM  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** MergeContacts.cs:101-105 and DetectDuplicateContacts.cs:31-35 call `dbContext.ExecuteRawSqlAsync("SELECT * FROM corg.fn_detect_duplicate_contacts({0})"...)` / `corg.fn_merge_contacts(...)`. Read both SQL files in full: DuplicateContact-fn-detect.sql is 205/205 lines prefixed with `--` including the `CREATE OR REPLACE FUNCTION` statement itself (line 11); DuplicateContact-fn-merge.sql is 491 lines, with the `CREATE OR REPLACE FUNCTION corg.fn_merge_contacts` line (line 7) and every executable line through line 490 (`END;`) commented out.
- **Gap identified:** Both backing PostgreSQL functions are 100% commented dead code while the full C# CQRS stack (validators, handlers, GraphQL) is live and reachable from the UI.
- **Why it's a problem:** Clicking Run Detection or Merge in production throws a raw Postgres 'function does not exist' exception, caught only by a generic try/catch that rethrows `InternalServerException(ex.Message)` (MergeContacts.cs:141, DetectDuplicateContacts.cs:55) — a Postgres-internal error leaks to the GraphQL client with no graceful UI fallback.
- **Recommended solution:** Uncomment and deploy both SQL functions (user-owned), then smoke-test Detect+Merge against a seeded duplicate pair before go-live.
- **Production impact:** Core CRM dedup+merge feature is completely non-operational; every attempt throws.
- **Business impact:** Data stewards cannot clean up duplicate donor/contact records.
- **Technical impact:** Unhandled Postgres exception surfaced via generic InternalServerException wrapper; no feature flag hides the UI when the function is absent.
- **Evidence:** sql-scripts-dyanmic/DuplicateContact-fn-detect.sql:1-205 (all lines `--`-prefixed); sql-scripts-dyanmic/DuplicateContact-fn-merge.sql:1-491 (all lines `--`-prefixed); Base.Application/Business/ContactBusiness/DuplicateContacts/Commands/DetectDuplicateContacts.cs:31-35; MergeContacts.cs:100-105,137-142

### #105 · Contact Import — Import execution — batch commit / rollback  — `High`

- **Module:** Contacts / CRM  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** ImportExecutionService.cs:20 class doc comment: 'Each batch call is its own transaction — partial progress is committed immediately.' ExecuteBatchImportAsync (lines 148-283): while-loop calling the import stored proc per batch (line 184-203), `UpdateBatchProgressAsync(sessionId, offset, totalParent)` per batch at line 218 to 'enable resume-on-failure', and `session.StagingRetainUntil = DateTime.UtcNow.AddDays(30)` at line 268. Repo-wide grep for Rollback/Undo across Base.Application/Business/ImportBusiness, Base.API, and Base.Support/Import returns zero matches (the only two Rollback/Undo hits repo-wide are in unrelated RegionHierarchies and AccountingIntegrations code).
- **Gap identified:** No automated or manual rollback/undo command exists for a partially-completed import; only resume-from-offset.
- **Why it's a problem:** A failed/cancelled import partway through leaves committed batches (Contacts + child records) permanently in production with no single-click undo — only manual SQL cleanup, and only while the 30-day staging retention window still holds reference data.
- **Recommended solution:** Add an 'Undo Import' capability that soft-deletes/deactivates every row created under a given ImportSessionId using the staging table linkage, or tag every created row with ImportSessionId for a safely-scoped rollback script.
- **Production impact:** No safe recovery path from a partially-failed import; requires manual DBA intervention.
- **Business impact:** Bad imports (wrong file/mapping, mid-run failure) can leave the donor database in an inconsistent state risking duplicate/partial records propagating into mailings, receipts, and reports.
- **Technical impact:** Committed batches are indistinguishable from organically-created contacts once staging data ages out after 30 days.
- **Evidence:** Base.Support/Import/Services/ImportExecutionService.cs:20,148-283,218,268; zero Rollback/Undo matches across Base.Application/Business/ImportBusiness, Base.API, Base.Support/Import

### #106 · Duplicate Detection (queue/grid + actions) — GetDuplicateContacts / IgnoreDuplicateContact / NotDuplicateContact  — `High`

- **Module:** Contacts / CRM  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** GetDuplicateContacts.cs:42-44 base query: `dbContext.DuplicateContacts.AsNoTracking().Where(d => d.IsDeleted == false)` — read the full 409-line file, no CompanyId filter anywhere. IgnoreDuplicateContact.cs:23-26 and NotDuplicateContact.cs:25-28 both query `dbContext.DuplicateContacts.Include(d=>d.Action).FirstOrDefaultAsync(d => d.DuplicateContactId == command.DuplicateContactId && d.Action.DataValue == "PEN", ...)` with no CompanyId predicate, both files read in full (48-50 lines each).
- **Gap identified:** Sibling query GetDuplicateContactSummary.cs correctly applies `var companyId = httpContextAccessor.GetCurrentUserStaffCompanyId(); ... baseQuery.Where(d => d.CompanyId == companyId)` (confirmed via grep at lines 35,44) — proving the correct pattern exists in the same feature folder but was not applied to the queue grid or either resolve command.
- **Why it's a problem:** Any user can view the entire cross-tenant duplicate queue and call Ignore/NotDuplicate on an arbitrary DuplicateContactId belonging to another company (IDOR) — a write action, not just a read leak.
- **Recommended solution:** Add `Where(d => d.CompanyId == companyId)` to GetDuplicateContacts and add the same ownership predicate to the FirstOrDefaultAsync lookups in IgnoreDuplicateContact and NotDuplicateContact.
- **Production impact:** Cross-tenant read of duplicate queue + cross-tenant write (dismiss/ignore) via ID enumeration.
- **Business impact:** Exposes tenant B's donor-matching data/actions to tenant A staff, undermining dedup feature trust.
- **Technical impact:** IDOR: DuplicateContactId is a sequential integer with no ownership check at the command layer.
- **Evidence:** Base.Application/Business/ContactBusiness/DuplicateContacts/Queries/GetDuplicateContacts.cs:42-44 (no CompanyId filter, full file read); Commands/IgnoreDuplicateContact.cs:23-26; Commands/NotDuplicateContact.cs:25-28; contrast confirmed at Queries/GetDuplicateContactSummary.cs:35,44 (`d.CompanyId == companyId`)

### #107 · Duplicate Detection / Merge Contacts — Merge data-transfer coverage  — `High`

- **Module:** Contacts / CRM  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** Full read of DuplicateContact-fn-merge.sql confirms live UPDATE statements (all still inside the commented-out function) for ReceiptDonations, OnlineDonations, SecondaryOnlineDonations, DonationDistributions, addresses/phones/emails/relationships/social links/purposes/referrals/ContactTypeAssignments — but genuine `-- TODO: Enable when X entity/table exists` stub sections (no actual UPDATE, just the TODO comment) at lines 378-379 (ContactTag), 382-383 (ContactUPIDetail), 407-408 (OnlineDonationDistributions — blocked because table lacks ContactId/PartnerContactId column), 421-422 (GlobalDonations), 424-425 (GlobalDonationDistributions), 427-428 (ContactPrayerRequests).
- **Gap identified:** When the merged contact is deactivated (line 451-456), any Tags, UPI details, Prayer Requests, or GlobalDonations tied to it are never transferred — becoming orphaned once the merged contact is IsDeleted=true.
- **Why it's a problem:** A donor's global donation history, UPI payment method, prayer requests, and tags recorded against the losing side silently disappear from the surviving contact's profile.
- **Recommended solution:** Complete the TODO transfer blocks for ContactTag, ContactUPIDetail, ContactPrayerRequests, and GlobalDonations/GlobalDonationDistributions; add a ContactId column to OnlineDonationDistributions before enabling merge.
- **Production impact:** Silent data loss on every merge for the entity types listed, once the (currently disabled) merge feature is turned on.
- **Business impact:** Loss of donation history/tags/payment info undermines donor relationship continuity and financial reporting completeness.
- **Technical impact:** No FK cascade or audit trail links orphaned child rows back to the surviving contact. Note: the GlobalDonations TODO text ('Enable when GlobalDonation table is created in DB') appears stale — GetContact.cs and GetDuplicateContacts.cs both actively query `dbContext.GlobalDonations` today, meaning that table already exists; the TODO is inaccurate and could mislead whoever eventually completes this function.
- **Evidence:** sql-scripts-dyanmic/DuplicateContact-fn-merge.sql:378-379,382-383,407-408,421-422,424-425,427-428 (six TODO stub sections, confirmed no UPDATE follows any of them); cross-checked GlobalDonations table already in active use at Base.Application/Business/ContactBusiness/Contacts/Queries/GetContact.cs:122

### #108 · Duplicate Detection / Merge Contacts — MergeContacts validator — tenant ownership  — `High`

- **Module:** Contacts / CRM  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** MergeContactsValidator (MergeContacts.cs:16-40), read in full: only validates ValidContactId != MergedContactId (line 27-29) and that both contacts exist and are IsActive/!IsDeleted (lines 31-39). No CompanyId/tenant-ownership check on either ContactId. The handler (lines 47-144) also never checks CompanyId of the two contacts before invoking `corg.fn_merge_contacts`.
- **Gap identified:** Nothing in the merge path prevents submitting an arbitrary ContactId pair — including ones from a different company — directly to the MergeContacts mutation, compounding the missing tenant filter on GetDuplicateContacts.
- **Why it's a problem:** Once the (currently disabled) merge SQL function is deployed, this becomes a cross-tenant data-integrity hazard: any user could merge/deactivate a contact belonging to another company by supplying its ContactId directly.
- **Recommended solution:** Add validator rules requiring both ValidContactId and MergedContactId to belong to the caller's current CompanyId (via `httpContextAccessor.GetCurrentUserStaffCompanyId()`).
- **Production impact:** Cross-tenant merge/deactivation possible via direct mutation call once the SQL function is live.
- **Business impact:** A cross-tenant merge could deactivate a contact and reroute donation/relationship history belonging to a different NGO client.
- **Technical impact:** No tenant-scoping guard at the single most destructive command in the Contacts module (merge = deactivate + transfer all child data).
- **Evidence:** Base.Application/Business/ContactBusiness/DuplicateContacts/Commands/MergeContacts.cs:16-40 (validator has no CompanyId check on either contact, full file read confirms handler also lacks one)

### #109 · Family — Family membership reassignment (merge, bulk-set, relationship-linking)  — `High`

- **Module:** Contacts / CRM  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** Verified three code paths: (1) DuplicateContact-fn-merge.sql:436-447 — `IF v_valid_family_id IS NOT NULL THEN UPDATE Contacts SET FamilyId = v_valid_family_id WHERE FamilyId = (merged contact's old FamilyId) AND ContactId != merged` — reassigns every member of the merged contact's old family whenever the valid contact has any FamilyId, with no check the merged contact was that family's head, and no deactivation of the now-orphaned Family row (confirmed no such UPDATE on `Families` table anywhere in the file). (2) SetFamilyMembers.cs:84-96 (Step 2) sets `c.FamilyId = req.FamilyId` for newly-added members with no check of prior FamilyId. (3) CreateContactRelationship.cs MapFamilyIfFamilyHead:99-117 sets `relationContact.FamilyId = parentContact.FamilyId` whenever parent IsFamilyHead+has FamilyId, with no check of the relation-contact's existing FamilyId (note: a validator rule at lines 31-40 does block RelationContact from being an existing family HEAD, but does not check/block a non-head member of a different family from being spliced in).
- **Gap identified:** No path in the Family module checks whether the target contact already belongs to a different family before reassignment, and no orphaned-Family cleanup occurs.
- **Why it's a problem:** All three are common, everyday actions and can silently splice unrelated families' memberships together or strand a FamilyId pointing at a now-empty family record, with no user-facing warning.
- **Recommended solution:** Before reassigning FamilyId in all three locations, check for an existing different non-null FamilyId with other members and block/confirm; mark a Family inactive when it reaches zero active members.
- **Production impact:** Silent family-membership corruption during routine merge/relationship/roster operations.
- **Business impact:** Corrupts household-level donation aggregation, mailing lists, and donor stewardship reporting.
- **Technical impact:** Orphaned Family rows accumulate; FamilyId can point somewhere the user never intended, discoverable only via manual DB inspection.
- **Evidence:** sql-scripts-dyanmic/DuplicateContact-fn-merge.sql:436-447; Base.Application/Business/ContactBusiness/Families/Commands/SetFamilyMembers.cs:84-96; Base.Application/Business/ContactBusiness/ContactRelationships/Commands/CreateContactRelationship.cs:99-117 (validator carve-out for existing family heads noted at lines 31-40 but does not close the gap for non-head members)

### #218 · Contact (UPI / payment details tab) — ContactUPIDetail — PII/financial data exposure  — `Medium`

- **Module:** Contacts / CRM  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** ContactUPIDetail.cs stores `UPIIdentifier` (a UPI payment ID, e.g. name@bank) as a plain string with no masking flag. GetContactUPIDetail.cs (Base.Application/Business/ContactBusiness/ContactUPIDetails/Queries/GetContactUPIDetail.cs:38) queries `dbContext.ContactUPIDetails.Where(x => x.IsDeleted == false)...` with no CompanyId filter, and the search clause (:43-45) matches directly against the raw `UPIIdentifier` string, which is then returned unmasked in `ContactUPIDetailResponseDto` to any caller with ContactUPIDetail:Read permission.
- **Gap identified:** A payment identifier tied to a real bank/UPI account is stored and served in cleartext with no masking (contrast with the project's own standard 'sensitive fields masked + write-only' pattern for CONFIG screens per project convention), and the same missing-CompanyId pattern found elsewhere in Contacts recurs here.
- **Why it's a problem:** UPI identifiers are financial PII; displaying them unmasked in any grid/list view (and potentially across tenants, given no CompanyId scoping) is a data-protection gap for a nonprofit handling donor payment information.
- **Recommended solution:** Mask UPIIdentifier in list/grid responses (show last few characters only, full value only in a dedicated detail/edit view with audit logging on reveal), and add the missing `CompanyId == companyId` filter to GetContactUPIDetail.
- **Production impact:** Financial PII displayed in cleartext in a general list query; potential cross-tenant exposure.
- **Business impact:** Donor payment/banking identifiers exposed beyond need-to-know, a compliance and trust risk for a donation-processing platform.
- **Technical impact:** No masking layer or field-level access control exists for this entity today.
- **Evidence:** Base.Domain/Models/ContactModels/ContactUPIDetail.cs:8 (UPIIdentifier plain string); Base.Application/Business/ContactBusiness/ContactUPIDetails/Queries/GetContactUPIDetail.cs:38-45 (no CompanyId filter, unmasked in search/response)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #219 · Contact Import — Duplicate detection during import validation  — `Medium`

- **Module:** Contacts / CRM  |  **Category:** qa  |  **Verification:** CONFIRMED
- **Current implementation:** sql-scripts-dyanmic/ContactImport-fn-validate.sql STEP 13a/13b (lines 1094-1158) flags duplicates via an exact match: `stg."FirstName" = dup."FirstName" AND stg."LastName" = dup."LastName" AND ... c."DOB" = stg."DOB"::date` for both intra-file duplicates and existing-DB duplicates (correctly scoped by `c."CompanyId" = $3`).
- **Gap identified:** The match is case-sensitive, exact-string only — no normalization (trimming, case-folding, removing punctuation/hyphens) like the separate dedup engine's fn_detect_duplicate_contacts uses (REPLACE-based name normalization). It also only matches on Name+DOB, ignoring the Name+Mobile and Name+Email categories the standalone Duplicate Detection feature uses.
- **Why it's a problem:** Real-world duplicate rows differing only by case ('John Smith' vs 'JOHN SMITH'), whitespace, or missing DOB will pass import validation as clean, undermining the 'prevent duplicates on import' goal and creating exactly the kind of dirty data the separate Duplicate Detection module then has to clean up (itself currently non-functional per Finding #1).
- **Recommended solution:** Normalize both sides of the comparison (lower-case, trim, strip punctuation) and add Name+Mobile / Name+Email match categories consistent with the standalone dedup engine so import-time and post-import dedup use the same matching logic.
- **Production impact:** Higher rate of duplicate contacts entering the system via bulk import undetected.
- **Business impact:** Data quality degradation compounds over time via imports, especially for large NGOs onboarding donor lists from spreadsheets with inconsistent casing/formatting.
- **Technical impact:** Inconsistent duplicate-matching rules between two features (Import validation vs. Duplicate Detection) that should share one definition of 'duplicate.'
- **Evidence:** sql-scripts-dyanmic/ContactImport-fn-validate.sql:1094-1158 (STEP 13a/13b exact-match logic, CompanyId-scoped at line 1145/1156)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #220 · Contact Source — MergeContactSources — tenant ownership check  — `Medium`

- **Module:** Contacts / CRM  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** MergeContactSourcesHandler (Base.Application/Business/ContactBusiness/ContactSources/Commands/MergeContactSources.cs:36-49) fetches `var cid = httpContextAccessor.GetCurrentUserStaffCompanyId();` at line 38 but never references `cid` again anywhere in the method. The only tenant-related check is `if (source.CompanyId != target.CompanyId) throw new BadRequestException(...)` at line 49 — comparing the two ContactSources to each other, not to the caller's own company.
- **Gap identified:** Neither `source` nor `target` is ever checked against `cid` (the caller's own tenant). As long as the two ContactSourceIds belong to the SAME company as each other (even if that company is NOT the caller's), the merge proceeds and reassigns all of that other company's Contacts from the source to the target ContactSourceId.
- **Why it's a problem:** A user from Company A can merge two ContactSources belonging to Company B purely by guessing/enumerating ContactSourceIds, silently reassigning Company B's contact-source classification data — a cross-tenant IDOR write.
- **Recommended solution:** Add `if (source.CompanyId != cid) throw new UnauthorizedAccessException(...)` (and equivalently for target, which is redundant once source is checked and source.CompanyId==target.CompanyId is already enforced).
- **Production impact:** Cross-tenant write capability via ID enumeration on a settings-like entity (Contact Source).
- **Business impact:** Another tenant's contact-source taxonomy and contact assignments can be altered without the affected company's knowledge.
- **Technical impact:** Dead variable `cid` is a strong signal the ownership check was intended but never implemented.
- **Evidence:** Base.Application/Business/ContactBusiness/ContactSources/Commands/MergeContactSources.cs:38 (cid fetched, never used), :49 (only compares source/target to each other, not to cid)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #221 · Duplicate Detection — DetectDuplicateContacts — category count reporting  — `Medium`

- **Module:** Contacts / CRM  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** DetectDuplicateContactsResult declares NameDobPairs/NameMobilePairs/NameEmailPairs (DetectDuplicateContacts.cs:9-12), but the handler (lines 46-50) always returns `new DetectDuplicateContactsResult(true, $"Detection completed. {pendingCount} total pending pairs.", 0, 0, 0)` — the three category counts are hardcoded to zero regardless of what the (currently non-deployed) SQL function actually finds.
- **Gap identified:** The SQL function's RETURNS TABLE signature computes real per-category counts (v_cat1_count/v_cat2_count/v_cat3_count per the commented-out source), but the C# handler never captures the function's result rows — it discards them and fabricates 0/0/0.
- **Why it's a problem:** If/when the underlying SQL function is deployed and this result is ever surfaced in the UI ('Found N name+DOB matches, N name+mobile matches...'), the breakdown shown to the user will always read zero across all categories even though real pairs were detected (the separate pendingCount is accurate, but the category split is not) — a misleading, fabricated success message.
- **Recommended solution:** Capture the SQL function's actual return row (via ExecuteRawSqlAsync's typed overload or a raw ADO reader) and populate NameDobPairs/NameMobilePairs/NameEmailPairs from it instead of hardcoding zero.
- **Production impact:** Fabricated statistics shown in detection-run feedback once the feature is deployed.
- **Business impact:** Erodes user trust in the dedup tool's reporting the first time someone notices '0 name+DOB pairs' next to a queue that clearly has some.
- **Technical impact:** Dead code path — the raw SQL call's result set is never read; a `.ToListAsync()`/reader step is entirely missing.
- **Evidence:** Base.Application/Business/ContactBusiness/DuplicateContacts/Commands/DetectDuplicateContacts.cs:9-12 (result shape) and :46-50 (hardcoded 0,0,0 despite SQL function computing real counts)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #311 · Contact — Tags & Segmentation — Tag assignment/removal (UpdateContact)  — `Low`

- **Module:** Contacts / CRM  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** UpdateContact.cs:460-498 reconciles a contact's ContactTags on every save: unmatched existing tags are physically removed via `dbContext.ContactTags.Remove(existing)` (line 473) rather than soft-deleted, despite ContactTag inheriting the base Entity's IsDeleted/IsActive audit fields.
- **Gap identified:** Tag removal bypasses the soft-delete convention used pervasively elsewhere in this codebase (e.g. Contact merge deactivation, DuplicateContact resolution) — the row (including AssignedDate/AssignedByUserId) is gone from the database the moment a tag is unchecked and saved.
- **Why it's a problem:** There is no way to audit or restore which tags a contact previously had, or who assigned/removed them and when — a segmentation/marketing-history gap, and an inconsistency that will surprise anyone relying on the codebase's otherwise-uniform soft-delete pattern for compliance/audit purposes.
- **Recommended solution:** Switch to soft-delete (`existing.IsDeleted = true; existing.IsActive = false;`) consistent with the rest of the Contact module, and add a RemovedByUserId/RemovedDate pair if tag-history audit is required.
- **Production impact:** Tag assignment history is unrecoverable once a tag is removed and the contact saved.
- **Business impact:** Loss of segmentation audit trail; cannot answer 'was this donor ever tagged X' after the fact.
- **Technical impact:** Inconsistent delete semantics between ContactTag and virtually every other Contact-related child entity in the same module.
- **Evidence:** Base.Application/Business/ContactBusiness/Contacts/Commands/UpdateContact.cs:460-498, specifically line 473 (`dbContext.ContactTags.Remove(existing)`)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #312 · Contact Dashboard / Contact list / Duplicate Detection — EngagementScore — stub field  — `Low`

- **Module:** Contacts / CRM  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** GetContact.cs:213 sets `dto.EngagementScore = 0; // engagementScore — SERVICE_PLACEHOLDER (ISSUE-3)` unconditionally for every row in the Contacts list; GetDuplicateContacts.cs similarly sets `dto.ContactFromEngagementScore = null;` with an in-code note that 'Contact.cs does NOT yet define EngagementScore column ... Leave null until real column is added.'
- **Gap identified:** EngagementScore is not backed by any real computed or stored value anywhere in the Contact module — it is a permanent hardcoded placeholder in at least two call sites.
- **Why it's a problem:** If EngagementScore is surfaced anywhere in the Contact Dashboard, Contact list column, or Duplicate Detection confidence comparison (all in this module's explicit scope), it will display as uniformly 0/blank for every contact, which is either misleading (looks like a real score of zero engagement) or, if hidden, a shipped-but-non-functional feature.
- **Recommended solution:** Either implement the real EngagementScore computation (donation recency/frequency + interaction signals) and add the backing column, or remove the field from DTOs/UI entirely until it's implemented, to avoid displaying fabricated data.
- **Production impact:** A visible KPI/column field is permanently fake (always zero/null) across at least two screens.
- **Business impact:** Staff relying on 'engagement score' to prioritize donor outreach get no real signal, undermining the CRM's segmentation value proposition.
- **Technical impact:** Placeholder acknowledged in-code (SERVICE_PLACEHOLDER comment) but not tracked as a blocking gap for release.
- **Evidence:** Base.Application/Business/ContactBusiness/Contacts/Queries/GetContact.cs:212-213 (`dto.EngagementScore = 0; // SERVICE_PLACEHOLDER (ISSUE-3)`); GetDuplicateContacts.cs (`dto.ContactFromEngagementScore = null;` with comment that Contact.cs has no EngagementScore column)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #313 · Duplicate Detection (GraphQL mutations, broadly all Contact mutations) — Exception message exposure  — `Low`

- **Module:** Contacts / CRM  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** DuplicateContactMutations.cs wraps every mutation (CreateDuplicateContact, MergeContacts, DetectDuplicateContacts, IgnoreDuplicateContact, NotDuplicateContact) in `catch (Exception ex) { return BaseApiResponse<T>.Error(ex.Message); }` (lines 26-29, 48-51, 70-73, 92-95, 117-120), returning the raw .NET/Postgres exception message directly in the API response.
- **Gap identified:** No sanitization/mapping layer converts internal exception text (e.g. 'relation "corg.fn_merge_contacts" does not exist', SQL constraint names, stack-adjacent details) into a safe, user-facing message before it reaches the GraphQL client.
- **Why it's a problem:** Raw exception messages can leak internal schema details (table/function/constraint names, ORM internals) to the frontend, which is both a minor information-disclosure risk and a poor UX (users see Postgres jargon instead of actionable guidance) — most acutely visible right now given Finding #1 (missing SQL functions) will surface exactly this kind of raw DB error to end users.
- **Recommended solution:** Introduce a shared exception-to-user-message mapper (already partially present via InternalServerException/BadRequestException/NotFoundException in other handlers) and ensure all Contact-area GraphQL mutations funnel through it instead of raw ex.Message.
- **Production impact:** Internal error detail leakage in mutation responses across the Contact module.
- **Business impact:** Minor security-hygiene and support-burden issue (confusing error text reaches end users).
- **Technical impact:** Consistent anti-pattern across all 5 mutations in this file; likely repeated in sibling mutation files across the module.
- **Evidence:** Base.API/EndPoints/Contact/Mutations/DuplicateContactMutations.cs:26-29, 48-51, 70-73, 92-95, 117-120 (catch (Exception ex) => Error(ex.Message) in every mutation)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #314 · Family — SetContactAsFamilyHead — FamilyCode generation  — `Low`

- **Module:** Contacts / CRM  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** SetContactAsFamilyHeadHandler (Base.Application/Business/ContactBusiness/Contacts/Commands/SetContactAsFamilyHead.cs:51-61) generates the next FamilyCode by loading ALL existing FamilyCode strings into memory (`dbContext.Families.Where(f => f.IsDeleted == false).Select(f => f.FamilyCode).ToListAsync(...)`), then computing `max(parsed)+1` in a foreach loop with no transaction/locking around the subsequent insert.
- **Gap identified:** This is a classic read-then-insert race condition: two concurrent 'Set as Family Head' actions (a realistic scenario during bulk donor onboarding or two staff working simultaneously) can both read the same max code and attempt to insert families with the same FamilyCode.
- **Why it's a problem:** Duplicate FamilyCode values break any downstream code expecting FamilyCode to be a stable unique business identifier (receipts, exports, reports keyed by family code), and the codebase already has a purpose-built NumberSequenceGenerator (used for 20+ other entities per project convention) that Family was not migrated onto.
- **Recommended solution:** Migrate Family code generation onto the existing NumberSequenceGenerator (per-tenant sequence with proper locking), consistent with Case/Pledge/Event/Contact and the other 20 entities already on this pattern.
- **Production impact:** Rare but possible duplicate FamilyCode under concurrent family-creation load.
- **Business impact:** Ambiguous family identifiers in exports/receipts/reports if a collision occurs.
- **Technical impact:** Full-table scan of FamilyCode on every single family-head assignment (also a minor performance concern as Family volume grows).
- **Evidence:** Base.Application/Business/ContactBusiness/Contacts/Commands/SetContactAsFamilyHead.cs:51-61 (in-memory max+1 scan, no locking/sequence)
- **Reviewer note:** not adversarially verified (Medium/Low)

## Background Services & Scheduled Jobs

### #9 · Online Donations > Recurring Donation Schedules — PayU recurring-charge failure escalation (PASTDUE circuit breaker)  — `Critical`

- **Module:** Background Services & Scheduled Jobs  |  **Category:** payments  |  **Verification:** ADJUSTED
- **Current implementation:** PayURecurringChargeService.ProcessOneAsync increments ConsecutiveFailures on each PayU decline; once it reaches MaxConsecutiveFailures (4), it attempts to resolve RECURRINGSCHEDULESTATUS/PASTDUE|PAST_DUE via MasterData lookup and, only if found, flips ScheduleStatusId.
- **Gap identified:** Confirmed and actually WORSE than originally described. The candidate query (PayURecurringChargeService.cs:59-66) excludes schedules by raw `s.ConsecutiveFailures < MaxConsecutiveFailures`, independent of whether the PASTDUE flip succeeds (lines 156-165, gated on `if (pastDueId != 0)`). Crucially, I traced the actual MasterData seed pipeline: sql-scripts-dyanmic/RecurringDonationSchedule-sqlscripts.sql STEP 7b explicitly CANONICALIZES RECURRINGSCHEDULESTATUS DataValues away from the verbose PaymentGateway-MasterData-seed.sql codes (ACTIVE/PASTDUE/PAUSED/CANCELLED/EXPIRED) into short codes ACT/PAU/CAN/FAIL/EXP/PDU — 'Past Due' becomes DataValue='PDU', NOT 'PASTDUE' or 'PAST_DUE' (lines 610-690). PayURecurringChargeService.cs:160 looks up only {"PASTDUE","PAST_DUE"} — this matches NEITHER the canonicalized 'PDU' code NOR does the rest of the recurring-schedule state machine (Pause='PAU', Cancel='CAN', Retry checks 'FAIL'/'ACT' in RetryRecurringDonationSchedule.cs:45) ever use 'PASTDUE' anywhere. So in a DB that has run the documented canonicalization script (the one written specifically for this screen's BE), pastDueId is ALWAYS 0, the status flip NEVER happens, and the schedule remains at whatever status it had (typically 'ACT'/Active) forever while being silently excluded from all future charge attempts. Additionally, the admin-facing 'Failed Payments Alert Banner' (GetRecurringDonationScheduleFailedAlert.cs:41) only surfaces schedules with ScheduleStatus.DataValue=='FAIL' — a PASTDUE-flagged schedule (even in the rare seed variant where 'PASTDUE' literally exists) would never appear in this banner either, since PASTDUE != FAIL. And the only manual reactivation path, RetryRecurringDonationScheduleCommand, explicitly rejects any status other than 'FAIL' or 'ACT' (line 45-46: throws BadRequestException otherwise) — so a schedule parked at a genuine PASTDUE/PDU status has no admin UI path back to Active either. This is a real, confirmed, multi-layer disconnect between the PayU failure path and the rest of the recurring-donation state machine.
- **Why it's a problem:** A donor's recurring gift can go permanently and silently dead after 4 bad charge days (e.g. a temporary card issue) with the schedule still displaying as Active in the grid — no automatic recovery, no visible alert-banner flag (banner only watches 'FAIL', not 'PASTDUE'), no donor notification, and even if staff notice, the Retry action refuses to touch it. This is a hard, undetectable revenue leak for donation-funded NGOs.
- **Recommended solution:** (1) Fix the immediate bug: change PayURecurringChargeService to resolve/flip to the SAME status code convention the rest of the module uses ('FAIL', not 'PASTDUE'/'PAST_DUE') so the existing alert banner and Retry command both pick it up correctly — this is a low-risk, high-value one-line-lookup fix. (2) Decouple the exclusion filter from the status-flip success — exclude candidates by ScheduleStatusId (post-flip) rather than raw ConsecutiveFailures, so a failed status transition never silently orphans the row. (3) Add a dunning notification (email/SMS to donor + staff alert) when ConsecutiveFailures crosses the threshold. (4) Confirm RetryRecurringDonationSchedule's allowed-status check is updated in lockstep with whatever code PayU writes.
- **Production impact:** Recurring donations silently stop being charged after 4 failed cycles with no operator visibility — confirmed the status-code mismatch means this is not an edge case (missing seed) but the LIKELY case for any DB that has run the documented canonicalization script for this exact screen.
- **Business impact:** Direct, silent loss of recurring donation revenue with no donor communication — donors believe they're still giving; the NGO believes the schedule is still active; and even the one existing alert banner built specifically to catch failing schedules cannot see this failure mode.
- **Technical impact:** No compensating job exists to detect or re-surface stuck schedules; ConsecutiveFailures never resets outside of a successful charge or the (inapplicable) Retry command; two disjoint status-code vocabularies coexist in the same state machine.
- **Evidence:** Base.Application/Services/RecurringDonations/PayURecurringChargeService.cs:59-66 (filter), 156-165 (conditional PASTDUE flip), 37 (MaxConsecutiveFailures=4); sql-scripts-dyanmic/RecurringDonationSchedule-sqlscripts.sql:610-690 (STEP 7b canonicalizes Past Due → DataValue='PDU', confirms 'PASTDUE'/'PAST_DUE' lookup can never match post-canonicalization); Base.Application/Business/DonationBusiness/RecurringDonationSchedules/Queries/GetRecurringDonationScheduleFailedAlert.cs:41 (alert banner filters DataValue=='FAIL' only); Base.Application/Business/DonationBusiness/RecurringDonationSchedules/Commands/RetryRecurringDonationSchedule.cs:44-46 (Retry rejects any status other than FAIL/ACT); grep of Email|Sms|Notif|Send across PayURecurringChargeService.cs returned zero matches.

### #10 · Reports > Scheduled Reports — Automated report generation & delivery  — `Critical`

- **Module:** Background Services & Scheduled Jobs  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** CreateScheduledReport/UpdateScheduledReport correctly compute and persist CronExpression and NextRunDate via CronHelper on every save, and the UI exposes a 'Run Now' action.
- **Gap identified:** There is NO execution engine anywhere in the codebase for Scheduled Reports. RunScheduledReportNowHandler (Base.Application/Business/ReportBusiness/ScheduledReports/RunNowCommand/RunScheduledReportNow.cs:38-59) only inserts a ScheduledReportRun row with Status=RUNNING and returns — the class doc comment literally says 'SERVICE_PLACEHOLDER: Hangfire/recurring-job infra not yet wired' and 'Actual report generation, email delivery, and shared-drive upload are deferred'. No Hangfire recurring job scans ScheduledReport.NextRunDate anywhere either — confirmed via grep across Base.API for RecurringJobManager/AddOrUpdate/ScheduledReport, which returns only the mutation/query GraphQL endpoints plus the stub handler; the only recurring-job registration extensions that exist in Base.API/Extensions are EventCommunicationDispatcherRegistrationExtension.cs, PayURecurringChargeRegistrationExtension.cs, and ImportScheduleRecoveryExtension.cs.
- **Why it's a problem:** The feature is 100% non-functional end-to-end: admins can configure a full recurring report schedule (cron, recipients, format) that silently does nothing, forever, with no error surfaced to the user — the row just sits at RUNNING with no completion, no file, no email. This is worse than 'manual-only' (like Renewal Reminders) because even the manual trigger is a stub.
- **Recommended solution:** Either hide/disable the Scheduled Reports feature entirely until built, or implement: (1) the actual report-generation + delivery pipeline behind RunScheduledReportNow, and (2) a Hangfire recurring poller (or per-report AddOrUpdate at Create/Update time, mirroring PayURecurringChargeRegistrationExtension.cs's pattern) that fires at NextRunDate and updates ScheduledReportRun to Completed/Failed.
- **Production impact:** Any tenant that configures a scheduled report gets zero output and no failure signal — a completely silent dead feature in production.
- **Business impact:** NGOs relying on automated board/donor/compliance reports will miss them entirely with no warning, undermining trust in the reporting module.
- **Technical impact:** ScheduledReportRun table accumulates permanently-RUNNING rows with no terminal state, polluting run-history queries and dashboards.
- **Evidence:** Base.Application/Business/ReportBusiness/ScheduledReports/RunNowCommand/RunScheduledReportNow.cs:5-10,38-59 (verified: handler only Adds a ScheduledReportRun with StatusId=RUNNING and SaveChangesAsync, no report generation/delivery code at all); grep of 'RecurringJobManager|AddOrUpdate|ScheduledReport' across Base.API confirms zero recurring-job registrations for ScheduledReport (only ScheduledReportMutations.cs/ScheduledReportQueries.cs GraphQL endpoints, no job wiring).

### #96 · Cross-cutting — all Hangfire recurring jobs — Production job observability & alerting  — `High`

- **Module:** Background Services & Scheduled Jobs  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** Hangfire is wired with persistent PostgreSQL storage (SchemaName=hangfire) so job history/state survives restarts.
- **Gap identified:** Confirmed: Base.API/Program.cs:56-60 wraps BOTH `await app.InitialiseDatabaseAsync()` and `app.UseHangfireDashboard("/hangfire")` inside `if (app.Environment.IsDevelopment())` — in Production there is no dashboard route registered at all (verified this is the only UseHangfireDashboard call in the entire codebase, and no IDashboardAuthorizationFilter/DashboardOptions exists anywhere to gate it for admin-only Production access instead). Confirmed [AutomaticRetry(Attempts = 0)] on PayURecurringChargeService.cs:39, EventCommunicationDispatcher.cs:62, OnlineDonationMapJobRunner.cs:35, ImportExecutionService.cs:55, ImportScheduledExecutionService.cs:39. Confirmed zero Sentry/ApplicationInsights/webhook-on-job-failure integration anywhere (grep across Base.* for sentry/applicationinsights/IElectStateFilter/OnStateApplied returned no hits related to job failure alerting — only unrelated Slack-webhook fields on PrayerRequestPage, a donor-facing SERVICE_PLACEHOLDER feature). Program.cs confirms Serilog is configured with only Console + File sinks (lines 11-15), no external log/alerting sink.
- **Why it's a problem:** In production, the only way to discover a payment/communication/FX job has been silently failing for days is to SSH into the server and grep log files — there is no dashboard, no alert, no proactive detection for money-critical or donor-critical automation.
- **Recommended solution:** Gate the Hangfire dashboard behind an authenticated admin-only route in Production (custom IDashboardAuthorizationFilter checking a superadmin claim) instead of `IsDevelopment()`, and add a lightweight alerting hook (e.g. a Hangfire IElectStateFilter / failure filter that fires an email/webhook to ops when any job transitions to Failed) at minimum for the payments, FX, and communication jobs.
- **Production impact:** Zero production visibility into background job health; failures self-heal at best after 24h (next cron tick) with nobody notified.
- **Business impact:** Payment/donation and communication failures can persist undetected across multiple business days.
- **Technical impact:** Diagnosis requires manual log spelunking on the box; no queryable job-failure history is available to support staff in Production.
- **Evidence:** Base.API/Program.cs:56-60 (`if (app.Environment.IsDevelopment()) { await app.InitialiseDatabaseAsync(); app.UseHangfireDashboard("/hangfire"); }`, and lines 8-15 Serilog Console+File only); PayURecurringChargeService.cs:39 and EventCommunicationDispatcher.cs:62 both `[AutomaticRetry(Attempts = 0)]`; grep confirms no other UseHangfireDashboard call and no Sentry/AppInsights/failure-webhook integration in Base.API/Base.Application/Base.Support.

### #97 · Membership > Renewals — Automated renewal reminder dispatch  — `High`

- **Module:** Background Services & Scheduled Jobs  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** RenewalReminderJobService.ProcessBulkRemindersAsync is a Hangfire job, but it is only ever enqueued from SendBulkRenewalRemindersHandler, which requires an authenticated staff user clicking 'Send Reminders' on the Renewals grid ([CustomAuthorize(..., Permissions.Modify)]).
- **Gap identified:** Verified: SendBulkRenewalRemindersCommand (Base.Application/Business/MemBusiness/MembershipRenewals/Commands/SendBulkRenewalReminders.cs:12,29-33) is decorated [CustomAuthorize(DecoratorMemModules.MembershipRenewal, Permissions.Modify)] and its handler only calls jobClient.Enqueue<IRenewalReminderJobService>(...) once, in response to the command — there is no self-scheduling. IRenewalReminderJobService is registered only as a scoped DI service (Base.API/DependencyInjection.cs:177: services.AddScoped<IRenewalReminderJobService, RenewalReminderJobService>()) — this is NOT a Hangfire recurring-job registration, just constructor wiring. Grep of RenewalReminder across Base.API found no RecurringJobManager.AddOrUpdate call anywhere; the only cron-based recurring jobs registered are PayURecurringChargeRegistrationExtension.cs and EventCommunicationDispatcherRegistrationExtension.cs. RenewalReminderJobService.cs:13-16's own doc comment confirms it 'Processes bulk renewal reminder sends as a single Hangfire background job' triggered per-call.
- **Why it's a problem:** Renewal reminders are inherently time-sensitive (member lapses without reminder), yet the only trigger is a human remembering to open the grid and click Send — there is no safety net if staff forget or are on leave, unlike PayU and Event Communications which are fully automated on daily cron.
- **Recommended solution:** Register a daily Hangfire recurring job (mirroring PayURecurringChargeRegistrationExtension.cs) that runs the same filter logic as SendBulkRenewalRemindersHandler per company/tenant and auto-enqueues ProcessBulkRemindersAsync for due renewals, with staff retaining the manual button for ad-hoc resends.
- **Production impact:** Renewal reminders will only go out when staff manually remember to trigger them per company, every time.
- **Business impact:** Members lapse without warning, directly hurting membership retention revenue — the exact scenario reminders exist to prevent.
- **Technical impact:** No missed-run/backoff concept applies because there is no run to miss — the automation layer simply does not exist.
- **Evidence:** Base.Application/Business/MemBusiness/MembershipRenewals/Commands/SendBulkRenewalReminders.cs:12,29-33,110-123 (manual-only Modify-gated command, IBackgroundJobClient.Enqueue only); Base.Support/Mem/RenewalReminderJobService.cs:13-17; Base.API/DependencyInjection.cs:176-177 (DI registration only, confirmed not a recurring-job call); no matching AddOrUpdate found anywhere in Base.API/Extensions/*.cs for renewal reminders.

### #201 · Cross-cutting — Audit Log pipeline — In-memory audit queue durability  — `Medium`

- **Module:** Background Services & Scheduled Jobs  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** AuditQueueDrainer is a BackgroundService draining an in-memory bounded IAuditQueue (max batch 50, max wait 500ms) into app.AuditLogs, with a final best-effort drain on shutdown capped at 5 seconds.
- **Gap identified:** IAuditQueue.TryEnqueue silently drops the oldest entry on overflow (documented as 'audit is best-effort, never blocks the caller') and PersistBatchAsync's catch block drops the whole failed batch with only a log line — there is no dead-letter queue, no retry, and the codebase's own doc comment flags this as a known gap (ISSUE-17: AuditEventId + UNIQUE dedup for at-least-once semantics) that has not been implemented.
- **Why it's a problem:** Audit logs are a compliance/traceability surface (who changed what, when) for a multi-tenant NGO platform handling donor and beneficiary PII/financial data; silent drops under load or on any DB write failure mean gaps in the audit trail that would only be discovered during an incident investigation, when it's too late.
- **Recommended solution:** Implement the already-identified ISSUE-17 fix (durable outbox/dead-letter with AuditEventId + UNIQUE dedup) at least for security- and payment-sensitive audit events, even if lower-value UI-click audits remain best-effort.
- **Production impact:** Audit trail can silently lose entries under queue overflow or transient DB failures, with no alert or backfill path.
- **Business impact:** Compliance/forensic gaps in the audit trail for a platform handling donor financial data.
- **Technical impact:** No dead-letter/retry exists; a batch write failure means those audit rows are gone permanently.
- **Evidence:** Base.Infrastructure/HostedServices/AuditQueueDrainer.cs (full file, 107 lines: MaxBatchSize=50, MaxWait=500ms, 5-second shutdown drain via `new CancellationTokenSource(TimeSpan.FromSeconds(5))`, PersistBatchAsync catch → rows dropped with log only); Base.Application/Common/Interfaces/IAuditQueue.cs (full file, 42 lines: 'Buffer is bounded (drops oldest on overflow with a warning) — audit is best-effort, never blocks the caller').
- **Reviewer note:** not adversarially verified (Medium/Low)

### #202 · Cross-cutting — job registration at startup — Recurring-job registration failure handling  — `Medium`

- **Module:** Background Services & Scheduled Jobs  |  **Category:** ops  |  **Verification:** CONFIRMED
- **Current implementation:** PayURecurringChargeRegistrationExtension, EventCommunicationDispatcherRegistrationExtension, and ImportScheduleRecoveryExtension each wrap their `IRecurringJobManager.AddOrUpdate(...)` startup call in a try/catch that logs only a warning on failure and lets the app continue starting.
- **Gap identified:** If cron registration itself throws at startup (e.g. Hangfire storage transiently unavailable during a deploy, or TimeZoneInfo.FindSystemTimeZoneById throwing for a bad TimeZoneId), the entire automated pipeline for that job (daily PayU charges, daily event communications, or all recovered import schedules) is silently never registered for that app lifetime — with only a log line, no alert, no retry-at-next-startup-only-if-fixed mechanism, and no health-check failure.
- **Why it's a problem:** A transient failure during exactly the moment of a deploy can permanently disable an entire day's (or until next restart's) worth of automated recurring donations, event reminders, or scheduled imports with zero operational signal beyond a warning-level log line most teams don't alert on.
- **Recommended solution:** Promote registration failures to a health-check (e.g. IHealthCheck reporting Unhealthy) so orchestration/monitoring can detect a bad deploy, and/or retry registration with backoff instead of swallowing the exception permanently for the process lifetime.
- **Production impact:** A single transient error at boot time can silently disable core recurring automation for the life of that app instance.
- **Business impact:** Donations/communications may not process for an entire day undetected if a bad deploy coincides with a Hangfire storage hiccup.
- **Technical impact:** No compensating control exists to detect or recover from a failed AddOrUpdate call; the only signal is a LogWarning.
- **Evidence:** Base.API/Extensions/PayURecurringChargeRegistrationExtension.cs (catch (Exception ex) { logger.LogWarning(ex, "Failed to register PayU SI recurring-charge cron job."); }); Base.API/Extensions/EventCommunicationDispatcherRegistrationExtension.cs (identical pattern); Base.API/Extensions/ImportScheduleRecoveryExtension.cs:58-61 (catch (Exception ex) { logger.LogWarning(ex, "Failed to recover import schedule jobs on startup"); }).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #203 · Events > Event Communications (reminders/feedback/announcements) — Daily event-communication dispatcher query scalability  — `Medium`

- **Module:** Background Services & Scheduled Jobs  |  **Category:** performance  |  **Verification:** CONFIRMED
- **Current implementation:** EventCommunicationDispatcher.ProcessDueEventCommunicationsAsync runs daily at 03:00 UTC and loads `dbContext.EventRegistrationPages.AsNoTracking().Include(p => p.Event).Where(p => p.IsDeleted == false && p.Event.IsDeleted == false).ToListAsync(ct)` with the tenant filter disabled (httpContextAccessor.HttpContext = null) to scan across ALL companies.
- **Gap identified:** This query has no due-date filtering at the SQL level at all — it loads every non-deleted EventRegistrationPage/Event across every tenant into memory, then applies feedback-due/reminder-due/announcement-due logic in-memory afterward, and issues a separate SaveChangesAsync per page rather than batching.
- **Why it's a problem:** As tenant count and event volume grow, this daily job's memory footprint and DB round-trip count grow unbounded and linearly with total historical event pages platform-wide (not just due ones), risking slow runs, memory pressure, and eventually job timeouts that could cause partial nightly communication runs.
- **Recommended solution:** Push the due-date filters (reminder/feedback/announcement due-date <= now, not yet sent) into the SQL WHERE clause so only actually-due rows are materialized, and batch SaveChanges per company or per N rows instead of per page.
- **Production impact:** Currently fine at low tenant/event volume; degrades as the platform scales — a known scaling cliff, not yet hit.
- **Business impact:** Risk of delayed or incomplete daily donor/attendee communications once tenant volume grows.
- **Technical impact:** Full-table cross-tenant scan with in-memory filtering plus per-row SaveChangesAsync round trips.
- **Evidence:** Base.Application/Services/EventCommunications/EventCommunicationDispatcher.cs (full file, 411 lines, read earlier in session): unfiltered `EventRegistrationPages...Where(p => p.IsDeleted == false && p.Event.IsDeleted == false).ToListAsync(ct)` query with all reminder/feedback/announcement due-date checks applied afterward in memory; `httpContextAccessor.HttpContext = null` used to bypass the tenant EF filter for the cross-tenant scan.
- **Reviewer note:** not adversarially verified (Medium/Low)

### #204 · System Settings > Currency / FX — OpenExchangeRatesSyncJob missed-run recovery  — `Medium`

- **Module:** Background Services & Scheduled Jobs  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** A bare IHostedService (not Hangfire) runs a while-loop that computes the next 04:00 UTC run via GetNextRunTime and Task.Delay(delay, ct) until it fires.
- **Gap identified:** `GetNextRunTime` only ever returns today-at-4am (if now < 4am) or tomorrow-at-4am (otherwise) — if the app restarts at any time after 4am on a given day (deploy, crash, scale event), that day's sync is permanently skipped with no catch-up logic; the job simply waits until the next day's 4am.
- **Why it's a problem:** FX rates (used for cross-currency donation conversion, per the FX direct-pair snapshot design) can go a full extra day stale after any restart that happens to land after 4am — a very common deploy window — silently, since the skip is not logged as an anomaly, just treated as normal 'next run tomorrow' scheduling.
- **Recommended solution:** On startup, check whether today's sync already ran (e.g. a LastSyncedDate marker) and if not, run immediately once before falling back to the daily 4am schedule — turning this into a proper missed-run catch-up rather than a fixed timer.
- **Production impact:** Any restart after 4am UTC costs up to ~24h of stale FX rates with no operator awareness.
- **Business impact:** Donations processed in non-default currencies during the stale window convert using outdated rates, a direct financial-accuracy issue for multi-currency NGOs.
- **Technical impact:** No persisted 'last successful sync' check-and-catch-up exists; the loop is purely a fixed-interval timer.
- **Evidence:** Base.Infrastructure/HostedServices/OpenExchangeRatesSyncJob.cs:66-99 (RunScheduledLoopAsync using GetNextRunTime + Task.Delay), :101-106 (GetNextRunTime: `var todayRun = now.Date.AddHours(4); return now < todayRun ? todayRun : todayRun.AddDays(1);`).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #205 · System Settings > Currency / FX — OpenExchangeRatesSyncJob concurrency safety under horizontal scaling  — `Medium`

- **Module:** Background Services & Scheduled Jobs  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** OpenExchangeRatesSyncJob is a plain ASP.NET Core IHostedService started via app.Services (not routed through Hangfire's distributed job queue), with the 04:00 UTC timer loop living independently inside every process that hosts the API.
- **Gap identified:** There is no distributed lock (Hangfire offers one via its storage; this job bypasses Hangfire entirely) coordinating the timer across instances. If the API is horizontally scaled to more than one instance, every instance runs its own identical RunScheduledLoopAsync and will independently call RunOnceAsync at ~04:00 UTC, all writing to CurrencyConversions concurrently.
- **Why it's a problem:** Duplicate/racing writes to the shared CurrencyConversions table from multiple instances at the same moment can cause redundant API calls to the OpenExchangeRates provider (extra cost/rate-limit risk) and potential write races depending on the upsert logic's concurrency semantics.
- **Recommended solution:** Move FX sync into a Hangfire recurring job (like every other scheduled job in the codebase) so Hangfire's distributed locking naturally prevents multi-instance duplication, or add an explicit distributed lock (e.g. Postgres advisory lock) around RunOnceAsync.
- **Production impact:** Only manifests once the API is scaled beyond a single instance, but the codebase shows no distributed-lock protection for this specific job unlike everything else which is Hangfire-coordinated.
- **Business impact:** Potential duplicate external-API billing/rate-limit consumption and a currency-data race under scale-out.
- **Technical impact:** This is the ONLY scheduled job in the codebase not running through Hangfire's coordination layer, breaking the otherwise-consistent single-engine pattern.
- **Evidence:** Base.Infrastructure/HostedServices/OpenExchangeRatesSyncJob.cs (IHostedService StartAsync/StopAsync/RunScheduledLoopAsync, no IRecurringJobManager/Hangfire usage anywhere in the file, confirmed via full file read of all 377 lines during earlier investigation).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #306 · Cross-cutting — Import execution failure handling — ImportScheduledExecutionService retry/backoff for failed import sessions  — `Low`

- **Module:** Background Services & Scheduled Jobs  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** PostExecutionReviewAsync re-schedules Failed sessions (ExecutionAttempts < MaxRetryAttempts=3) by setting Status=Scheduled and ScheduledRunTime = DateTime.UtcNow.Date.AddDays(1), and permanently fails sessions once ExecutionAttempts >= 3.
- **Gap identified:** The retry delay is a flat 'always tomorrow, same time-of-day' with no exponential backoff and, more importantly, the next cron tick's session-selection query (`ExecuteScheduledImportsAsync`, lines 68-73) selects ALL sessions with `Status == ImportSessionStatus.Scheduled` for that ImportScheduleJobId with no check against ScheduledRunTime — meaning the 'tomorrow' retry delay is enforced only by virtue of the cron itself running once daily, not by any explicit due-time gate in the query.
- **Why it's a problem:** If the underlying ImportScheduleJob's cron were ever changed to run more frequently than daily (e.g. hourly, which the CronExpression field allows arbitrarily), a session that was 'rescheduled for tomorrow' after a failure would actually be picked up and retried on the very next (hourly) tick instead of waiting a day — silently breaking the intended backoff.
- **Recommended solution:** Add an explicit `s.ScheduledRunTime <= now` predicate to the session-selection query in ExecuteScheduledImportsAsync so the retry delay is enforced by data, not by an implicit assumption that the job's own cron cadence is daily.
- **Production impact:** Currently harmless because all observed ImportScheduleJob crons are daily ('0 0 * * *'), but the code has no safeguard if that assumption changes.
- **Business impact:** Minimal today; would surface as unexpected rapid-retry storms against a source system if schedules were ever tightened.
- **Technical impact:** Retry/backoff timing is implicit (coupled to cron cadence) rather than explicit (data-driven), a latent correctness gap.
- **Evidence:** Base.Support/Import/Services/ImportScheduledExecutionService.cs:68-73 (session query filters only on ImportScheduleJobId + Status==Scheduled, no ScheduledRunTime predicate), :308-317 (PostExecutionReviewAsync sets ScheduledRunTime = DateTime.UtcNow.Date.AddDays(1) as the sole backoff mechanism).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #307 · Cross-cutting — Import scheduling — Import schedule recovery vs. dispatcher pattern (positive contrast baseline)  — `Low`

- **Module:** Background Services & Scheduled Jobs  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** ImportScheduleRecoveryExtension.RecoverImportScheduleJobsAsync re-registers all active per-grid ImportScheduleJob cron entries from the DB at startup (ensuring Hangfire recurring jobs survive restarts/redeploys) and also registers the nightly DropExpiredStagingTablesJob cleanup — this pattern is done correctly and is the strongest example in the codebase of durable, self-healing job registration.
- **Gap identified:** This is not itself a defect, but its existence highlights the inconsistency: only Imports and Online-Donation-Map jobs have this DB-driven re-registration-on-restart pattern; PayU recurring charges and Event Communications rely solely on Hangfire's own persistent recurring-job storage (registered once at startup, not re-derived per-tenant from a DB source of truth) — acceptable since they are single global crons, but it means the codebase has two different reliability models for 'recurring job survives restart' without a documented rationale for why.
- **Why it's a problem:** Inconsistent patterns across otherwise-similar 'recurring job registration' concerns make it harder for future maintainers to reason about which jobs are safe to assume 'self-recovering' vs. which depend purely on Hangfire's own persistence layer never being wiped/reconfigured.
- **Recommended solution:** Document (in a README or architecture note) which reliability model applies to which job family, so future engineers don't assume uniform behavior across all scheduled jobs.
- **Production impact:** No direct production defect; this is a maintainability/consistency observation.
- **Business impact:** None directly; reduces future engineering risk of miscategorizing job reliability guarantees.
- **Technical impact:** Two distinct 'recurring job survives restart' models coexist without a written contract distinguishing them.
- **Evidence:** Base.API/Extensions/ImportScheduleRecoveryExtension.cs:16-62 (per-tenant per-grid AddOrUpdate re-registration from DB + DropExpiredStagingTablesJob registration) vs. Base.API/Extensions/PayURecurringChargeRegistrationExtension.cs and EventCommunicationDispatcherRegistrationExtension.cs (single static global cron registered once, no DB-driven re-derivation).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #308 · Membership > Renewals — SMS renewal reminder channel  — `Low`

- **Module:** Background Services & Scheduled Jobs  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** RenewalReminderJobService's constructor, ISmsSenderService field, TrySendSmsAsync method, and the SMS-send block inside ProcessSingleRenewalAsync are entirely commented out (lines 3,21,27,41,92-101,164-192), leaving only the Email channel functional.
- **Gap identified:** The class doc comment itself states 'SMS will be activated when configured' — this is a half-built feature. If the frontend or the `channels` parameter on SendBulkRenewalRemindersCommand implies SMS is selectable, staff selecting SMS get silent no-ops with no channel actually attempted (the loop's `attemptedChannels`/`sentChannels` tracking never includes SMS since the code block doesn't execute).
- **Why it's a problem:** Renewal reminders sent as 'Email + SMS' from the UI may in practice only ever be Email, and staff/reporting have no way to know SMS was never actually attempted unless they read the backend code, since the commented-out block also means no failure reason is recorded for the missing channel.
- **Recommended solution:** Either wire up the SMS sending path fully (uncomment + implement ISmsSenderService integration, consistent with the SMS Campaign feature elsewhere in the codebase) or remove SMS as a selectable channel option in the Renewals UI until it is built, to avoid a silent capability gap.
- **Production impact:** Only affects the SMS channel of renewal reminders; Email channel is fully functional.
- **Business impact:** Members relying on SMS reminders never receive them despite the schedule/UI implying multi-channel support.
- **Technical impact:** Dead code paths (entirely commented out) sitting in a production job class.
- **Evidence:** Base.Support/Mem/RenewalReminderJobService.cs:3,21,27,41,92-101,164-192 (all SMS-related code commented out); class doc comment line 15: 'SMS will be activated when configured.'
- **Reviewer note:** not adversarially verified (Medium/Low)

## Fundraising · Campaigns & Intake

### #32 · Donation Confirmation — P2P Campaign donation / CrowdFunding donation (contrast: Online Donation Page) — Post-payment-capture ledger promotion (OnlineDonationStaging -> fund.GlobalDonations)  — `Critical`

- **Module:** Fundraising · Campaigns & Intake  |  **Category:** Data Integrity / Funnel Completeness  |  **Verification:** CONFIRMED
- **Current implementation:** ConfirmP2PDonationHandler and ConfirmCrowdFundDonationHandler write only to fund.OnlineDonationStagings (plus PaymentMethodToken/RecurringDonationSchedule/PaymentTransaction rows for recurring cycles). ConfirmOnlineDonation.cs (ODP) was retrofitted 2026-07-14 (ODP-B5) with PromoteCapturedDonationAsync, which calls PromoteOnlineDonationStagingCommand via an injected IMediator immediately after gateway capture.
- **Gap identified:** P2P and CrowdFund donation confirmations never call PromoteOnlineDonationStagingCommand (or any equivalent) -- captured payments sit in staging only until a staff member manually resolves them via the Donation Inbox (#175). ODP donations are now auto-promoted at capture time; P2P/CrowdFund are not.
- **Why it's a problem:** A captured P2P/CrowdFund payment is real charged money, but it is invisible to every GlobalDonation-based report/rollup/receipt/dashboard until a human notices and resolves it in the inbox (which also requires a ContactId, see Finding 2). Campaign totals, tax receipts, and donor history are wrong/missing for however long staff take to work the queue -- potentially indefinitely for high-volume campaigns.
- **Recommended solution:** Apply the same ODP-B5 pattern to ConfirmP2PDonationHandler and ConfirmCrowdFundDonationHandler: inject IMediator and call PromoteOnlineDonationStagingCommand (non-fatal try/catch, exactly as ConfirmOnlineDonation.cs does) immediately after each gateway captures the charge, for both one-time and recurring branches.
- **Production impact:** Every P2P and CrowdFund donation is captured but absent from the ledger until manual staff intervention; at scale this is a silent money-tracking failure.
- **Business impact:** Fundraising totals/leaderboards/goal-met badges under-report actual raised amounts; donors do not receive ledger-backed tax receipts until manually resolved.
- **Technical impact:** Two near-identical gateway-dispatch handlers diverge from the now-canonical ODP-B5 pattern, widening a feature-parity gap and doubling future maintenance.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/Public/PublicMutations/ConfirmP2PDonation.cs ctor lines 40-47 (no IMediator/email) + doc comment lines 8-24 ('OUT OF SCOPE here'); .../CrowdFunds/Commands/ConfirmCrowdFundDonation.cs ctor lines 39-46 + doc comment lines 8-22; contrast .../OnlineDonationPages/PublicMutations/ConfirmOnlineDonation.cs lines 53-91 (IMediator + PromoteCapturedDonationAsync). Independently confirmed via `git show --stat 59786747` in the PSS_2.0_Backend repo (commit 'fix(online-donation): auto-promote captured payment to globaldonation', 2026-07-14 14:22): ConfirmP2PDonation.cs's only change in that commit was a +26-line campaign-lifecycle re-check, not promotion wiring; ConfirmCrowdFundDonation.cs was not touched at all.

### #33 · Online Donation Page / P2P Donation / CrowdFund Donation — public Initiate mutations — Anti-abuse controls (reCAPTCHA + CSRF) on anonymous public payment-initiation endpoints  — `Critical`

- **Module:** Fundraising · Campaigns & Intake  |  **Category:** Security  |  **Verification:** CONFIRMED
- **Current implementation:** All three Initiate handlers hardcode `var recaptchaScore = 1.0m;` (always passes the `< 0.3m` bot-score check) and validate CSRF only via `req.CsrfToken.Length < 16` -- a presence/shape check with no real cookie/header pairing or server-issued token comparison -- both explicitly marked SERVICE_PLACEHOLDER in surrounding comments.
- **Gap identified:** No real reCAPTCHA verification (no call to a provider's siteverify API) and no real CSRF protection exists on any of the three anonymous, unauthenticated public payment-initiation mutations.
- **Why it's a problem:** These are internet-facing anonymous endpoints that initiate real payment-gateway transactions; without real bot/CSRF defenses they are exposed to card-testing/carding attacks, scripted donation-spam, and cross-site request forgery at production launch.
- **Recommended solution:** Wire a real reCAPTCHA v3 verification call before payment-gateway handoff, and implement true double-submit CSRF (server-issued token bound to a session/cookie, compared server-side) in all three handlers, replacing both SERVICE_PLACEHOLDER stubs before real traffic is accepted.
- **Production impact:** Public payment-initiation endpoints are unprotected against bots/CSRF at launch.
- **Business impact:** Exposure to payment-gateway card-testing/fraud costs, chargebacks, and reputational risk from spam donations.
- **Technical impact:** Three separate copies of the same stub with no shared abstraction -- fixing it requires identical changes to all three files (good candidate for a shared IRecaptchaVerifier/ICsrfValidator service).
- **Evidence:** InitiateOnlineDonation.cs lines 70, 106-120 (CsrfToken validator + hardcoded recaptchaScore, flagged ISSUE-19/ISSUE-9 SERVICE_PLACEHOLDER); InitiateP2PDonation.cs lines 72, 107-119; InitiateCrowdFundDonation.cs lines 77, 112-123 -- identical pattern verified in all three files via direct grep with line numbers.

### #135 · Bulk Donation Import — Historical/offline donation batch import -> fund.GlobalDonations (payment status)  — `High`

- **Module:** Fundraising · Campaigns & Intake  |  **Category:** Data Integrity  |  **Verification:** CONFIRMED
- **Current implementation:** import.execute_bulk_donation_import() always inserts new GlobalDonations with PaymentStatusId defaulted by preference order PENDING > PEN > first-seeded value (lines 151-166, applied at line 301); there is no column/mapping in the import grid to carry an actual historical payment status from the source file.
- **Gap identified:** Every bulk-imported donation, regardless of whether the source system recorded it as already completed/settled, is force-set to PENDING (or whichever master-data row matches that preference order).
- **Why it's a problem:** Bulk import exists specifically to migrate historical donation data. Marking all of it Pending misstates every report/dashboard that filters or sums by PaymentStatus=Completed (revenue reports, giving history, tax-receipt eligibility) for the entire imported dataset until someone bulk-corrects PaymentStatusId afterward.
- **Recommended solution:** Add a PaymentStatus column to the import grid mapping, with a validate-fn lookup resolving it to a MasterDataId (mirroring resolved_contact_id/resolved_currency_id), defaulting to COMPLETED only when the source data is silent -- not unconditionally to PENDING.
- **Production impact:** All bulk-imported historical donations show as financially unresolved in every downstream report.
- **Business impact:** Understated giving/revenue totals and incorrect tax-receipt eligibility for every migrated donor until manually corrected.
- **Technical impact:** Requires extending the import grid schema/validate function, not just the execute function.
- **Evidence:** sql-scripts-dyanmic/BulkDonationImport-fn-execute.sql lines 15-16 (header doc), 151-166 (PaymentStatusId resolution logic preferring PENDING/PEN), 301 (v_default_payment_status_id bound directly into the INSERT).

### #136 · Donation Inbox (#175) — ResolveOnlineDonationStaging — Manual staging -> GlobalDonation promotion, contact-resolution requirement  — `High`

- **Module:** Fundraising · Campaigns & Intake  |  **Category:** Business Logic / Validation  |  **Verification:** ADJUSTED
- **Current implementation:** ResolveOnlineDonationStagingValidator requires Request.ContactId > 0 unconditionally. The handler now has two branches: a 'contact-only re-resolve' path when staging.PromotedGlobalDonationId is already set (auto-promoted -- ODP only today), and a legacy 'full-mint' path for rows never auto-promoted -- P2P/CrowdFund rows always land in the latter, which builds CreateGlobalDonationWithChildrenRequestDto directly from req.ContactId.
- **Gap identified:** Because P2P/CrowdFund staging rows are never auto-promoted (Finding 1), they always require a staff-assigned ContactId to reach the ledger -- there is no path today for an anonymous, contact-less P2P/CrowdFund donation to ever become a GlobalDonation, manual or automatic.
- **Why it's a problem:** Anonymous donations (IsAnonymous flag, no login) are a normal pattern, but for P2P/CrowdFund they are permanently stuck as staging rows requiring a staff member to match or fabricate a contact -- unlike ODP, where PromoteOnlineDonationStagingCommand already tolerates a null ContactId for one-time donations (money reaches the ledger immediately; only IsResolved/contact-linking stays pending).
- **Recommended solution:** Do not relax ResolveOnlineDonationStagingValidator's ContactId>0 rule -- that full-mint path is a deliberate staff-assignment gate. Instead wire PromoteOnlineDonationStagingCommand into the P2P/CrowdFund confirm handlers per Finding 1; its existing null-contact-tolerant one-time-donation logic already solves the anonymous case correctly without touching the manual Resolve validator.
- **Production impact:** Anonymous P2P/CrowdFund donations cannot reach the ledger through any existing path today.
- **Business impact:** Legitimate anonymous donors' contributions are undercounted/omitted from campaign totals indefinitely.
- **Technical impact:** No separate validator change is warranted -- fixing Finding 1 resolves this as a side effect.
- **Evidence:** ResolveOnlineDonationStaging.cs lines 39-54 (validator: ContactId GreaterThan(0)), lines 89-96 and 212-262 (contact-only re-resolve path gated on staging.PromotedGlobalDonationId.HasValue) vs full-mint path from line 264 (uses req.ContactId directly at lines 281, 293); contrast PromoteOnlineDonationStaging.cs lines 185-195, 192-195, 214/224 (resolvedContactId may be null for one-time donations, §④ contact policy) and lines 322-331 (§⑧ two-state writeback tolerates a null ResolvedContactId).
- **Reviewer note:** The validator constraint is real, but this is a corollary of Finding 1 rather than an independent defect -- the system already has a working anonymous-promotion mechanism (PromoteOnlineDonationStagingCommand), it just is not wired into P2P/CrowdFund yet. Priority and recommended fix corrected accordingly; downgraded from a standalone Critical validator-bug framing to a High-priority consequence of Finding 1.

### #137 · Online Donation Page / P2P / CrowdFund — gateway webhook & confirm idempotency — Duplicate-promotion guard for captured donations (UX_GlobalOnlineDonations_Company_GatewayTxn)  — `High`

- **Module:** Fundraising · Campaigns & Intake  |  **Category:** Data Integrity / Concurrency  |  **Verification:** CONFIRMED
- **Current implementation:** PromoteOnlineDonationStagingHandler has an app-level idempotency guard (lines 73-86: no-op return when staging.PromotedGlobalDonationId.HasValue). Its doc comment and the GlobalOnlineDonationConfigurations Fluent-API config both claim this is backed by a DB partial-unique index UX_GlobalOnlineDonations_Company_GatewayTxn on (CompanyId, GatewayTransactionId), filtered WHERE GatewayTransactionId IS NOT NULL AND IsDeleted=false (GlobalOnlineDonationConfiguration.cs lines 74-83).
- **Gap identified:** No EF Core migration exists that actually creates this index in the database. Grepping Base.Infrastructure/Migrations/*.cs and ApplicationDbContextModelSnapshot.cs for 'UX_GlobalOnlineDonations' returns zero matches. `git show --stat` on the commit that introduced this Fluent config (59786747, 'auto-promote captured payment to globaldonation') lists 18 changed files and none is a new/modified Migration file -- the model snapshot was never regenerated for this index.
- **Why it's a problem:** The app-level guard alone is not race-safe: two concurrent webhook deliveries (or a webhook racing a confirm-page callback -- a documented real behavior of Braintree/Razorpay retry policies) can both read PromotedGlobalDonationId as null and both proceed to WriteAsync, minting two GlobalDonations for one captured charge, because no DB constraint exists to make the second insert fail atomically.
- **Recommended solution:** Generate and apply the EF Core migration for UX_GlobalOnlineDonations_Company_GatewayTxn (per the project's user-owned-migrations policy, the developer supplies the spec and the user runs `dotnet ef migrations add`/`database update`) before production traffic; until it exists, treat the idempotency guarantee as advisory/app-level only, not deterministic.
- **Production impact:** A concurrent double-webhook delivery can double-mint a GlobalDonation for one charge with no DB-level backstop.
- **Business impact:** Duplicate donation records inflate campaign totals and could trigger duplicate tax receipts/thank-you communications for a single actual charge.
- **Technical impact:** Fluent-API config and the EF model snapshot are out of sync; the index exists only in C# metadata, not in the actual database schema.
- **Evidence:** Base.Infrastructure/Data/Configurations/DonationConfigurations/GlobalOnlineDonationConfiguration.cs lines 74-83 (index declaration + doc comment); grep of Base.Infrastructure/Migrations/*.cs and ApplicationDbContextModelSnapshot.cs for 'UX_GlobalOnlineDonations' -> no matches; `git show --stat 59786747` in the PSS_2.0_Backend repo confirms no Migrations/*.cs file among the 18 files changed in the commit that added the index config; PromoteOnlineDonationStaging.cs lines 21-24 and 73-86 (app-level guard + doc comment explicitly claiming the DB backstop).

### #138 · Online Donation Page / P2P Campaign donation / CrowdFund donation — post-payment confirmation — Donor receipt/thank-you email on successful donation  — `High`

- **Module:** Fundraising · Campaigns & Intake  |  **Category:** Functional Completeness / Donor Communication  |  **Verification:** CONFIRMED
- **Current implementation:** None of ConfirmP2PDonationHandler, ConfirmCrowdFundDonationHandler, or ConfirmOnlineDonation's handlers inject an email service or dispatch an email command at the point of successful payment capture; each only logs a line such as '[SERVICE_PLACEHOLDER ISSUE-3 email-send] SUCCESS...' instead of actually sending anything.
- **Gap identified:** No donor ever receives an automatic confirmation/receipt email immediately after a successful donation, across all three public funnels (ODP, P2P, CrowdFund), one-time or recurring.
- **Why it's a problem:** A donation confirmation email is baseline expected behavior for any donation platform -- donors expect immediate proof of a successful charge; without it, support burden increases and timely-receipting obligations are unmet.
- **Recommended solution:** Wire the existing shared email-template service (already used for grant/invitation communications per the project's composed-email pattern) into all three Confirm handlers, dispatched non-fatally (never blocking a successful payment response) immediately after capture/promotion.
- **Production impact:** No donor receives a receipt/confirmation for any online donation at launch.
- **Business impact:** Increased support load and reduced donor trust/repeat-giving from the lack of an immediate email receipt.
- **Technical impact:** Same SERVICE_PLACEHOLDER stub duplicated across three handlers; a shared donation-receipt email helper would reduce triplication.
- **Evidence:** ConfirmP2PDonation.cs ctor lines 40-47 (no email/IMediator dependency), log lines 243/336/433 ('[SERVICE_PLACEHOLDER ISSUE-3 email-send] SUCCESS'); ConfirmCrowdFundDonation.cs ctor lines 39-46, log lines 251/344/441. Final sweep: grep across Base.Application/Business/DonationBusiness for IEmailService|EmailSendJob|SendEmailAsync|IEmailTemplateService returns 13 files, all of which are invitation-sending (P2PCampaignPages/CrowdFunds InvitationCommands+Queries) or manual tax-receipt generation (GeneratedTaxReceipts/Commands/SendGeneratedTaxReceipt.cs) -- none tied to the donation-confirmation code path in ConfirmP2PDonation.cs, ConfirmCrowdFundDonation.cs, ConfirmOnlineDonation.cs, or PromoteOnlineDonationStaging.cs.

### #240 · Bulk Donation — Duplicate receipt detection  — `Medium`

- **Module:** Fundraising · Campaigns & Intake  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** BulkDonationImport-fn-validate.sql lines 469-485: a receipt_number that already exists in fund.GlobalDonations for the same CompanyId is flagged only as a WARNING (ValidationStatus=3), which is still eligible for execution (fn-execute.sql line 120 treats ValidationStatus IN (1,3) as importable).
- **Gap identified:** A row whose receipt number exactly matches an existing donation's receipt number is allowed through to insertion by default (Warning, not Invalid/blocked) -- there is no hard uniqueness constraint or block, and no cross-check against OTHER rows within the same import batch (only against already-committed GlobalDonations).
- **Why it's a problem:** Re-uploading the same source file (a very plausible user error, e.g., after a partial-looking run or accidental re-submission) will re-insert every donation a second time with only a soft warning that a human must notice and manually reject row-by-row; there is no batch-level duplicate-file guard either.
- **Recommended solution:** Escalate exact receipt-number collision (same CompanyId) to a hard INVALID (blocking) status rather than a soft Warning, and/or add an intra-batch duplicate check within the same staging table.
- **Production impact:** Re-running or duplicate-uploading a donation file can double-book every donation in it with only a soft warning.
- **Business impact:** Double-counted donation history/revenue, incorrect donor receipts.
- **Technical impact:** No file-level or intra-batch dedup safeguard.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/BulkDonationImport-fn-validate.sql:469-485; PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/BulkDonationImport-fn-execute.sql:118-122
- **Reviewer note:** not adversarially verified (Medium/Low)

### #241 · Bulk Donation Import — Historical/offline donation batch import — currency/FX handling  — `Medium`

- **Module:** Fundraising · Campaigns & Intake  |  **Category:** Data Integrity / Financial Accuracy  |  **Verification:** ADJUSTED
- **Current implementation:** The execute function hardcodes ExchangeRate = 1.0 and BaseCurrencyId = resolved_currency_id for every imported row (doc lines 17-19, code lines 295-297), explicitly labeled 'V1 -- single-currency' in the source comment.
- **Gap identified:** There is no direct-pair FX lookup (unlike PromoteOnlineDonationStaging.cs's fxRateService.GetRateAsync pattern) -- every imported donation is treated as if its transaction currency IS the org's base currency, producing a wrong BaseCurrencyAmount for any row whose currency actually differs from the tenant's configured base currency.
- **Why it's a problem:** For a multi-currency tenant importing historical donations in a non-base currency, base-currency rollups (the entire purpose of BaseCurrencyAmount/BaseCurrencyId in this system's FX architecture) are silently wrong -- not blocked or flagged, just incorrect, because ExchangeRate is force-set to 1.0 regardless of actual currency.
- **Recommended solution:** Resolve BaseCurrencyId from OrgSettings DEFAULT_CURRENCY (as PromoteOnlineDonationStaging.cs does via CurrencyBaseLookup.ResolveBaseCurrencyIdAsync) and look up the direct-pair FX rate for (resolved currency -> base) as of the donation date via the same IFxRateService pattern, falling back to 1.0 only when currencies match or no rate exists.
- **Production impact:** Multi-currency historical imports produce silently wrong base-currency rollups.
- **Business impact:** Consolidated cross-currency reporting is inaccurate for any tenant importing non-base-currency historical donations.
- **Technical impact:** Same-file fix scope as the PaymentStatus gap -- both live in execute_bulk_donation_import and both need the validate-fn/grid mapping extended.
- **Evidence:** sql-scripts-dyanmic/BulkDonationImport-fn-execute.sql lines 17-19 (doc, explicitly 'V1 -- single-currency'), lines 275-276 and 295-297 (BaseCurrencyId/ExchangeRate/BaseCurrencyAmount hardcoding in the INSERT statement).
- **Reviewer note:** Gap confirmed as real, but priority corrected down from the original Critical/High framing: the code's own header comment explicitly scopes this as a documented 'V1 -- single-currency' limitation rather than an undocumented oversight, so it reads as a known, tracked follow-up rather than a production-blocking defect.

### #242 · Crowdfunding — Recurring donation confirm (Braintree/Razorpay/PayU)  — `Medium`

- **Module:** Fundraising · Campaigns & Intake  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** HandleBraintreeRecurringAsync (~line 468), HandleRazorpayRecurringAsync (~line 586), and HandlePayURecurringAsync (~line 810) in ConfirmCrowdFundDonation.cs each perform multiple sequential SaveChangesAsync() calls (PaymentMethodToken -> RecurringDonationSchedule -> RecurringDonationScheduleDistribution -> PaymentTransaction -> schedule stat updates, e.g. lines 713-747 and 857-926) with no enclosing database transaction.
- **Gap identified:** If a later SaveChangesAsync in the same logical recurring-setup sequence throws (e.g., a distribution insert fails FK validation), earlier SaveChangesAsync calls in the same request have already committed, leaving an orphaned PaymentMethodToken and/or a RecurringDonationSchedule with no distribution row.
- **Why it's a problem:** Partial writes leave inconsistent recurring-donation state that is hard to detect and clean up later (a schedule that will bill the donor's card but never distributes/allocates the money correctly, or a payment token with no schedule using it).
- **Recommended solution:** Wrap the multi-step recurring-setup sequence in a single explicit DB transaction (or use the shared execution-strategy pattern already used elsewhere, e.g., IGlobalDonationCompositeWriter) so a failure anywhere rolls back the whole sequence.
- **Production impact:** A transient failure mid-sequence during recurring donation setup can leave orphaned/partial rows.
- **Business impact:** Inconsistent recurring billing records that are difficult to reconcile or support.
- **Technical impact:** No atomicity guarantee across a multi-entity write sequence.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/CrowdFunds/Commands/ConfirmCrowdFundDonation.cs:468-926 (HandleBraintreeRecurringAsync/HandleRazorpayRecurringAsync/HandlePayURecurringAsync, incl. 713-747, 857-926)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #243 · Crowdfunding — Reward tiers / perks / inventory  — `Medium`

- **Module:** Fundraising · Campaigns & Intake  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** CrowdFund.cs entity (143 lines) exposes only GoalAmount plus jsonb string columns (MilestonesJson, UpdatesJson, ImpactBreakdownJson, BeneficiariesJson, AmountChipsJson); CrowdFundDonation.cs is a plain (CrowdFundId, GlobalDonationId) junction with a unique index on GlobalDonationId. A codebase-wide case-insensitive grep for reward|inventory|perk|Quantity|StockCount across all CrowdFund files returns zero real matches (only incidental EF migration-designer false positives).
- **Gap identified:** There is no reward-tier, perk, or inventory/quantity concept modeled anywhere in the Crowdfunding feature -- donors can only give a free-form monetary amount toward a goal, with no perk selection or stock/quantity tracking.
- **Why it's a problem:** This makes the audit's named focus area ('crowdfund inventory decrement atomicity') moot as a technical bug check, but it is a material feature-completeness gap: most production crowdfunding platforms (Kickstarter/GoFundMe-style, which the entity's own field set explicitly mirrors) support reward tiers, and NGOs commonly want to offer perk-based giving tiers.
- **Recommended solution:** If reward-tier crowdfunding is in scope for production, it needs a net-new child entity (CrowdFundRewardTier with quantity/stock, and a donor selection + atomic decrement on donation) designed and built; if out of scope, document that Crowdfunding is goal-based only (no perks) so stakeholders don't discover the gap after go-live.
- **Production impact:** No perk/reward/inventory functionality exists to test or decrement atomically.
- **Business impact:** Feature-parity gap vs. common crowdfunding platform expectations.
- **Technical impact:** N/A -- confirmed absent by design, not a defect in existing code.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/CrowdFund.cs (full file); PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/CrowdFundDonation.cs (full file)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #244 · Online Donation Setup / P2P / Crowdfunding (Initiate) — Cross-instance idempotency for donation initiation  — `Medium`

- **Module:** Fundraising · Campaigns & Intake  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** InitiateCrowdFundDonation.cs (lines 125-137, 627) uses IMemoryCache keyed by the client-supplied IdempotencyKey with a 10-minute TTL, explicitly documented in-code as 'best-effort ... covers sequential retries on the same instance' only.
- **Gap identified:** In any horizontally-scaled deployment (multiple app instances behind a load balancer), a retried Initiate request routed to a different instance bypasses the cache entirely, and a request retried after 10 minutes on the same instance also bypasses it -- so double-submit protection is effectively absent in a realistic production topology.
- **Why it's a problem:** A donor's double-click or a client-side retry-on-timeout can create two separate PENDING staging rows (and, after gateway capture, potentially two charges) with nothing at the DB layer stopping it.
- **Recommended solution:** Move idempotency-key enforcement to a DB-backed unique constraint (e.g., unique index on (CompanyId, IdempotencyKey) on the staging table) or a distributed cache (Redis) shared across instances, as the in-code comment itself recommends.
- **Production impact:** Double-submit protection does not function correctly in a multi-instance production deployment.
- **Business impact:** Risk of duplicate charges/donations from donor double-clicks or client retries.
- **Technical impact:** In-memory cache is instance-local and TTL-bounded, not a durable idempotency guarantee.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/CrowdFunds/Commands/InitiateCrowdFundDonation.cs:125-137,627
- **Reviewer note:** not adversarially verified (Medium/Low)

### #245 · Payment Reconciliation — Run Auto-Reconciliation concurrency safety  — `Medium`

- **Module:** Fundraising · Campaigns & Intake  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** RunAutoReconciliation.cs matches unmatched PaymentTransactions to candidate GlobalDonations in-memory (lines 121-283), committing GlobalOnlineDonation inserts in batches of 100 (CommitBatchSize, lines 267-299) with no database-level uniqueness constraint or advisory lock preventing two concurrent runs (or a manual match + an auto-run) from targeting the same PaymentTransaction or GlobalDonation simultaneously.
- **Gap identified:** The only protection against double-matching is the in-request `usedGds` HashSet and the pre-query filter excluding already-linked GODs -- both are point-in-time snapshots with no locking, so two overlapping RunAutoReconciliation invocations (e.g., a scheduled job overlapping with a manual staff-triggered run) could both select the same candidate GlobalDonation for two different PaymentTransactions, or the same PaymentTransaction for two different donations.
- **Why it's a problem:** A race here creates two GlobalOnlineDonation rows both claiming a link to the same PaymentTransaction/GlobalDonation pair (or duplicate reconciliation entries), corrupting the reconciliation ledger and any downstream fee/settlement reporting.
- **Recommended solution:** Add a unique DB constraint on GlobalOnlineDonations(CompanyId, PaymentGatewayId, GatewayTransactionId) (already partially covered by the ODP-B5 pending index) and/or serialize reconciliation runs per company with an advisory lock so overlapping runs cannot race.
- **Production impact:** Concurrent reconciliation runs (scheduled + manual) can double-match the same payment.
- **Business impact:** Corrupted reconciliation records requiring manual cleanup.
- **Technical impact:** Classic check-then-act race with no DB-level guard in this specific write path.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/Reconciliation/RunAutoReconciliationCommand/RunAutoReconciliation.cs:121-299
- **Reviewer note:** not adversarially verified (Medium/Low)

## Payments & Reconciliation

### #52 · Payment Webhooks — Braintree / Razorpay / PayU controllers — Payment webhook duplicate-event race condition  — `Critical`

- **Module:** Payments & Reconciliation  |  **Category:** payments  |  **Verification:** CONFIRMED
- **Current implementation:** PaymentWebhookLogConfiguration.cs defines no index (unique or otherwise) on GatewayEventId, and RazorpayWebhookController.cs logs the incoming event and only checks for duplicates against already-committed rows before its own SaveChangesAsync, with no DB-level uniqueness constraint backing the check.
- **Gap identified:** PaymentWebhookLogConfiguration.cs:1-25 contains no HasIndex call at all on GatewayEventId (verified — only column-length/required config, no index of any kind). The in-app dedup check at RazorpayWebhookController.cs:163-181 compares against OTHER rows only, and the current row's GatewayEventId/SignatureValid values are not committed to the DB until the later SaveChangesAsync at line 178 or 189 — meaning two concurrent deliveries of the same event each create their own log row, each pass signature validation, and each query the other's (not-yet-committed) row and find no duplicate, so both proceed to ProcessRazorpayEvent (line 184).
- **Why it's a problem:** Two concurrent deliveries of the same webhook event each pass signature validation and each query the other's not-yet-committed row, finding no duplicate, so both proceed to process the same payment event — a classic TOCTOU race enabled by the missing index.
- **Recommended solution:** Add a unique index on (GatewayEventId) in PaymentWebhookLogConfiguration.cs, and change RazorpayWebhookController (and equivalent Braintree/PayU controllers) to insert-and-commit the log row first inside a try/catch for the unique-constraint violation, treating a violation as 'already processed' before calling ProcessRazorpayEvent.
- **Production impact:** Concurrent webhook retries (common with all major payment gateways) can cause double-processing of a single payment event under real production load.
- **Business impact:** Double-processing a payment/refund webhook can double-credit or double-refund a donation, directly corrupting financial records and donor statements.
- **Technical impact:** Lack of a DB-level uniqueness constraint means the in-app dedup check is not race-safe; correctness depends entirely on timing rather than an enforced invariant.
- **Evidence:** Base.Infrastructure/Data/Configurations/DonationConfigurations/PaymentWebhookLogConfiguration.cs:1-25 (no index defined); Base.API/Controller/RazorpayWebhookController.cs:100-112 (log+save before checks), :132-155 (in-memory signature flag), :158-181 (dedup query against other rows, TOCTOU window before commit at 178/189).

### #53 · Refund Management (Screen #14 area) — CreateRefund / ApproveRefund / ProcessRefund / CompleteRefund — Refund lifecycle has no real gateway integration  — `Critical`

- **Module:** Payments & Reconciliation  |  **Category:** payments  |  **Verification:** CONFIRMED
- **Current implementation:** CreateRefund.cs sets RefundStatusId to 'REF' (born-complete) and only touches internal GlobalDonation ledger fields inside a DB transaction, never calling IPaymentService.RefundAsync; ProcessRefund.cs contains a literal 'SERVICE_PLACEHOLDER' comment and only flips status/ProcessingStartedDate; CompleteRefund.cs accepts GatewayTransactionRefundId as free-text with no verification against any real gateway transaction.
- **Gap identified:** CreateRefund.cs:238-251,360-408 sets RefundStatusId to REF (born-complete) and only updates GlobalDonation ledger fields inside a CreateExecutionStrategy/BeginTransactionAsync block — IPaymentService.RefundAsync is never called anywhere in the file. ProcessRefund.cs:7-12 and :64 contain an explicit self-documenting comment: 'SERVICE_PLACEHOLDER: IPaymentService.RefundAsync(...) would be invoked here' — confirming the handler only flips RefundStatusId to PRO and sets ProcessingStartedDate, with zero gateway interaction. CompleteRefund.cs:14-17,90-93 accepts GatewayTransactionRefundId as a free-text optional string on the command DTO, sets it verbatim onto the entity with no call to any provider and no verification it matches a real transaction.
- **Why it's a problem:** The entire refund state machine (Create/Process/Complete) advances refunds to a fully-completed state in the ledger while no money ever moves at the payment gateway, meaning refunds are recorded as done without ever being executed against Braintree/Razorpay/PayU.
- **Recommended solution:** Wire ProcessRefund.cs to actually invoke IPaymentService.RefundAsync against the correct provider (BraintreeProvider/RazorpayProvider/PayUIndiaProvider — already implemented but unused), only allow CompleteRefund to set GatewayTransactionRefundId from the provider's own response, and gate REF/completed status transitions on a confirmed gateway callback rather than a manual command.
- **Production impact:** Finance staff and donors will see refunds marked complete in the system while no actual funds are returned, creating a ledger that does not reflect reality.
- **Business impact:** Donors who were promised refunds do not receive money, creating disputes, chargebacks, and trust/compliance exposure, while the org's books misstate cash position.
- **Technical impact:** Ledger and gateway state are fully decoupled — GatewayTransactionRefundId being free-text also opens the door to fabricated/incorrect reconciliation records with no verification path.
- **Evidence:** CreateRefund.cs:238-251 (REF-born status resolution), :350-409 (transaction that never calls RefundAsync); ProcessRefund.cs:7-12,64 (explicit SERVICE_PLACEHOLDER comment, state-machine-only); CompleteRefund.cs:14-17,90-93 (GatewayTransactionRefundId is free-text, unset from any gateway response); PaymentService.cs:45-49, BraintreeProvider.cs:145-161, RazorpayProvider.cs:300, PayUIndiaProvider.cs:419-427 (unused real implementations).

### #158 · Braintree Webhook Controller — Braintree webhook dev-only bypass  — `High`

- **Module:** Payments & Reconciliation  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** The Braintree webhook endpoint is decorated with controller-level AllowAnonymous and gates itself solely with `if (!_env.IsDevelopment()) return NotFound();`, with a code comment admitting it can forge subscription charge-success/failure/cancel/past-due transitions.
- **Gap identified:** The endpoint's own code comment at :257-263 explicitly acknowledges it can forge subscription charge-success/failure/cancel/past-due transitions. The sole guard is `if (!_env.IsDevelopment()) return NotFound();` at :264-268 — a single runtime environment check with no additional secret, auth, or compile-time exclusion.
- **Why it's a problem:** A single environment flag is not a security boundary — if ASPNETCORE_ENVIRONMENT is ever misconfigured in a non-prod tier or a lower environment shares production data, an anonymous caller can fabricate subscription lifecycle events with no signature or secret verification.
- **Recommended solution:** Remove the environment-only guard and require Braintree webhook signature verification (HMAC/notification signature) on every call regardless of environment; if a dev-only simulation endpoint is still needed, compile it out of Release builds via #if DEBUG or a separate test-only controller excluded from prod deployment artifacts.
- **Production impact:** A misconfigured environment variable in any deployed tier turns this into an open, unauthenticated endpoint capable of forging payment state transitions.
- **Business impact:** Forged subscription events could mark donations as charged/cancelled without real money movement, corrupting donor billing and revenue recognition.
- **Technical impact:** Lack of cryptographic webhook verification is a significant security-surface gap on a payment-state-mutating endpoint.
- **Evidence:** Base.API/Controller/PaymentWebhookController.cs:10-13 (controller-level AllowAnonymous), :254-268 (endpoint + sole environment guard), :257-263 (self-acknowledging risk comment).

### #159 · Online Donation Confirm — ConfirmOnlineDonationHandler — Donation confirm race condition (no concurrency control)  — `High`

- **Module:** Payments & Reconciliation  |  **Category:** payments  |  **Verification:** CONFIRMED
- **Current implementation:** ConfirmOnlineDonationHandler reads the payment staging row with a plain SELECT and no optimistic (RowVersion/xmin) or pessimistic locking mechanism exists anywhere in Base.Infrastructure, relying only on a post-read idempotency-by-replay check.
- **Gap identified:** Project-wide grep across Base.Infrastructure for IsRowVersion/ConcurrencyToken/xmin/RowVersion returned zero matches — no optimistic concurrency token or pessimistic locking exists anywhere in this data layer. The staging row is read in a plain SELECT with no FOR UPDATE / atomic claim, so two concurrent Confirm calls for the same PaymentSessionId can both read PENDING state before either commits COMPLETED, and both would proceed past the idempotency check to call the gateway.
- **Why it's a problem:** Two concurrent Confirm calls for the same PaymentSessionId can both read PENDING state before either commits COMPLETED, letting both proceed past the idempotency check and call the payment gateway twice for the same donation.
- **Recommended solution:** Add a concurrency token (EF `[ConcurrencyCheck]`/rowversion or Postgres xmin) to the staging entity and catch DbUpdateConcurrencyException on save, or claim the row atomically via a conditional UPDATE ... WHERE Status = PENDING RETURNING pattern before any gateway call.
- **Production impact:** Race conditions under concurrent webhook/client retries can trigger duplicate gateway charge attempts in production.
- **Business impact:** Donors could be double-charged or duplicate donation records created, generating refund overhead and donor trust damage.
- **Technical impact:** Absence of any concurrency control across the entire data layer is a systemic data-integrity gap, not isolated to this handler.
- **Evidence:** ConfirmOnlineDonation.cs:104-107 (unlocked staging load), :122-133 (idempotency-by-replay check only); grep for IsRowVersion|ConcurrencyToken|xmin|RowVersion across Base.Infrastructure returned no files.

### #160 · Online Donation Confirm — Recurring donation setup (Razorpay & PayU) — Recurring donation setup missing transaction wrapping  — `High`

- **Module:** Payments & Reconciliation  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** The Razorpay and PayU recurring-donation setup paths in ConfirmOnlineDonation.cs execute six-plus sequential SaveChangesAsync calls with no EF execution strategy or explicit transaction, unlike CreateRefund.cs which wraps its multi-step write in CreateExecutionStrategy()+BeginTransactionAsync().
- **Gap identified:** Grep of the entire file for CreateExecutionStrategy/BeginTransactionAsync returned zero matches — none of these SaveChangesAsync calls are wrapped in an EF transaction or execution strategy, unlike CreateRefund.cs:385-409 which properly uses efDbContext.Database.CreateExecutionStrategy() + BeginTransactionAsync() for its multi-step write.
- **Why it's a problem:** If any SaveChangesAsync call in the sequence fails partway (including transient DB errors that EF's retry strategy is meant to handle), the recurring schedule and related donation/contact records can be left in a partially-committed, inconsistent state.
- **Recommended solution:** Wrap the full recurring-setup write sequence in efDbContext.Database.CreateExecutionStrategy().ExecuteAsync(...) with a single BeginTransactionAsync/CommitAsync, mirroring the pattern already established in CreateRefund.cs.
- **Production impact:** A transient DB blip mid-sequence in production leaves recurring donation records half-written with no automatic rollback.
- **Business impact:** Inconsistent recurring-donation state can cause missed or incorrect future auto-debits, affecting donor billing accuracy.
- **Technical impact:** Lack of atomicity across multi-step writes risks orphaned/partial rows and makes failure recovery non-deterministic.
- **Evidence:** ConfirmOnlineDonation.cs:876-877,899-900,903-912,918-942,944-962 (Razorpay recurring, six unwrapped SaveChangesAsync calls); :1029-1042 (PayU recurring, identical unwrapped pattern continuing past this point); contrast with Refunds/Commands/CreateRefund.cs:385-409 (proper CreateExecutionStrategy + BeginTransactionAsync).

### #161 · Webhook Processing — Best-effort donation promotion — Webhook promotion failures leave no durable trace  — `High`

- **Module:** Payments & Reconciliation  |  **Category:** ops  |  **Verification:** ADJUSTED
- **Current implementation:** Inbox AWAITING/UnresolvedCount buckets key off ResolvedContactId==null rather than PromotedGlobalDonationId==null, and recurring per-cycle promotions (PromoteRecurringCycle.cs) update schedule fields unconditionally before the promotion try/catch runs, with no staging row equivalent for recurring cycles.
- **Gap identified:** The Inbox's AWAITING/UnresolvedCount buckets (GetOnlineDonationStagingList.cs:105-110, GetOnlineDonationInboxSummary.cs:85) are keyed off `ResolvedContactId == null`, NOT off `PromotedGlobalDonationId == null` — so a staging row where ResolvedContactId was already populated before promotion ran (e.g., recurring donations, which per ConfirmOnlineDonation.cs:1000-1002 require a resolved contact before Confirm even proceeds) but where the subsequent promotion attempt threw, falls into the 'RESOLVED' bucket, is not counted as unresolved, and is never flagged for staff attention despite no GlobalDonation actually existing. For per-cycle RECURRING promotions specifically (PromoteRecurringCycle.cs), there is no staging row at all — schedule fields (LastChargedDate, TotalChargedCount, etc.) are updated unconditionally at PaymentWebhookController.cs:181-187 BEFORE the promotion attempt, so a promotion failure there leaves absolutely no durable trace beyond the log line; the schedule looks fully up-to-date.
- **Why it's a problem:** A staging row that already has a resolved contact but whose promotion attempt threw falls into the RESOLVED bucket and is never flagged for staff, and for recurring cycles the schedule looks fully up-to-date even when no GlobalDonation was actually created.
- **Recommended solution:** Change inbox filters to key unresolved/failed state off PromotedGlobalDonationId==null (not ResolvedContactId), and introduce a durable per-cycle promotion-attempt record (or a PromotionFailed flag on the schedule) written before schedule fields are updated so failures survive past the log line.
- **Production impact:** Silent promotion failures accumulate undetected in production with no operational alert surfacing them.
- **Business impact:** Donors whose payments were captured but never promoted to a GlobalDonation may never receive receipts, and recurring revenue can appear healthy while cycles are silently failing.
- **Technical impact:** Inbox counters and schedule state diverge from actual ledger truth, undermining any reconciliation or audit built on those signals.
- **Evidence:** PaymentWebhookController.cs:181-208 (schedule fields updated unconditionally before best-effort promotion try/catch, no failure flag persisted); ConfirmOnlineDonation.cs:63-91 (PromoteCapturedDonationAsync catch-and-log), :1000-1002 (recurring requires ResolvedContactId before Confirm); PromoteOnlineDonationStaging.cs:21-29,74-80 (PromotedGlobalDonationId idempotency guard exists but is schema-only); GetOnlineDonationStagingList.cs:101-114 (AWAITING/RESOLVED filters keyed on ResolvedContactId, not PromotedGlobalDonationId); GetOnlineDonationInboxSummary.cs:83-89 (same ResolvedContactId-based UnresolvedCount); PromoteRecurringCycle.cs:1-39 (no staging-equivalent row for recurring cycles at all).

### #259 · Payment Gateway Webhooks — PayU — PayU webhook missing refund/dispute event handling  — `Medium`

- **Module:** Payments & Reconciliation  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** PayUWebhookController only handles payment.captured/payment.failed events across its 299 lines; there is no branch for refund-confirmation or chargeback/dispute events.
- **Gap identified:** No webhook handling exists for PayU refund-confirmation or chargeback/dispute events, meaning even if a refund were correctly initiated via IPaymentService.RefundAsync in the future, PSS would have no automated way to confirm the refund actually completed on PayU's side or detect a chargeback/dispute raised against a PayU transaction.
- **Why it's a problem:** Even if a refund is correctly initiated via IPaymentService.RefundAsync in the future, PSS has no automated way to confirm the refund completed on PayU's side or to detect a chargeback/dispute raised against a PayU transaction.
- **Recommended solution:** Add webhook event branches for PayU refund-confirmation and dispute/chargeback notifications, updating the corresponding GlobalDonation/refund/dispute records analogous to how the Braintree/Razorpay paths (or the RespondToDispute flow) handle these events.
- **Production impact:** Refund and dispute status for PayU transactions will silently drift from the gateway's actual state with no automated reconciliation.
- **Business impact:** Staff lack visibility into PayU chargebacks and refund completion, risking delayed financial reporting and unresolved donor disputes.
- **Technical impact:** An incomplete webhook surface for one gateway creates inconsistent event coverage across the payments subsystem.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/Controller/PayUWebhookController.cs (only payment.captured/payment.failed handled, 299 lines total, no refund/dispute event branch).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #260 · Payment Reconciliation — RunAutoReconciliation — Auto-reconciliation permanently excludes failed-batch donations  — `Medium`

- **Module:** Payments & Reconciliation  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** When a batch's SaveChangesAsync throws a DbUpdateException, RunAutoReconciliation correctly decrements autoMatched/increments failed for that batch, but the GlobalDonationIds already added to the in-memory usedGds set for that failed batch are never released.
- **Gap identified:** If a batch's SaveChangesAsync throws a DbUpdateException (lines 270-281, 287-298), the code correctly decrements `autoMatched` and increments `failed` for that batch, but the GlobalDonationIds already added to `usedGds` for that failed batch are never removed/retried — those donations are permanently excluded from matching for the remainder of the same run (and reported as neither matched nor explicitly retried), since `usedGds` is only consulted for candidate exclusion within the same execution.
- **Why it's a problem:** Those donations remain excluded from candidate matching for the rest of the same run even though they were never actually committed as matched, so they are neither matched nor retried within that execution.
- **Recommended solution:** On batch failure, remove that batch's GlobalDonationIds from usedGds before continuing to the next batch (or before the run ends) so they remain eligible for matching in the same or a subsequent run pass.
- **Production impact:** A transient DB error during one batch silently reduces the effective match rate of an otherwise-successful reconciliation run.
- **Business impact:** Legitimately matchable donations sit unmatched longer, delaying receipt issuance and financial close.
- **Technical impact:** In-memory exclusion state that isn't reconciled with actual commit outcome introduces a correctness gap in batch-processing logic.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/Reconciliation/RunAutoReconciliationCommand/RunAutoReconciliation.cs:264-283 (usedGds.Add before commit), :270-281 (failure path decrements counts but does not release usedGds).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #261 · PayU Recurring (SI mandate) — PayU recurring mandate activation unconfirmed  — `Medium`

- **Module:** Payments & Reconciliation  |  **Category:** payments  |  **Verification:** CONFIRMED
- **Current implementation:** The recurring donation schedule is created and shown as active immediately after PayU setup, but a TODO(PayU-SI) comment in ConfirmOnlineDonation.cs flags that actual subsequent auto-debits depend on a merchant-account-level activation step that is not confirmed or enforced in code.
- **Gap identified:** The recurring schedule is created and presented to the donor/staff as active, but the code itself flags that actual subsequent auto-debits depend on a merchant-account-level activation step that is not confirmed/enforced anywhere in the code — i.e., the system can create a 'recurring' donation record for PayU that never actually charges again after the first payment, with no visible indicator to staff that this gateway's recurring capability is conditional/incomplete.
- **Why it's a problem:** The system can present a 'recurring' PayU donation as active when it may never charge again after the first payment, with no indicator to staff that this gateway's recurring capability is conditional or incomplete.
- **Recommended solution:** Confirm PayU SI mandate activation status via their API/webhook before marking the schedule active, and surface a visible staff-facing status flag (e.g., 'Mandate Pending Activation') until confirmed; block or warn on relying on PayU recurring until this is resolved.
- **Production impact:** Donors and staff will believe recurring payments are running when they may silently stop after the first charge.
- **Business impact:** Expected recurring revenue from PayU donors may not materialize, and donors are not informed their commitment isn't actually recurring.
- **Technical impact:** An unresolved TODO on a payment-critical path indicates the feature is incomplete despite being exposed as a working option.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/OnlineDonationPages/PublicMutations/ConfirmOnlineDonation.cs:987-988 (TODO(PayU-SI) comment).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #262 · Reconciliation — MatchPaymentTransaction / RunAutoReconciliation — Cross-currency transactions unmatchable in reconciliation  — `Medium`

- **Module:** Payments & Reconciliation  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** MatchPaymentTransaction hard-blocks matching when a PaymentTransaction's currency differs from the GlobalDonation's currency, and RunAutoReconciliation's candidate scoring filter is likewise currency-equality-only.
- **Gap identified:** Any PaymentTransaction whose donor-facing currency differs from the recorded GlobalDonation currency (which can legitimately happen for multi-currency gateways/pages) can never be matched via reconciliation — manually or automatically — leaving those transactions permanently in the unmatched queue with no documented workaround in the code.
- **Why it's a problem:** Any donation captured via a multi-currency gateway/page where transaction and donation currencies legitimately differ can never be matched — manually or automatically — with no documented workaround, leaving those items permanently stuck in the unmatched queue.
- **Recommended solution:** Allow manual matching to override the currency-equality hard block (with an explicit confirmation/audit note), and extend auto-reconciliation candidate scoring to consider FX-converted amount equivalence using the existing direct-pair FX rate service rather than excluding cross-currency pairs outright.
- **Production impact:** Growing backlog of permanently unmatched transactions inflates the unmatched queue and obscures true reconciliation health.
- **Business impact:** Legitimate multi-currency donations never get reconciled to a matched state, complicating financial reporting and donor receipt accuracy.
- **Technical impact:** A hard currency-equality filter with no override path is a structural gap in the matching algorithm for any multi-currency deployment.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/Reconciliation/MatchCommand/MatchPaymentTransaction.cs:66-71 (ISSUE-4 hard block); RunAutoReconciliationCommand/RunAutoReconciliation.cs:186 (currency-equality filter in candidate scoring).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #263 · Reconciliation — RespondToDispute — Dispute resolution ledger linkage unverified  — `Medium`

- **Module:** Payments & Reconciliation  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** RespondToDispute.cs was located but not read in this pass, leaving unconfirmed whether a lost dispute/chargeback triggers any GlobalDonation ledger adjustment (e.g., RefundedAmount/PaymentStatusId) analogous to the Refund flow, or is purely status/note tracking.
- **Gap identified:** Not fully verified in this pass whether a lost dispute/chargeback automatically triggers any GlobalDonation ledger adjustment (e.g., RefundedAmount / PaymentStatusId update) analogous to the Refund flow, or whether it is purely a status/note-tracking feature with no financial-ledger linkage — this needs a follow-up read to confirm severity.
- **Why it's a problem:** If chargeback losses are not reflected in the donation ledger, financial records would overstate revenue that was actually clawed back by the gateway/bank.
- **Recommended solution:** Read RespondToDispute.cs to confirm whether a lost-dispute outcome updates GlobalDonation financial fields; if it does not, add the ledger adjustment (mirroring CreateRefund's RefundedAmount/PaymentStatusId updates) so lost disputes are reflected in reported revenue.
- **Production impact:** Requires a follow-up code read before severity can be confirmed; currently an open verification gap in the production-readiness review.
- **Business impact:** If unlinked, lost chargebacks would silently inflate reported donation revenue, misleading financial statements.
- **Technical impact:** Potential ledger/status divergence between dispute outcomes and the donation record if no linkage exists.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/Reconciliation/RespondToDisputeCommand/RespondToDispute.cs (file located, not read in this pass).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #264 · Refund Workflow — CreateRefund — Refund creation bypasses approval workflow  — `Medium`

- **Module:** Payments & Reconciliation  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** CreateRefund now sets RefundStatusId directly to REF (approved/final) at creation time per a 'Session 16' code comment, while the separate ApproveRefund PEN→APR handler still exists in the codebase but is no longer part of the normal creation flow.
- **Gap identified:** The primary refund creation path now bypasses the entire approval chain that ApproveRefund/ProcessRefund/CompleteRefund were built to enforce, meaning any user with refund-create permission can immediately finalize a refund (which also flips receipt status and donation ledger fields) with no second-person approval step, while the approval-workflow code remains present and presumably still reachable/callable, creating two inconsistent operating models in the same subsystem.
- **Why it's a problem:** Any user holding refund-create permission can immediately finalize a refund — which also flips receipt status and donation ledger fields — with no second-person approval, while the still-present approval code creates two inconsistent operating models in the same subsystem.
- **Recommended solution:** Decide on one refund lifecycle: either restore CreateRefund to land in PEN and require ApproveRefund for the ledger-affecting transition, or formally deprecate/remove the approval workflow and enforce single-actor refund controls (e.g., maker-checker via a separate authorization gate) if that is the intended new model.
- **Production impact:** Inconsistent code paths risk a maintenance/regression incident if a future change re-enables the approval branch without reconciling the two models.
- **Business impact:** Loss of segregation-of-duties on refunds is a financial control and audit/compliance risk for donor money movement.
- **Technical impact:** Two divergent state-machine entry points for the same status field increase the risk of future logic conflicts and untested code paths.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/Refunds/Commands/CreateRefund.cs (RefundStatusId set to REF at creation, 'Session 16' comment); ApproveRefund.cs:1-93 (still-present PEN→APR handler, now effectively unreachable via normal creation flow).
- **Reviewer note:** not adversarially verified (Medium/Low)

## Root · Auth · Layout · Dashboards

### #64 · Main Dashboard (Master Landing Page) — KPI Snapshot / Goals & Targets / Upcoming widgets  — `Critical`

- **Module:** Root · Auth · Layout · Dashboards  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** Three of five widgets on the primary post-login landing page are 100% hardcoded mock data with no backend integration, shipped with only a small always-on 'Preview' badge as the sole visual cue that the numbers are fake.
- **Gap identified:** KpiSnapshotRow, MissionProgressStrip and UpcomingStrip render fully hardcoded, static in-component `KpiCard[]`/`ProgressRow[]`/`UpcomingItem[]` arrays (Donations Today 12,450 +18.2%; Donation Goal 34,200/50,000 68%; Annual Donor Gala May 25, etc.). Only the currency-code prefix is pulled from real state (useCompanySettingsSession); every figure, date, label, percentage, and sparkline bar-height is a literal constant with zero GraphQL/query wiring. Each widget self-labels with an animated 'Preview' chip.
- **Why it's a problem:** First screen every user sees after login; fabricated donation totals/campaign reach/goal progress/calendar events could be mistaken for real figures by finance/leadership staff or seen by a donor/board member on a screen-share, causing real operational or reputational harm.
- **Recommended solution:** Wire these three widgets to real aggregation queries (donations-today sum, campaign progress, calendar/events feed) before go-live, or remove them from the production build and ship only the already-real widgets (Modules grid, MissionControlRail) until the backend queries exist.
- **Production impact:** Every login shows fabricated donation/campaign/goal data as if real; no env/feature-flag gate hides it in production.
- **Business impact:** Erodes trust in the platform for finance/leadership users; reputational risk if seen by donors/board.
- **Technical impact:** None of these three components subscribe to any query; adding real data requires new backend aggregation endpoints not yet designed.
- **Evidence:** PSS_2.0_Frontend/src/presentation/pages/master/landing-page/kpi-snapshot-row.tsx lines 71-117 (hardcoded cards array, entire component has no useQuery/hook besides currency code); mission-progress-strip.tsx lines 86-124 (hardcoded rows array); upcoming-strip.tsx lines 39-80 (hardcoded items array). Verified by full read of all three files — none contain a data-fetching hook of any kind.
- **Reviewer note:** Read all three files in full. Every claim in the original finding is accurate: no query/hook wires any of the three widgets to backend data, all values are literal constants, and a 'Preview' chip is rendered unconditionally (not gated by an env flag or feature toggle) meaning this ships to production as-is.

### #65 · Root / Session handling (all authenticated screens) — Access-token refresh  — `Critical`

- **Module:** Root · Auth · Layout · Dashboards  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** Backend fully implements a rotating-refresh-token RefreshToken mutation. Frontend never calls it anywhere; expired-token handling is a passive toast only.
- **Gap identified:** The frontend never calls the backend's RefreshToken mutation. NextAuth's `jwt` callback (auth.ts) only sets token.accessToken/refreshToken/expiresIn once from `user` at initial sign-in and has no branch that checks expiry or calls RefreshToken. Apollo's authLink (apollo-wrapper.tsx) always resends whatever token currently sits in the NextAuth session, unconditionally. The errorLink's only handling of an expired token is `toast.error(GlobalInfoEnum.TOKENEXPIRED)` — no retry, no redirect, no session refresh. A repo-wide grep for 'refreshToken('/'RefreshToken(' usage across src confirms no call-site anywhere in the frontend invokes the mutation.
- **Why it's a problem:** Users mid-session (e.g. filling a long form) get silent GraphQL failures with only a passive toast and no path back to a working session short of manual logout/login.
- **Recommended solution:** Add refresh logic to the NextAuth jwt callback (check token expiry, call backend RefreshToken mutation, rotate refreshToken) or implement an Apollo errorLink-triggered refresh-and-retry on 'Token expired' GraphQL errors that replays the failed operation.
- **Production impact:** All users experience an unrecoverable session death at token expiry with no automatic remediation.
- **Business impact:** Work-in-progress data loss (unsaved forms) and support tickets for 'the app stopped working' complaints.
- **Technical impact:** A fully-built backend capability (RefreshToken mutation with rotation) sits completely unused.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Auth/Mutations/AuthendicationMutations.cs lines 192-303 (RefreshToken mutation fully implemented, validates+rotates); PSS_2.0_Frontend/src/infrastructure/lib/configs/auth.ts lines 64-71 (jwt callback sets token fields only from `user`, no refresh branch, no expiry check); PSS_2.0_Frontend/src/presentation/components/apollo/apollo-wrapper.tsx lines 73-91 (errorLink only toasts 'Token expired', no refresh/redirect/retry logic). Grep for 'TOKENEXPIRED|Token expired|refreshToken\(|RefreshToken\(' across src returns only the toast site plus two unrelated accounting-integration files.

### #173 · Login — Account lockout / brute-force protection  — `High`

- **Module:** Root · Auth · Layout · Dashboards  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** Per-user lockout after 5 failed attempts exists on the Login mutation; the codebase does have a working ASP.NET rate-limiter (proven by 8 policies protecting public donation/campaign endpoints), but none of those policies, nor any other, is attached to the Login mutation.
- **Gap identified:** On failed login, FailedLoginCount increments and IsLocked=true is set once it reaches 5, scoped only to the targeted UserId row (AuthendicationMutations.cs lines 64-76). Verified DependencyInjection.cs's full AddRateLimiter block (lines 226-351): it registers 8 named policies (P2PStartFundraiser, P2PDonationSubmit, PublicSubmitRateLimit, PublicPrayedRateLimit, VolunteerSubmit, CrowdFundDonationSubmit, DonationSubmit, EventRegistrationSubmit) — every one scoped to public donation/registration/prayer endpoints. None reference Login or Auth. A grep for 'EnableRateLimiting|RateLimit' inside the Auth endpoint folder returns zero matches. UseRateLimiter() middleware only enforces rate limiting where [EnableRateLimiting("PolicyName")] is attached, which the Login mutation lacks entirely.
- **Why it's a problem:** An attacker enumerating known/guessed staff usernames can deliberately lock out real users' accounts (denial of service) with 5 wrong-password requests per username, with no IP-based throttling or CAPTCHA to slow this down — and the team has already proven they know how to add rate-limit policies (used elsewhere) but simply never applied one here.
- **Recommended solution:** Add an IP-based rate-limit policy (mirroring the existing FixedWindowRateLimiter pattern already used for DonationSubmit/EventRegistrationSubmit) to the Login mutation/endpoint, and/or a CAPTCHA challenge after 2-3 failed attempts, independent of the per-user lockout counter.
- **Production impact:** Any external party can lock out any known staff username with 5 requests, with no other mitigation in place.
- **Business impact:** Legitimate staff can be locked out of the system by a malicious actor targeting known email/username patterns, causing operational disruption for an NGO's donation/case-management staff.
- **Technical impact:** No infrastructure-level rate limiting protects the Login GraphQL mutation, even though the rate-limiter middleware and policy-registration pattern are already in active use elsewhere in the same file.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Auth/Mutations/AuthendicationMutations.cs lines 68-76 (FailedLoginCount >= 5 => IsLocked, per-user only, no IP tracking anywhere in the Login method); PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/DependencyInjection.cs lines 226-351 (all 8 rate-limit policies are for public donation/campaign/registration/prayer submission endpoints; none for Login/Auth); grep for 'EnableRateLimiting|RateLimit' in the Auth endpoints directory returns no matches.

### #174 · Root / Global navigation — Company Switcher  — `High`

- **Module:** Root · Auth · Layout · Dashboards  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** The multi-tenant company-switch UI (CompanySwitcher + CompanySwitcherItem) is fully built and correctly wired end-to-end to the backend SwitchCompany mutation, but is never imported/rendered by any layout, header, sidebar, topbar, or profile menu anywhere in the app.
- **Gap identified:** CompanySwitcherItem.handleSwitch correctly calls SWITCH_COMPANY_MUTATION, re-authenticates via signIn('credentials', {userData}), clears Apollo cache/localStorage, and hard-navigates. CompanySwitcher/index.tsx fetches STAFF_COMPANIES_BY_STAFFID_QUERY and auto-selects a default company. But a repo-wide grep for 'CompanySwitcher'/'company-switcher' returns only the component's own two files plus one unrelated comment in useUserInfo.ts. Verified the actual production app shell: layout-components/header/header.tsx (used by all real (core) app pages via NavTools -> ProfilePopover) and profile-popover/index.tsx (read in full, all menu items enumerated) contain no reference to CompanySwitcher. The master-landing-page's own separate header (landing-page/header/index.tsx) also only renders TenantClock/ThemeButton/Logout, not CompanySwitcher.
- **Why it's a problem:** This is explicitly a multi-tenant SaaS where staff can belong to multiple companies. With the component never mounted, any multi-company staff user has no in-app way to switch companies at all, despite the backend and component fully supporting it.
- **Recommended solution:** Mount <CompanySwitcher /> in the global header/topbar (NavTools in header.tsx, alongside ThemeButton/ProfilePopover) or the master-landing-page header (alongside TenantClock/ThemeButton/Logout) so multi-company staff can actually reach it.
- **Production impact:** Multi-company staff cannot switch companies through the UI in production despite the feature being fully implemented server-side and client-side.
- **Business impact:** Staff supporting multiple NGO client companies are blocked from a core workflow; likely forces support workarounds that don't exist either.
- **Technical impact:** Dead component tree; the SwitchCompany mutation path is untested by real usage in production.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/custom-components/company-switcher/company-switcher-item.tsx lines 37-91 (correct switch flow); index.tsx (full read, correctly implemented UI); PSS_2.0_Frontend/src/presentation/components/layout-components/header/header.tsx (full read — NavTools renders ThemeButton/FullScreen/ModuleNavigator/ProfilePopover only); profile-popover/index.tsx (full read — Profile/Settings/Themes/Notifications/Shortcuts/Help/Trash/Logout menu items only, no company switch entry); PSS_2.0_Frontend/src/presentation/pages/master/landing-page/header/index.tsx lines 2-37 (TenantClock/ThemeButton/Logout only). Grep for 'CompanySwitcher|SwitchCompany' confirms no render site outside the component's own directory.

### #175 · Root / Session handling — JWT expiry vs declared ExpiresIn  — `High`

- **Module:** Root · Auth · Layout · Dashboards  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** The JWT itself is cryptographically valid for 24 hours from issuance, while the ExpiresIn field returned to the client always reports ~900 seconds regardless of the token's actual lifetime.
- **Gap identified:** AuthExtensions.CreateToken() sets the actual JWT SecurityTokenDescriptor.Expires = DateTime.UtcNow.AddDays(1) (24h validity, line 89) but returns ExpiresIn = (int)(DateTime.UtcNow.AddMinutes(15) - DateTime.UtcNow).TotalSeconds (line 109) — a value computed from two near-simultaneous UtcNow calls, always ~900 seconds, completely unrelated to the token's real 24-hour expiry.
- **Why it's a problem:** Declared vs actual token lifetime must match for any refresh/rotation strategy to be correct and for security review of 'how long is a leaked token valid' to be accurate. A 24-hour-valid access token is unusually long-lived for a bearer JWT with no server-side revocation check per request.
- **Recommended solution:** Make ExpiresIn reflect the actual Expires used in the token descriptor, or shorten Expires to a genuine 15-minute short-lived access token relying on the already-built RefreshToken flow for renewal.
- **Production impact:** Access tokens are valid 96x longer than the value clients are told, undermining any expiry-based client logic and increasing the blast radius of a leaked token.
- **Business impact:** Increases exposure window if a token is intercepted/logged; inconsistent with any compliance expectation of short-lived bearer tokens.
- **Technical impact:** Any future refresh-scheduling logic built against expiresIn will be silently wrong.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Extensions/AuthExtensions.cs line 89 (Expires = DateTime.UtcNow.AddDays(1)) and line 109 (ExpiresIn hardcoded to a fresh 15-minute window, not derived from Expires). Read the full CreateToken method — no other logic reconciles the two values.

### #279 · Login — Post-login session-ready check  — `Medium`

- **Module:** Root · Auth · Layout · Dashboards  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** After `signIn()`, `useAuth.login` polls `checkSession()` in a loop originally designed for up to 10 attempts (500ms apart); the loop bound was changed to `const maxAttempts = 1` (with the original `// const maxAttempts = 10;` left commented above it), and `// await PostLogin();` (an undefined/removed post-login hook) is also commented out. Regardless of whether the session check ever succeeds, `router.push(MASTER_URL)` executes unconditionally.
- **Gap identified:** The check now gets at most one attempt plus a single 500ms wait before giving up and showing `toast.warning('Session initialization timeout')` — yet the code navigates to the dashboard anyway either way, making the warning toast both frequently spurious (under any real-world network latency the session cookie may not have propagated in under ~500ms) and functionally meaningless (it doesn't block or retry anything).
- **Why it's a problem:** Users will intermittently see a confusing 'Session initialization timeout' warning on completely successful logins, undermining trust in the app, while the reduced retry budget also makes the app less tolerant of normal latency in session cookie propagation than it was designed to be.
- **Recommended solution:** Restore a reasonable retry budget (or replace the polling entirely with awaiting the `useSession()` update / `getSession()` resolving before navigating), and only show the timeout warning when navigation is actually deferred/blocked by it — not as a fire-and-forget toast alongside an unconditional redirect.
- **Production impact:** Spurious warning toasts appear on legitimate logins under normal latency; reduced resilience versus the originally-designed retry budget.
- **Business impact:** Confuses users at the single most important first-impression screen of the app (login).
- **Technical impact:** Dead/commented code left in a live code path (`// const maxAttempts = 10`, `// await PostLogin()`), unclear intended behavior for future maintainers.
- **Evidence:** PSS_2.0_Frontend/src/presentation/hooks/useAuth/index.ts lines 77-95 (maxAttempts reduced to 1, unconditional router.push(MASTER_URL) after warning, PostLogin() commented out)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #280 · Root / connectivity UX — NetworkStatusProvider (offline detection overlay)  — `Medium`

- **Module:** Root · Auth · Layout · Dashboards  |  **Category:** uiux  |  **Verification:** CONFIRMED
- **Current implementation:** A fully-built offline-detection system exists: browser online/offline events, `app:network-down`/`app:network-up` custom events dispatched from Apollo's errorLink, a self-adapting heartbeat ping, and a full-screen blocking 'No internet connection / Reconnecting…' overlay plus a 'Back online' toast.
- **Gap identified:** The root locale layout has both the `import` and the `<NetworkStatusProvider>` JSX usage commented out, so this entire system is never mounted and is completely inert in production.
- **Why it's a problem:** The Apollo errorLink still dispatches `app:network-down`/`app:network-up` events (dead work, no listener), and users get zero feedback when the backend is unreachable beyond whatever a specific query's own loading/error UI happens to show — no app-wide signal that the connection itself is down.
- **Recommended solution:** Re-enable `NetworkStatusProvider` in the root layout (uncomment both the import and the JSX wrapper), and QA the overlay/recovery-poll behavior before shipping, or remove the dead event-dispatching code from the Apollo errorLink if the feature is intentionally deprioritized.
- **Production impact:** No app-wide offline/connectivity feedback is shown to users in production despite the feature being fully implemented.
- **Business impact:** Users on flaky connections (a real scenario for field/branch staff of an NGO) get silent failures per-query instead of a clear 'reconnecting' state.
- **Technical impact:** Dead code path; wasted event dispatches with no consumer.
- **Evidence:** PSS_2.0_Frontend/src/presentation/provider/network-status-provider.tsx (entire file, fully implemented); PSS_2.0_Frontend/src/app/[lang]/layout.tsx (import and <NetworkStatusProvider> usage both commented out)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #281 · Root / Logout & shared-device hygiene — localStorage purge on logout  — `Medium`

- **Module:** Root · Auth · Layout · Dashboards  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** `useLogout` clears Apollo cache/cache-persist and removes localStorage keys matching prefixes 'app-', 'user-', 'nextauth', or containing 'cache'/'session', then hard-navigates via `window.location.replace(logoutUrl)`. The Zustand `useGlobalStore` (holding `staffId`, `companyId`, `companyName`, `companyCode`, `moduleCode`, etc.) persists to localStorage under the key `global-store`, which matches none of the removal filters.
- **Gap identified:** `global-store` is never removed on logout, so the previous user's `staffId`/`companyId`/`companyName`/`companyCode`/last-active module remain in localStorage after logout on a shared/kiosk browser.
- **Why it's a problem:** On the brief window after a new user logs in on the same device — before `useUserInfo`'s `LOGIN_USER_INFO_QUERY` resolves and overwrites `companyId`/`staffId` — any component reading `useGlobalStore` sees the PREVIOUS user's company/staff identifiers. For an NGO admin tool plausibly used at shared front-desk/reception terminals across multiple branch companies, this is a real (if narrow-window) cross-user/cross-tenant state bleed.
- **Recommended solution:** Explicitly clear `useGlobalStore`'s persisted state (or call `localStorage.removeItem('global-store')`) as part of `useLogout`, in addition to the existing prefix-based cleanup.
- **Production impact:** Stale tenant/staff identifiers briefly rehydrate for the next login on the same browser/device.
- **Business impact:** Risk of momentarily wrong company/branch context being read on shared devices, relevant for multi-branch NGO deployments.
- **Technical impact:** logout cleanup filter list ('app-','user-','nextauth','cache','session') does not cover the literal key name 'global-store'.
- **Evidence:** PSS_2.0_Frontend/src/presentation/hooks/useAuth/useLogout.ts lines 19-38 (removal filter list); PSS_2.0_Frontend/src/application/stores/common-stores/global-store.ts lines 36-49 (persist name: 'global-store', partialize includes staffId/companyId/companyName/companyCode)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #282 · Root / Route protection — Client-side RouteGuard  — `Medium`

- **Module:** Root · Auth · Layout · Dashboards  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** `RouteGuard` component has its entire body (session check, redirect, loading state) commented out and simply returns `<>{children}</>` unconditionally. It is still wrapped around the `(master)` layout's children with `requireAuth={true}`.
- **Gap identified:** The component gives every appearance in the codebase of enforcing client-side auth (it's literally named RouteGuard and passed `requireAuth`), but performs no check at all. The only real enforcement is the server-side `authorized()` callback in middleware, which only checks `!!auth` (a session object exists) — it cannot react to things like a mid-session account lock/disable without a fresh navigation.
- **Why it's a problem:** This creates a false sense of defense-in-depth: a developer reading `(master)/layout.tsx` reasonably assumes client-side protection exists. In reality there is a single enforcement layer (middleware), and it only gates full page navigations, not client-side route transitions within an already-loaded SPA shell, and it cannot detect same-session revocation events (e.g. a disabled account) until the next server round-trip triggers a redirect.
- **Recommended solution:** Either implement real client-side session/expiry/role checks in RouteGuard (restoring the commented logic, updated for current session shape) or remove the component entirely and rely explicitly and only on middleware, updating any documentation/comments so the security model is accurately understood by the team.
- **Production impact:** No functional break today (middleware still gates full navigations), but a misleading security control exists in the codebase that could cause a false assumption about protection guarantees during future changes.
- **Business impact:** Risk of a future regression where someone assumes RouteGuard is doing real work and removes/weakens the actual middleware gate.
- **Technical impact:** Dead code path (all logic commented) mounted in the production render tree of every (master) page.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/auth/route-guard.tsx (entire logic commented out, returns children only); PSS_2.0_Frontend/src/app/[lang]/(master)/layout.tsx (wraps children in <RouteGuard requireAuth={true}>)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #283 · Root / Session issuance — NextAuth Credentials `authorize()`  — `Medium`

- **Module:** Root · Auth · Layout · Dashboards  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** `authorize(credentials)` does not validate `userName`/`password` against the backend at all — it only requires `credentials.userData` to be parseable JSON, then returns whatever `accessToken`/`refreshToken`/`expiresIn` fields it contains as the session's tokens. Actual credential validation happens earlier and separately, in the FE's own call to `LOGIN_MUTATION` before `signIn()` is invoked.
- **Gap identified:** Because `authorize()` trusts `userData` unconditionally, any client-side JS call to `signIn('credentials', { userName: 'x', password: 'y', userData: JSON.stringify({ accessToken: 'anything' }) })` will successfully mint a valid NextAuth session cookie, since NextAuth itself never independently verifies the token against the backend.
- **Why it's a problem:** This means 'a NextAuth session exists' (which is exactly what middleware's `authorized({ auth }) { return !!auth }` checks to gate every non-public route) can be forged by any script running in the browser context, without ever calling the real Login mutation. Real GraphQL data access is still protected because the backend independently validates the JWT signature, so this is not a full account-takeover — but it is a gap in the session-issuance boundary that middleware's route-gating relies on.
- **Recommended solution:** Have `authorize()` independently verify the supplied access token (e.g. call a lightweight backend 'whoami'/introspection query, or verify the JWT signature server-side with the known public key) before minting a session, rather than trusting client-supplied JSON verbatim.
- **Production impact:** Middleware's route-gate can be bypassed for page-level access with a forged session, though real data operations still fail at the GraphQL layer.
- **Business impact:** Weakens the security boundary between 'session exists' and 'user is authenticated,' relevant for any future feature that trusts `!!auth` for more than page routing.
- **Technical impact:** No server-side token verification exists in the NextAuth authorize callback.
- **Evidence:** PSS_2.0_Frontend/src/infrastructure/lib/configs/auth.ts lines 30-48 (authorize only parses userData JSON, no backend/token verification) and lines 80-105 (authorized callback gates routes purely on !!auth)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #327 · Login / Forgot Password — Locale-aware navigation  — `Low`

- **Module:** Root · Auth · Layout · Dashboards  |  **Category:** uiux  |  **Verification:** CONFIRMED
- **Current implementation:** The 'Forgot password' link on the login form is hardcoded as `<Link href="/en/forgot">`, regardless of the page's current `[lang]` route segment.
- **Gap identified:** A user on the `/bn/login` or `/ar/login` page clicking 'Forgot password' is force-navigated into the English-locale route (`/en/forgot`), breaking the i18n experience mid-flow for exactly the two non-English locales the app explicitly supports (`bn`, `ar` per the locales list in auth.ts).
- **Why it's a problem:** Inconsistent/broken localization on an auth-recovery flow is a real, user-visible functional bug for non-English tenants, not just cosmetic — the user's language context silently resets.
- **Recommended solution:** Read the current `lang` param (already available via the route's `[lang]` segment/context) and build the link as `/${lang}/forgot`, consistent with how other locale-aware links are built elsewhere in the app.
- **Production impact:** Every forgot-password click for bn/ar users is silently redirected to the English locale.
- **Business impact:** Degrades the experience for any non-English-speaking tenant/staff using the forgot-password recovery flow.
- **Technical impact:** Simple hardcoded-string bug.
- **Evidence:** PSS_2.0_Frontend/src/presentation/pages/auth/login/login-form.tsx line 153 (<Link href="/en/forgot">)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #328 · Root / App Layout — Mobile safe-area / notch handling  — `Low`

- **Module:** Root · Auth · Layout · Dashboards  |  **Category:** uiux  |  **Verification:** CONFIRMED
- **Current implementation:** Fixed-position UI elements exist across the app (e.g. the landing page's `LandingHeader` fixed top bar), but a repo-wide search finds zero usage of `safe-area`, `env(safe-area-inset-*)`, or `viewport-fit=cover` anywhere in the frontend source.
- **Gap identified:** No accommodation exists for device safe areas (notches, home-indicator bars) on mobile/PWA-style usage of fixed headers/footers.
- **Why it's a problem:** On modern notched phones (iPhone X-class and later) or if the app is ever added-to-homescreen/run full-screen, fixed top/bottom bars can be obscured by or overlap the notch/home-indicator, since the CSS never reserves `env(safe-area-inset-*)` space.
- **Recommended solution:** Add `viewport-fit=cover` to the viewport meta config and apply `padding: env(safe-area-inset-*)` (or Tailwind's safe-area utilities) to fixed top/bottom chrome (header, bottom nav if any, overlays like the offline banner).
- **Production impact:** Visual clipping/overlap risk on notched mobile devices, most noticeable if the app is used as a home-screen PWA.
- **Business impact:** Minor polish gap for mobile/field-staff usage of the admin app.
- **Technical impact:** No safe-area CSS anywhere in the codebase (grep returned zero matches).
- **Evidence:** Repo-wide grep for 'safe-area|env(safe-area|viewport-fit' across PSS_2.0_Frontend/src returned no matches; PSS_2.0_Frontend/src/presentation/pages/master/landing-page/header/index.tsx (fixed header with no safe-area padding)
- **Reviewer note:** not adversarially verified (Medium/Low)

## API / GraphQL Contract

### #7 · All GraphQL queries/mutations (global — e.g. Base.API/EndPoints/Case/Queries/BeneficiaryQueries.cs, Base.API/EndPoints/Grant/Queries/GrantQueries.cs, Base.API/EndPoints/Grant/Mutations/GrantMutations.cs) — GraphQL error-handling contract  — `Critical`

- **Module:** API / GraphQL Contract  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** Every resolver catches all exceptions in try/catch and returns them as a `.Error(ex.Message)` custom envelope over HTTP 200, bypassing HotChocolate's native GraphQL error channel entirely.
- **Gap identified:** Every resolver wraps mediator.Send in try/catch and converts ANY exception (including FluentValidation ValidationException) into `.Error(ex.Message)` on a custom ApiResponse envelope returned with HTTP 200. HotChocolate's native GraphQL error channel is never used — `.AddMutationConventions()` is commented out.
- **Why it's a problem:** GraphQL-aware tooling and any API consumer relies on response.errors[]/HTTP status; here 100% of business exceptions collapse into 200-OK 'success:false' envelopes with raw exception text exposed.
- **Recommended solution:** Introduce a resolver-level exception translation layer mapping domain/validation exceptions to typed GraphQLException with structured extensions; re-enable AddMutationConventions(); restore StrictValidation; reserve ApiResponse envelope for legitimate business-status fields only.
- **Production impact:** Affects 100% of the GraphQL surface — every resolver in every module follows this identical pattern.
- **Business impact:** Support/ops cannot triage production incidents from GraphQL error telemetry; error text (including internal exception detail) leaks to clients.
- **Technical impact:** No structured, spec-compliant GraphQL error contract across the entire API surface.
- **Evidence:** Base.API/Extensions/GraphQLRegistrationExtensions.cs:54 `//.AddMutationConventions()` (confirmed commented out) and :58-61 `options.StrictValidation = false` (confirmed set); Base.API/EndPoints/Case/Queries/BeneficiaryQueries.cs:30-47 (GetBeneficiaries: generic `catch (Exception ex) { return ...Error(ex.Message); }` wrapping every method, confirmed for GetBeneficiaries/GetBeneficiary/GetBeneficiaryCases); Base.API/EndPoints/Grant/Mutations/GrantMutations.cs:26-79 (CreateGrant/UpdateGrant/DeleteGrant/ToggleGrant all follow identical `catch (Exception ex) { return BaseApiResponse<int>.Error(ex.Message); }` pattern); Base.Application/Behaviors/CommandValidationBehavior.cs:33 confirms `throw new ValidationException(string.Join(", ", formattedErrors))` — this ValidationException is caught by the generic `catch(Exception)` in every resolver and its raw message text returned to the client inside a 200-OK payload. Verified no counter-evidence exists (AddDynamicApiResponseTypes in GraphQLServiceExtension.cs only registers schema types, does not touch error handling).
- **Reviewer note:** Fully confirmed by direct code read across resolver layer, DI registration, and the validation pipeline. No mitigating code found anywhere in the reviewed files. This is the most severe, systemic contract defect and Critical priority is justified.

### #8 · All list/grid screens using GridFeatureRequest pagination (global) — GraphQL pagination contract  — `Critical`

- **Module:** API / GraphQL Contract  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** ApplyPagination applies whatever pageSize the client sends with no upper bound and returns the full unpaginated query whenever pageSize is zero or negative, with only the frontend applying any clamping.
- **Gap identified:** `GridQueryBuilderHelper.ApplyPagination` has no upper clamp on pageSize and returns the query fully unpaginated when pageSize<=0. No server-side validator enforces bounds anywhere (GridFeatureRequest is a plain record with no bounds, and grep confirms zero FluentValidation validators reference pageSize). FE only clamps client-side.
- **Why it's a problem:** Any client can request pageSize 0 or negative and receive the entire unfiltered table — DoS and data-exfiltration vector plus EF Core performance cliff on large tables.
- **Recommended solution:** Enforce a server-side max page size (e.g. 100) and minimum of 1 inside ApplyPagination itself or a shared GridFeatureRequest validator, independent of any FE clamp.
- **Production impact:** Directly exploitable by any consumer bypassing the Next.js frontend.
- **Business impact:** Risk of full-table data exposure per request and production DB load spikes.
- **Technical impact:** Unbounded query results possible from any authenticated GraphQL client.
- **Evidence:** Base.Application/CommonServiceFeatures/GridFeature/GridQueryBuilderHelper.cs:764-772 — confirmed exact code: `if (pageIndex < 0 || pageSize <= 0) { return query; } return query.Skip(pageSize * pageIndex).Take(pageSize);`; Base.Application/CommonServiceFeatures/GridFeature/GridFeatureRequest.cs:3-12 — plain record, `pageSize = 10` default, no range validation attribute; grep of Base.Application for FluentValidation validators referencing 'pageSize' returned zero files; Base.Application/Behaviors/QueryValidationBehavior.cs exists as a generic pipeline hook but only fires per-query registered validators (none constrain pageSize); PSS_2.0_Frontend/.../data-table-fetch-data.tsx:104 `pageSize: Math.min(pageSize, 100)` confirmed client-side only.
- **Reviewer note:** Verified at every layer (helper, request DTO, query validators, FE) — no server-side enforcement exists anywhere in the codebase. Directly exploitable by any authenticated GraphQL client bypassing the Next.js FE (e.g. Postman with a valid bearer token) to request pageSize=0 and receive an entire unfiltered/unpaginated table.

### #93 · All index/grid pages using useInitializeDataTableDatas (global) — Client-side handling of the API error envelope  — `High`

- **Module:** API / GraphQL Contract  |  **Category:** qa  |  **Verification:** CONFIRMED
- **Current implementation:** useInitializeDataTableDatas simply reads `data?.result?.data ?? []` into grid state and only sets its error state on genuine Apollo/network transport failures, ignoring the envelope's success/errorCode/message fields.
- **Gap identified:** The shared FE hook processes results via `setData(data?.result?.data ?? [])` etc. and never inspects `data.result.success`/`errorCode`/`message`; the `error` state is populated only by genuine Apollo/network-transport failures, which are rare given the BE's 200-OK-always contract.
- **Why it's a problem:** Real backend exceptions render as empty grids, identical to legitimate zero-match results, making support tickets like 'the list is empty' undiagnosable from the UI.
- **Recommended solution:** Have the hook check `data.result.success === false` and surface `data.result.message`/`errorCode` through the existing error state, paired with fixing BE envelope semantics (findings #1, #3).
- **Production impact:** Systemic — affects essentially every grid/list screen (29+ confirmed usage sites).
- **Business impact:** Support cannot distinguish 'no data' from 'system is broken'; incidents go undetected until escalated.
- **Technical impact:** No client-visible signal for real backend failures on any list screen.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/flow/data-table-fetch-data.tsx:231-270 confirmed — the result-processing effect reads only `data?.result?.data`, `data.result.totalCount`, `data.result.filteredCount`, with no check of a success/errorCode field anywhere in the hook; `error` (line 273) is sourced solely from Apollo's `useLazyQuery` transport-level error plus a local try/catch around client-side processing exceptions. Confirmed dead-code claim: grantlist/grant/index-page.tsx:175-179 shows `const error = dataError || columnsError; if (error && viewMode === "table") { ... Error: {error.toString()} }` — this path is fed only by the rarely-populated Apollo error, corroborated by the same `error`-gated render pattern appearing near-identically across 27 index-page files repo-wide (grep confirmed).
- **Reviewer note:** Fully confirmed. Combined with findings #1 and #3, a real backend failure (DB timeout, unhandled bug, permission denial) renders as a silently empty grid indistinguishable from a legitimate zero-match filter.

### #94 · All list/grid queries returning PaginatedApiResponse (global) — Empty-result vs. error semantics  — `High`

- **Module:** API / GraphQL Contract  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** A legitimately empty paginated result is routed through the same ExceptionCode.BadRequest/'Failed to retrieve the records' error path used for actual server failures.
- **Gap identified:** A legitimately empty filtered/paginated result set is returned through the exact same error path (ExceptionCode.BadRequest, 'Failed to retrieve the records') as an actual server failure.
- **Why it's a problem:** A user filtering to legitimately zero rows gets an API-level 'error' response indistinguishable from a real backend failure, breaking any client trying to distinguish 'no results' from 'something broke'.
- **Recommended solution:** Return a success envelope with data: [], totalCount: 0 for legitimately empty result sets; reserve the error path strictly for actual exceptions.
- **Production impact:** Affects effectively every list screen in the application.
- **Business impact:** Confusing/incorrect error semantics could surface to end users on legitimately empty filtered views.
- **Technical impact:** API contract cannot express 'zero matches' as a success state.
- **Evidence:** Base.API/EndPoints/Case/Queries/BeneficiaryQueries.cs:39-40 confirmed exact pattern `if (result.beneficiaries == null || !result.beneficiaries.Data.Any()) return ApiResponseHelper.ReturnPaginatedApiResponseError<BeneficiaryResponseDto>();` (also present at line 91-92 for GetBeneficiaryCases, line 62-63 for GetBeneficiary singular); Base.API/Extensions/ApiResponseHelper.cs:22-25 confirms `ReturnPaginatedApiResponseError<T>() => PaginatedApiResponse<IEnumerable<T>>.Error(ExceptionCode.BadRequest, ExceptionMessage.GetRecordsFailed)` — i.e. a genuinely empty result and a thrown exception are both routed to `ExceptionCode.BadRequest`/'Failed to retrieve...'; repo-wide grep for this pattern hit 183 files across nearly every module (Grant, Donation, Case, Contact, Setting, Auth, etc.), confirming systemic scope.
- **Reviewer note:** Code matches the finding exactly; scale claim (166+ files) is corroborated (183 files matched the broader search pattern including declaration sites, consistent with a systemic issue affecting effectively every list screen).

### #95 · GraphQL endpoint configuration (global — Base.API/Extensions/GraphQLRegistrationExtensions.cs, Base.API/DependencyInjection.cs, Base.API/Program.cs) — Query cost/depth limiting, introspection lock-down, and CORS policy  — `High`

- **Module:** API / GraphQL Contract  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** The GraphQL endpoint is registered with no query cost/depth limiter, introspection left enabled, `StrictValidation = false`, and CORS configured with `SetIsOriginAllowed(_ => true).AllowCredentials()` applied the same way in every environment.
- **Gap identified:** No query cost/depth limiting configured anywhere; introspection never disabled; `StrictValidation = false` explicitly set; CORS configured with `SetIsOriginAllowed(_ => true).AllowCredentials()` (wildcard origin + credentials), applied unconditionally with no environment/Development-vs-Production branching.
- **Why it's a problem:** Combined with unbounded eager-loading and unbounded pagination, an actor can craft expensive deeply-nested/fanned-out queries (aided by full introspection) that trigger unbounded DB work; wildcard CORS+credentials widens cross-origin credentialed attack surface.
- **Recommended solution:** Configure HotChocolate cost analysis (AddMaxExecutionDepthRule/field cost middleware) and execution timeout, disable introspection in production, restore StrictValidation, and replace the wildcard CORS origin predicate with an explicit allow-list.
- **Production impact:** Applies to the single shared GraphQL endpoint serving the entire application, unconditionally in all environments.
- **Business impact:** Increases DoS and reconnaissance risk against the production API; wildcard+credentials CORS is a standing cross-origin exposure.
- **Technical impact:** GraphQL endpoint has no cost/depth guardrails and full introspection exposure in the actual production configuration path (verified no environment branching excludes it).
- **Evidence:** Base.API/Extensions/GraphQLRegistrationExtensions.cs:54,58-61 confirmed (`.AddMutationConventions()` commented out, `StrictValidation = false`); repo-wide grep for MaxAllowedFieldCost/MaxExecutionDepth/ExecutionTimeout/BanIntrospection/DisableIntrospection/AddMaxExecutionDepthRule/AllowIntrospection returned zero matches anywhere in the backend; Base.API/DependencyInjection.cs:361-367 confirmed exact `app.UseCors(option => option.AllowAnyHeader().AllowAnyMethod().SetIsOriginAllowed(_ => true).AllowCredentials());` followed by `app.MapGraphQL()` at :386 with no cost/depth/introspection configuration; Base.API/Program.cs:51-56 confirms `app.UseApiServices()` (which contains this CORS/GraphQL setup) runs unconditionally before the only environment check in Program.cs (`if (app.Environment.IsDevelopment())`, used solely for DB seeding/Hangfire dashboard) — i.e. this configuration applies identically in production.
- **Reviewer note:** Fully confirmed at every layer with no environment-conditional mitigation found. The wildcard-origin+credentials CORS policy is a live, unconditional production exposure (not merely theoretical), which if anything argues for at least High and arguably Critical severity given it is a standing cross-origin credentialed-request vulnerability in production, compounded by unbounded introspection and absent cost/depth limits.

### #199 · All GraphQL list queries with child navigation properties (e.g. Base.Application/Business/GrantBusiness/Grants/GetAllQuery/GetGrants.cs) — Selection-set-aware projection / eager-loading efficiency  — `Medium`

- **Module:** API / GraphQL Contract  |  **Category:** technical  |  **Verification:** ADJUSTED
- **Current implementation:** GetGrantsHandler.Handle chains all 10 `.Include()` calls unconditionally on every grants-list call, with no DataLoader or HotChocolate UseProjection to trim the joins to the client's requested fields.
- **Gap identified:** Zero DataLoader/HotChocolate UseProjection usage exists anywhere. GetGrantsHandler.Handle unconditionally chains 10 `.Include()` calls on every grants-list call regardless of which fields the client actually requested.
- **Why it's a problem:** The database pays the cost of joining every related entity for every list request regardless of the client's actual field selection — real but bounded (per-page, single-query) over-fetching, not unbounded N+1 blowup.
- **Recommended solution:** If/when this becomes a measured bottleneck, adopt HotChocolate's [UseProjection] on list resolvers exposing entity types directly, or selectively trim Include() chains to only commonly-displayed columns; treat as a backlog optimization, not a release blocker.
- **Production impact:** Affects all list-style GraphQL queries across every module, but impact scales with page size (bounded), not table size (unbounded) — contingent on finding #2 being fixed.
- **Business impact:** Modest incremental DB load/latency as data volume grows; not an acute production risk on its own.
- **Technical impact:** Every list query fetches full related-entity graphs (via JOIN) regardless of client selection set, bounded by page size once pagination is enforced.
- **Evidence:** Base.Application/Business/GrantBusiness/Grants/GetAllQuery/GetGrants.cs:37-51 confirmed exact 10 chained `.Include()` calls (FunderContact, Currency, GrantType, PurposeProgram, Branch, Stage, Priority, AssignedStaff, ReportingFrequency, FinancialReportingFrequency) with no conditional selection-set awareness; repo-wide grep for UsePaging/UseSorting/UseFiltering/UseProjection returned zero matches, confirming HotChocolate's selection-set middleware is unused anywhere.
- **Reviewer note:** The underlying facts (10 unconditional Includes, zero UseProjection/DataLoader usage) are fully confirmed. However the framing overstates severity and mischaracterizes the mechanism: (1) this is 'N+1 avoidance' mislabeling — all 10 Include()s target to-one reference navigations (not collections), so EF Core generates a SINGLE SQL query with LEFT JOINs, not N+1 round-trips or cartesian row explosion; the real cost is extra JOIN columns per query, not N+1 queries. (2) The query result is bounded by ApplyGridFeatures' Skip/Take (page size), so in normal usage (once finding #2's pagination gap is fixed) this only over-fetches columns for a page's worth of rows, not the whole table — a modest efficiency cost, not the 'scales poorly / DB always pays full cost' framing implied. (3) This architecture is a consistent, intentional CQRS-with-fixed-DTO pattern applied identically across the whole codebase (confirmed: GraphQL resolvers return hand-shaped Response DTOs, not raw entity graphs), so adopting [UseProjection] would require significant, non-targeted rearchitecture rather than a scoped fix — this is a design trade-off, not a regression/bug. Downgraded from High to Medium and retitled from 'N+1 avoidance' to 'selection-set-aware projection / over-fetch efficiency' to match what the code actually does.

### #200 · GraphQL schema-wide (e.g. GrantStageHistoryResponseDto.AmountReceived in Base.Application/Schemas/GrantSchemas/GrantSchemas.cs, queried by GET_GRANT_BY_ID_QUERY) — Schema versioning / field deprecation  — `Medium`

- **Module:** API / GraphQL Contract  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** GrantStageHistoryResponseDto.AmountReceived remains a plain, undecorated schema field that FE's GET_GRANT_BY_ID_QUERY still actively queries, with no `@deprecated`/`[GraphQLDeprecated]` directive anywhere in the schema.
- **Gap identified:** No `@deprecated` directive (nor `[GraphQLDeprecated]`) exists anywhere in the schema (confirmed via grep). At least one confirmed case — `GrantStageHistoryResponseDto.AmountReceived` — has BE code comments explicitly stating it is superseded by the new `GrantFundReceipt` ledger, yet it remains a live, undeprecated field that the FE still actively queries (`GET_GRANT_BY_ID_QUERY` in GrantQuery.ts, `stageHistory { ... amountReceived ... }`).
- **Why it's a problem:** With no versioning/deprecation mechanism anywhere in the schema, there is no way for API consumers (including the team's own FE, and any future external integrator) to discover that a field is legacy and should be migrated off, nor any safe path to eventually remove superseded fields without a breaking, un-signaled change.
- **Recommended solution:** Adopt HotChocolate's `[GraphQLDeprecated("reason")]` attribute (or equivalent schema-first `@deprecated` directive) on known-legacy fields such as `AmountReceived`, and establish a standing convention requiring deprecation markers before any field is superseded.
- **Production impact:** Low immediate risk, but compounds over time as more fields get superseded without any deprecation trail.
- **Business impact:** Future schema cleanup work has no safe, discoverable deprecation path and risks breaking undocumented consumers.
- **Technical impact:** No machine-readable signal exists anywhere in the schema for superseded/legacy fields.
- **Evidence:** PSS_2.0_Frontend/src/infrastructure/gql-queries/grant-queries/GrantQuery.ts line ~226 (`stageHistory { ... amountReceived ... }` in GET_GRANT_BY_ID_QUERY); repo-wide grep for `@deprecated`/`GraphQLDeprecated`/`AddMutationConventions` deprecation usage returned no real matches
- **Reviewer note:** not adversarially verified (Medium/Low)

### #305 · Grant DTOs and equivalents across schemas (e.g. Base.Application/Schemas/GrantSchemas/GrantSchemas.cs GrantRequestDto/GrantResponseDto) — GraphQL nullability correctness  — `Low`

- **Module:** API / GraphQL Contract  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** GrantRequestDto/GrantResponseDto and nearly every other schema DTO declare always-populated fields, including primary keys like GrantId, as C# nullable types, which HotChocolate then reflects as nullable in the GraphQL schema.
- **Gap identified:** Primary-key and always-populated fields are declared as C# nullable (`public int? GrantId { get; set; }` on GrantRequestDto, inherited into GrantResponseDto) even though a returned row can never actually have a null `GrantId`. This pattern is consistent across essentially every DTO in the schema — nearly all properties are nullable regardless of whether the underlying value is ever actually absent.
- **Why it's a problem:** HotChocolate infers GraphQL schema nullability directly from the C# nullable-reference/value annotations. Marking fields that are always present (like a primary key on a response object) as nullable forces every FE consumer to defensively null-check or use non-null assertions (`grantId!`) on values that are contractually guaranteed to exist, defeating one of GraphQL's core benefits (precise nullability contracts) and masking the cases where a field is genuinely optional from ones that are just carelessly annotated.
- **Recommended solution:** Split request/response DTO nullability deliberately: on response DTOs, mark identity and guaranteed-populated fields (e.g. `GrantId`, `GrantCode` once created) as non-nullable, reserving `?` for fields that can genuinely be absent (e.g. `AwardedAmount` before an award decision).
- **Production impact:** Cosmetic/systemic rather than a functional blocker on its own, but indicates the schema was not deliberately designed around nullability semantics.
- **Business impact:** Low direct business impact; mainly a code-quality/DX cost paid by every FE consumer of the schema.
- **Technical impact:** GraphQL schema nullability does not reflect true data guarantees, degrading client-side type safety.
- **Evidence:** Base.Application/Schemas/GrantSchemas/GrantSchemas.cs lines 126-138 (GrantRequestDto: `public int? GrantId { get; set; }`, inherited by GrantResponseDto at line 171) — the same over-nullable pattern repeats across the DTO's ~40 properties (lines 171-209)
- **Reviewer note:** not adversarially verified (Medium/Low)

## Currency / FX / Decimal / Timezone

### #17 · Donation Entry — Global Donation Create/Edit Form (crm/donation/globaldonation) — Manual donation entry — exchange rate persistence  — `Critical`

- **Module:** Currency / FX / Decimal / Timezone  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** CreateGlobalDonation.cs:21 (and identically UpdateGlobalDonation.cs:22) only run ValidatePropertyIsRequired on ExchangeRate — a non-null check, no GreaterThan(0)/range check. CreateGlobalDonationHandler.Handle (lines 48-53/61) and UpdateGlobalDonationHandler.Handle (lines 51-62) do a straight `Adapt<GlobalDonation>()`/`Adapt(entity)` from the client DTO and save — neither handler references IFxRateService (confirmed via grep: IFxRateService is used in 16 files across the codebase — PromoteOnlineDonationStaging, ResolveOnlineDonationStaging, CompleteRefund, GrantFxSnapshot, RecordProgramFundingTransfer, CreateGrantFundReceipt, etc. — and CreateGlobalDonation/UpdateGlobalDonation are not among them).
- **Gap identified:** The primary manual/staff Global Donation entry path (both Create and Update) accepts whatever ExchangeRate + BaseCurrencyAmount the client sends, with zero server-side verification against the authoritative FX rate table, and zero minimum-value validation.
- **Why it's a problem:** A compromised/buggy client, stale cached FE rate, or a direct GraphQL mutation call (bypassing the FE form's rate lookup) can post an arbitrary ExchangeRate/BaseCurrencyAmount pair that feeds every downstream donation aggregate, dashboard KPI, and financial rollup with no server-side backstop — and this affects both the initial Create and any subsequent Update.
- **Recommended solution:** In both CreateGlobalDonationHandler and UpdateGlobalDonationHandler, server-side re-resolve the rate via IFxRateService.GetRateAsync(fromCode, toCode, donationDate) whenever CurrencyId != BaseCurrencyId, and either reject on excessive deviation from the resolved rate or overwrite ExchangeRate/BaseCurrencyAmount server-side, permitting client override only via an explicit audited 'manual rate' flag (mirroring the ResolveOnlineDonationStaging override pattern already built for the online-donation path).
- **Production impact:** Financial data integrity risk in the primary donation-entry path used by every staff member for every manual donation across all tenants, on both create and edit.
- **Business impact:** Misstated donor-currency-to-base-currency conversions directly misstate donation revenue reporting to nonprofit boards/auditors/regulators.
- **Technical impact:** GlobalDonation.BaseCurrencyAmount — the field every downstream aggregate/report trusts as safe-to-sum — has no server-side correctness guarantee on the flagship manual-entry path, undermining the multi-currency aggregation model that IS correctly enforced on the online-donation and refund paths.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/GlobalDonations/Commands/CreateGlobalDonation.cs:21,48-53; PSS_2.0_Backend/.../GlobalDonations/Commands/UpdateGlobalDonation.cs:22,51-62; contrast the 16 files that do call IFxRateService including ResolveOnlineDonationStaging.cs, CompleteRefund.cs, GrantFxSnapshot.cs

### #110 · Ambassador Collection — Create Collection form — Back-dated / high-value auto-approval branching using server-local date  — `High`

- **Module:** Currency / FX / Decimal / Timezone  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** Confirmed verbatim: CreateAmbassadorCollection.cs:38 `RuleFor(x => x.ambassadorCollection.CollectedDate).LessThanOrEqualTo(DateTime.Today)`; handler line 53 `var today = DateTime.Today;` and line 54 `var isBackDated = entity.CollectedDate.Date < today.AddDays(-BackDateThresholdDays);` branches the auto-approval Status. Contrast confirmed: GetAmbassadorCollectionSummary.cs:25-27 explicitly documents 'DateTime.Today returns Kind=Unspecified' and uses `DateTime.UtcNow.Date` instead.
- **Gap identified:** A business-critical auto-approval decision (auto-verify vs. hold for approval) is driven by the application server's local system time-zone date rather than UTC, in the same feature area where the sibling summary query was explicitly fixed for this exact issue.
- **Why it's a problem:** If the app server's local time zone differs from UTC/the tenant's timezone, a collection entered near a day boundary can be misclassified as back-dated or not, inconsistently, depending on server-local midnight rather than any tenant-meaningful boundary — a non-deterministic bug for a fraud/error control given the app serves multiple tenants from one server clock.
- **Recommended solution:** Replace `DateTime.Today` with `DateTime.UtcNow.Date` in both the validator and handler, matching the already-documented correct pattern in GetAmbassadorCollectionSummary.cs.
- **Production impact:** Non-deterministic back-date/high-value classification depending on server deployment timezone.
- **Business impact:** Ambassador collections near day boundaries can be inconsistently auto-verified vs. held for approval, undermining the fraud/error control this threshold exists to enforce.
- **Technical impact:** Reintroduces the exact Npgsql Kind=Unspecified risk class the team documented and fixed elsewhere in the same feature area, indicating the fix was not applied uniformly across sibling files.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/FieldCollectionBusiness/AmbassadorCollections/Commands/CreateAmbassadorCollection.cs:38,53-54; contrast PSS_2.0_Backend/.../AmbassadorCollections/Queries/GetAmbassadorCollectionSummary.cs:25-27

### #111 · Cross-cutting — all FX snapshot/rounding call sites (Grant, Refund, Donation, Recurring Schedule, Pledge, Campaign, Membership, Volunteer, Ambassador summaries) — Decimal precision of converted/aggregated monetary amounts  — `High`

- **Module:** Currency / FX / Decimal / Timezone  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** Confirmed: Currency.cs:24 defines `public int DecimalPlaces { get; set; } = 2;` with an ISO-4217 comment ('fixed set 0/2/3'). A grep of `Math.Round(...,2)` across Base.Application returns 96 occurrences across 53 files (more than the 41/27 originally cited), including the specifically-checked GrantFxSnapshot.cs:41 `Math.Round(amount * rate.Value, 2)`. A grep of `DecimalPlaces` across all of Base.Application returns only 2 hits — CurrencySchemas.cs and SharedMappings.cs — i.e. it is exposed via DTO/GraphQL mapping only and is never read by any rounding/business-logic call site.
- **Gap identified:** Currency.DecimalPlaces is a modeled, ISO-4217-aware field that is never consulted anywhere the codebase rounds a converted or aggregated monetary amount — confirmed dead for computational purposes (only surfaces in schema/mapping code, never in a Math.Round or business calculation).
- **Why it's a problem:** For a zero-decimal currency (JPY, KRW) amounts get spuriously rounded to fractional units that can never exist; for a three-decimal currency (KWD, BHD, OMR) amounts lose their legitimate third decimal — both produce monetary values that don't match the real-world minor-unit convention of the currency.
- **Recommended solution:** Introduce a shared helper (e.g. `CurrencyRounding.Round(amount, currency.DecimalPlaces)`) and route every FX-snapshot/aggregation rounding call site through it instead of the literal `,2)` constant, prioritizing the money-bearing call sites (GrantFxSnapshot, CompleteRefund, CreateRefund, CreatePledge, UpdatePledge, CreateRecurringDonationSchedule) over the non-money ones (e.g. email-analytics percentage rounding, which is a different, lower-priority class of the same pattern).
- **Production impact:** Systemic decimal-precision defect across every module that converts or aggregates monetary values in a non-2-decimal currency.
- **Business impact:** Financial records for organizations operating in zero- or three-decimal currencies will not match real-world currency minor units, a material accounting-accuracy defect for any tenant using such currencies.
- **Technical impact:** A modeled, purpose-built field (Currency.DecimalPlaces) is effectively dead code for computation — present in the schema/domain model but never read by any rounding call site; note the actual scope is larger than originally cited (96 occurrences/53 files, though a portion of those are non-monetary e.g. email analytics percentages, not all money-rounding).
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/Currency.cs:23-24; PSS_2.0_Backend/.../SharedBusiness/Currencies/GrantFxSnapshot.cs:41; grep confirms DecimalPlaces referenced only in CurrencySchemas.cs and SharedMappings.cs codebase-wide

### #112 · Cross-cutting — canonical FE amount formatter (companySettingsFormatters.ts) — Application-wide currency display precision  — `High`

- **Module:** Currency / FX / Decimal / Timezone  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** Confirmed verbatim: formatCurrency() lines 108-111 hardcodes `minimumFractionDigits: opts.minimumFractionDigits ?? 2, maximumFractionDigits: opts.maximumFractionDigits ?? 2` with no per-currency decimal-place lookup; FormatCurrencyOptions (lines 87-93) only accepts currencyCode/currencySymbol/displayFormat overrides, never a decimal-places parameter tied to actual currency master data.
- **Gap identified:** The one FE module purpose-built to be the single canonical, tenant-aware currency formatter still has no per-currency decimal-place awareness — every caller that doesn't explicitly override gets 2 decimals regardless of the amount's actual currency.
- **Why it's a problem:** Even after fixing individual call sites to route through this canonical formatter, JPY/KWD-style currencies will still display incorrectly unless every call site remembers to pass decimal-places explicitly — the root formatter should default correctly so callers don't have to.
- **Recommended solution:** Extend FormatCurrencyOptions with an optional `currencyDecimalPlaces` (or accept a Currency object) and use it to derive min/max fraction digits by default instead of the hardcoded 2; expose org currency master data (with DecimalPlaces) to the FE so callers can pass it through.
- **Production impact:** Root-cause gap underlying multiple downstream currency-display defects across the FE codebase.
- **Business impact:** Any tenant using a non-2-decimal base or donor currency sees incorrectly formatted amounts throughout the application, even in the 'correctly built' canonical formatter path.
- **Technical impact:** Fixing individual call sites without also fixing this root formatter only shifts the defect, it does not resolve it for JPY/KWD-style tenants.
- **Evidence:** PSS_2.0_Frontend/src/presentation/utils/companySettingsFormatters.ts:87-93,108-111

### #113 · Currency Management (#79) — Update Rates modal — Admin 'Batch Update Auto Rates' button  — `High`

- **Module:** Currency / FX / Decimal / Timezone  |  **Category:** currency  |  **Verification:** ADJUSTED
- **Current implementation:** BatchUpdateAutoRates.cs:20-40 is an explicit, self-labeled `SERVICE_PLACEHOLDER` handler that does `await Task.CompletedTask;` and always returns `{Success=true, RowsAdded=0, Message="Auto-rate fetch pending OpenExchangeRates integration"}`. The Currency Management screen's update-rates-modal.tsx wires its 'Update Now' button to exactly this stub mutation (BATCH_UPDATE_AUTO_RATES_MUTATION), not to TriggerOpenExchangeRatesSyncCommand. HOWEVER, verification found a SECOND, separate, fully-working admin surface: the 'Currency Exchange Rates' (Currency Conversion) screen's data-table.tsx:91-115 has its own 'Sync Now' button correctly wired to TRIGGER_OPEN_EXCHANGE_RATES_SYNC_MUTATION → TriggerOpenExchangeRatesSyncCommand → IOpenExchangeRatesSyncJob.RunOnceAsync (the real, production-quality sync implementation), and correctly reads back real success/rowsAdded/error from the response.
- **Gap identified:** The 'Update Rates' action on the Currency Management screen (#79) is a dead stub that always fake-reports success while a second, correctly-wired 'Sync Now' action already exists and works on the sibling Currency Conversion screen — i.e. this is a duplicate/broken control on ONE screen, not a total absence of the capability from the product.
- **Why it's a problem:** An admin using the Currency Management screen's 'Update Rates' button believes rates were refreshed (toast shows the placeholder message, RowsAdded always 0) when nothing happened; they must know to instead navigate to the separate Currency Conversion screen to actually trigger a sync. This is confusing/duplicate UX and a broken control on a screen presented as the currency admin surface, but it is not a full product gap since a working manual-refresh path is reachable elsewhere.
- **Recommended solution:** Either remove the redundant 'Update Rates' modal/button from Screen #79 and point users to the working Currency Conversion screen's 'Sync Now', or repoint BatchUpdateAutoRatesHandler to call IOpenExchangeRatesSyncJob.RunOnceAsync (same call TriggerOpenExchangeRatesSyncHandler already makes) so both buttons perform the real sync.
- **Production impact:** One admin screen has a fake action, but the actual FX-refresh capability is not absent from the product — it's just discoverable only via a different screen.
- **Business impact:** Confusing dual-surface admin UX; an admin who only ever uses the Currency Management screen (the more discoverable/named one) will believe rates are refreshing when they are not.
- **Technical impact:** Duplicate/competing command implementations for the same feature (TriggerOpenExchangeRatesSync — real — vs BatchUpdateAutoRates — stub) is a maintenance hazard; the wrong one is wired to the #79 screen.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SharedBusiness/Currencies/Commands/BatchUpdateAutoRates.cs:20-40; PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currency/update-rates-modal.tsx:52-81; PSS_2.0_Backend/.../CurrencyConversions/Commands/TriggerOpenExchangeRatesSync.cs:29-51; PSS_2.0_Frontend/src/presentation/components/page-components/general/masters/currencyconversion/data-table.tsx:91-115
- **Reviewer note:** Downgraded from Critical to High: the original finding characterized this as leaving admins with 'no way to manually refresh FX rates,' but a working, correctly-implemented manual-sync control already exists and is shipped on the Currency Conversion screen (data-table.tsx:91-115), so the capability is not actually missing from production — only duplicated/broken on one specific screen.

### #114 · Online Donation Inbox — Resolve/Promote staging record — Cross-currency online donation FX resolution on promote  — `High`

- **Module:** Currency / FX / Decimal / Timezone  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** ResolveOnlineDonationStaging.cs:145-172 confirmed as described: `var exchangeRate = 1m;` default; for cross-currency staging rows it calls `fxRateService.GetRateAsync(fromCode, toCode, asOfDate, ...)` and only overwrites `exchangeRate` `if (rate is > 0m)` — otherwise the 1:1 fallback silently stands, per the code's own comment block (lines 145-150) acknowledging this is 'legacy behaviour that never blocks the promote.' `baseCurrencyAmount = staging.Amount * exchangeRate` is computed from this value with no flag written. Confirmed via grep of the GlobalDonation domain model that no RateSource/IsRateFallback/IsEstimatedRate-type field exists anywhere to mark this.
- **Gap identified:** When no configured FX rate exists for a cross-currency online donation, the system silently records BaseCurrencyAmount at 1:1 parity rather than surfacing this as an exception requiring staff attention, and there is no persisted marker distinguishing a resolved real rate from this fallback.
- **Why it's a problem:** A donation in a currency with no configured rate to the org's base currency is recorded as if 1:1, understating/overstating true base-currency value with no audit trail — staff resolving the inbox have no visual cue the rate used was a fallback, and the resulting GlobalDonation row is indistinguishable from a properly-rated one after the fact.
- **Recommended solution:** Persist a boolean/enum RateSource marker (e.g. 'FallbackParity') on the promoted GlobalDonation row when this path is hit, and surface a warning in the Online Donation Inbox resolve dialog so staff can correct the rate before finalizing.
- **Production impact:** Silent data-quality gap in the automated online-donation promotion pipeline.
- **Business impact:** Base-currency donation totals can be silently wrong for any currency pair missing a configured rate.
- **Technical impact:** No machine-readable marker distinguishes a real resolved rate from a 1:1 fallback on the persisted row, making retroactive audit/correction impossible without re-deriving from raw staging history.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/OnlineDonationInbox/Commands/ResolveOnlineDonationStaging.cs:145-172

### #222 · Ambassador Collection Distribution — Ambassador collection distribution currency snapshot  — `Medium`

- **Module:** Currency / FX / Decimal / Timezone  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** AmbassadorCollectionDistribution.ExchangeRate is a modeled domain field, but a grep for 'ExchangeRate' across the entire Base.Application/Business/FieldCollectionBusiness folder returns zero matches.
- **Gap identified:** Same dead-field pattern as the Membership finding above: the Ambassador distribution model carries an ExchangeRate column that no command/handler in the Ambassador feature area ever populates or reads.
- **Why it's a problem:** If an ambassador collects donations in a currency other than the org base currency and those collections are later distributed/allocated, there is no snapshot of the conversion rate used, making downstream distribution reporting currency-unsafe for any non-base-currency ambassador collection.
- **Recommended solution:** Audit whether AmbassadorCollectionDistribution ever needs to carry a currency different from its parent AmbassadorCollection; if cross-currency distribution is a real scenario, wire FX snapshot via IFxRateService at distribution-create time, following the GrantFxSnapshot pattern. If it is never cross-currency in practice, remove the unused column to avoid future confusion.
- **Production impact:** Dead/unwired currency field in a module explicitly flagged in Pending.txt item #15 ('Ambassador module full testing') as needing full business-flow testing.
- **Business impact:** Ambassador collection distribution reporting cannot be trusted to be currency-safe if any cross-currency scenario occurs in production.
- **Technical impact:** Confirms the same 'modeled-but-unwired ExchangeRate field' pattern recurs across at least two independent modules (Membership, Ambassador), suggesting a systemic process gap where FX snapshot wiring is not a mandatory checklist item when new financial-child-entities are added.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/FieldCollectionModels/AmbassadorCollectionDistribution.cs:19; zero grep matches for 'ExchangeRate' anywhere under PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/FieldCollectionBusiness
- **Reviewer note:** not adversarially verified (Medium/Low)

### #223 · Contact Profile — Donation History tab — Donation amount display in Contact's donation history detail dialog  — `Medium`

- **Module:** Currency / FX / Decimal / Timezone  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** contact-donation-history.tsx:27-34 defines a local `formatAmount(amount, currencyName)` that calls `amount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })` — browser-default locale grouping, hardcoded 2 decimals, and prefixes the raw `currencyName` string rather than using the org's configured currencyDisplayFormat (SymbolBefore/SymbolAfter/IsoCodeBefore).
- **Gap identified:** The screen Pending.txt item 1 explicitly names ('contact and amount displayed areas') as still needing full currency-handling coverage is confirmed still on the old ad-hoc formatting pattern rather than the canonical companySettingsFormatters.ts.
- **Why it's a problem:** For an org configured with EU (1.234.567,89) or Indian-lakh (12,34,567.89) number grouping, this dialog will show US-style grouping regardless, because `toLocaleString(undefined, ...)` uses the browser's OS/locale default, not the tenant's configured Number Format setting — inconsistent with every other properly-formatted amount elsewhere in the app.
- **Recommended solution:** Replace the local formatAmount with `formatCurrency` from companySettingsFormatters.ts, passing `currencyCode: selectedDonation.currency?.currencyCode` so both number grouping and currency layout honor the tenant's configured settings.
- **Production impact:** Confirmed live production gap directly named in Pending.txt item 1.
- **Business impact:** International tenants (EU, Indian-grouping orgs) see donation amounts formatted in a foreign convention on a customer-facing (staff-facing) screen, undermining the multi-tenant number-format feature that was built specifically to solve this.
- **Technical impact:** One more of several independent, divergent local currency-formatting implementations found across the FE (see companySettingsFormatters.ts and public/p2pcampaignpage/templates/shared.tsx findings) instead of the single canonical formatter.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/page-components/crm/contact/contact/contact-donation-history.tsx:27-34,50
- **Reviewer note:** not adversarially verified (Medium/Low)

### #224 · Event Analytics Dashboard widgets (Revenue Total KPI, ROI Table, Revenue Breakdown) — Per-widget currency amount display  — `Medium`

- **Module:** Currency / FX / Decimal / Timezone  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** dashboards/widgets/event-analytics-widgets/_shared.tsx exports a local `formatCurrency(amount, _code?)` that explicitly ignores its second parameter (documented in-code as intentional: '...always labels amounts with the org's base currency...The legacy `code` argument is intentionally ignored'). EventRevenueTotalKpiWidget.tsx destructures a real `currencyCode` from its backing query row (interface TotalRevenueData) and passes it through, but per _shared.tsx that value is discarded and the org's base currency is always used for the label.
- **Gap identified:** Every event-analytics widget displays amounts labeled with the tenant's base currency regardless of what currency the underlying aggregated figure (e.g., event ticket revenue, ROI) is actually denominated in at the row level.
- **Why it's a problem:** If the backing query (admin-configurable per widget via useWidgetFirstRow) ever returns a currency-specific raw amount rather than an already-normalized BaseCurrencyAmount, this widget will mislabel it as the org's base currency, silently misrepresenting the figure to whoever views the dashboard — the comment's assumption that the amount is always 'multi-tenant correct' base-currency data is not verified anywhere in this widget layer itself.
- **Recommended solution:** Either (a) enforce and document at the query-authoring layer that every event-analytics widget's amount field MUST be pre-converted to base currency before reaching the widget (with a validation/lint step), or (b) stop discarding the per-row currencyCode and display it faithfully so a non-base-currency figure is never silently mislabeled.
- **Production impact:** Dashboard KPI figures could display a mismatched currency label if any admin-configured widget query supplies a non-base-currency amount.
- **Business impact:** Leadership-facing dashboard revenue figures risk silent currency mislabeling, undermining trust in the new dashboard module (Pending.txt item #21 'Dashboard development').
- **Technical impact:** The 'legacy code argument intentionally ignored' design decision bakes in an unverified assumption about upstream data shape across all widgets sharing this _shared.tsx module, not just this one.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/event-analytics-widgets/_shared.tsx:1-50 (formatCurrency ignoring _code); PSS_2.0_Frontend/.../event-analytics-widgets/EventRevenueTotalKpiWidget.tsx:16-21,36,70,75 (currencyCode destructured then discarded)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #225 · Membership — Manual/Webhook Renewal payment transaction recording — Membership payment transaction currency snapshot  — `Medium`

- **Module:** Currency / FX / Decimal / Timezone  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** MembershipPaymentTransaction.ExchangeRate is a nullable decimal field on the domain model, but MembershipManualRenewalService.cs populates `CurrencyId` at both construction sites (lines 141 and 230) and never assigns `ExchangeRate`. A grep across the entire Base.Application/Business/MemBusiness folder for 'ExchangeRate' returns zero matches — the field is never read or written by any Membership command/handler.
- **Gap identified:** The Membership module has a modeled ExchangeRate field for its payment transactions (mirroring the pattern used correctly by GlobalDonation and Grant flows) but it is entirely unwired — never populated on create, so it is always null.
- **Why it's a problem:** Any membership plan/renewal paid in a currency other than the org's base currency has no recorded conversion rate at all, unlike Donations and Grants which snapshot the rate at write time; any future multi-currency membership revenue rollup has no way to safely aggregate MembershipPaymentTransaction amounts across currencies.
- **Recommended solution:** Wire MembershipManualRenewalService (and MembershipRenewalWebhookService) to call IFxRateService.GetRateAsync when the payment CurrencyId differs from the org base currency, and snapshot both ExchangeRate and a BaseCurrencyAmount-equivalent field, following the same GrantFxSnapshot pattern already established elsewhere.
- **Production impact:** Membership module (explicitly listed as Pending.txt item #18 'implementation') is missing FX snapshot wiring that other financial modules already have.
- **Business impact:** Multi-currency membership revenue cannot be safely aggregated/reported against the org's base currency; any such report today would either omit or misrepresent non-base-currency memberships.
- **Technical impact:** A modeled column (ExchangeRate) sits permanently null — dead field, no code path populates it.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/MemModels/MembershipPaymentTransaction.cs:46; PSS_2.0_Backend/.../Services/Memberships/MembershipManualRenewalService.cs:141,153,230,241 (CurrencyId set, ExchangeRate never referenced)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #226 · Public CrowdFund Donate Form (public/crowdfundingpage/donate-form.tsx) — Donor-facing amount display + payment gateway drop-in wallet-button amount  — `Medium`

- **Module:** Currency / FX / Decimal / Timezone  |  **Category:** uiux  |  **Verification:** ADJUSTED
- **Current implementation:** Line 66's `${currency} ${value.toLocaleString()}` is only the CATCH fallback of formatAmount(); the primary path (lines 59-64) uses `Intl.NumberFormat` with `style:'currency'` but hardcodes `maximumFractionDigits:0` for every currency (a real but display-only quirk — it forces whole-unit display even for 2-decimal currencies, not the claimed 'ignores format entirely'). Line 222's `(effectiveAmount ?? 0).toFixed(2)` is used ONLY to populate `options.paypal.amount` and `options.googlePay.transactionInfo.totalPrice` inside the Braintree Drop-in config (lines 222-240) — i.e. the wallet button's displayed/consent amount, not the actual charge. Verified in ConfirmCrowdFundDonation.cs:183-189 that the REAL Braintree charge is `Amount = staging.Amount` — a server-persisted, server-validated decimal (validated against min/max/allowed-chip amounts in InitiateCrowdFundDonation.cs:242-262) — completely independent of the FE's toFixed(2)/formatAmount functions.
- **Gap identified:** The FE display and Braintree-Dropin wallet-button amount formatters are not currency-decimal-aware (always force either 0 or 2 fraction digits regardless of the currency's real minor-unit convention), but the actual money movement is NOT driven by these values — the server computes and charges `staging.Amount` directly via Braintree's TransactionRequest.Amount, independently re-validated server-side.
- **Why it's a problem:** For a zero-decimal currency (JPY) or three-decimal currency (KWD/BHD), the PayPal/Google Pay wallet button inside the Braintree Drop-in could show a mismatched or malformed amount to the donor during consent (a real, if narrow, UX/trust defect and possible wallet-API rejection), and the on-page amount chips/summary would also display incorrectly-precisioned figures. But this does NOT translate into an actual over/under-charge in settlement, since the settled amount is the server-side `staging.Amount` decimal, not the client's formatted string.
- **Recommended solution:** Make formatAmount() and the Drop-in wallet amount currency-decimal-aware (derive fraction digits from the currency's actual minor-unit convention instead of hardcoding 0/2), and route display through the canonical formatter for consistency. Lower priority than a payments-correctness defect since real money is not at risk.
- **Production impact:** Cosmetic/wallet-consent-screen amount-precision inconsistency for non-2-decimal currencies on the public donate form; no impact on the actual amount charged/settled.
- **Business impact:** Potential donor confusion or wallet-checkout friction for tenants operating in 0- or 3-decimal currencies, not a financial-correctness or overcharge risk.
- **Technical impact:** No shared, currency-decimal-aware amount formatter is used for the public donate form's display/wallet-config layer, but the settlement layer (ConfirmCrowdFundDonation.cs) already correctly uses the server-trusted decimal amount, so this is a display-layer defect, not a payments-integrity defect.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/page-components/public/crowdfundingpage/donate-form.tsx:58-68,222-240; PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/CrowdFunds/Commands/ConfirmCrowdFundDonation.cs:183-189; InitiateCrowdFundDonation.cs:242-262
- **Reviewer note:** Downgraded from Critical/payments to Medium/uiux: the original finding claimed real charge amounts risk being 'wrong by an order of magnitude,' but the actual Braintree Sale call (ConfirmCrowdFundDonation.cs:183-189) charges `staging.Amount`, a server-validated decimal independent of the client's toFixed(2)/formatAmount() functions — those only feed the wallet button's display/consent amount and the on-page amount labels, not the settled transaction amount.

### #227 · Public P2P Campaign Page — donor-facing templates — Donation amount display on public fundraiser page  — `Medium`

- **Module:** Currency / FX / Decimal / Timezone  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** public/p2pcampaignpage/templates/shared.tsx exports a local `formatCurrency(value, code)` using `Intl.NumberFormat` with `maximumFractionDigits: 0` hardcoded and `currency: code || "USD"` — defaulting to USD whenever the currency code is absent, and always rounding to whole units regardless of the actual currency's decimal convention or the org's configured base currency.
- **Gap identified:** A second, independent, divergent currency formatter exists on the public donor-facing P2P page, diverging from the canonical companySettingsFormatters.ts in both decimal precision (hardcoded 0) and default-currency fallback (hardcoded USD instead of the org's actual base currency).
- **Why it's a problem:** A non-US, non-USD tenant whose fundraiser page ever renders an amount without an explicit currency code (e.g., a loading/placeholder state) would show a '$' formatted figure that has nothing to do with the org's actual currency, and legitimate sub-unit donation amounts get silently truncated to whole numbers on the public page donors see before pledging.
- **Recommended solution:** Remove this bespoke formatter and route through companySettingsFormatters.ts (or a public-page-safe re-export of it) so decimal precision and currency defaulting are consistent with the rest of the application.
- **Production impact:** Public donor-facing page shows amounts in a hardcoded format independent of the tenant's actual currency/decimal configuration.
- **Business impact:** Donors on non-USD tenant fundraiser pages may see incorrectly formatted or mislabeled amounts, hurting trust at the exact moment they are deciding to donate.
- **Technical impact:** Third confirmed independent reimplementation of currency formatting logic in the FE codebase (alongside event-analytics-widgets/_shared.tsx and contact-donation-history.tsx), each with different, incompatible defaults.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/page-components/public/p2pcampaignpage/templates/shared.tsx:1-18
- **Reviewer note:** not adversarially verified (Medium/Low)

### #228 · Volunteer Hour Log — Create / Update / Log-and-Approve / Summary / Aggregate-by-Volunteer — Date boundary computation for hour-log validation and aggregation  — `Medium`

- **Module:** Currency / FX / Decimal / Timezone  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** CreateVolunteerHourLog.cs:37,39, LogAndApproveVolunteerHourLog.cs:33,35, UpdateVolunteerHourLog.cs:40, GetVolunteerHourLogSummary.cs:24 and GetVolunteerHourLogAggregateByVolunteer.cs:30 all use `DateOnly.FromDateTime(DateTime.Today)` to derive 'today' for validation/aggregation boundaries, rather than `DateTime.UtcNow`.
- **Gap identified:** Five files in the Volunteer Hour Log feature repeat the same server-local-time pattern that the Ambassador Collection module's own summary query documents as incorrect for a Postgres timestamptz-backed system.
- **Why it's a problem:** Volunteer hour-log date validation (e.g., 'cannot log hours for a future date') and monthly/period aggregation boundaries computed from server-local time will drift from the tenant's actual calendar day whenever the app server's local timezone differs from the org's configured timezone, causing valid entries to be rejected or aggregation periods to be off by a day around midnight boundaries.
- **Recommended solution:** Standardize all five files on `DateOnly.FromDateTime(DateTime.UtcNow)` (or a tenant-timezone-aware 'today' helper if the org's local business day must be honored), consistent with the documented-correct pattern already present in the codebase.
- **Production impact:** Volunteer hour submissions and reporting periods can be off-by-one-day depending on server deployment location relative to tenant timezone.
- **Business impact:** Volunteer hour tracking (an explicit Pending.txt item — #16/#17 Volunteer module) risks rejecting legitimate entries or misattributing hours to the wrong reporting period.
- **Technical impact:** Repeats an already-identified anti-pattern across 5 files instead of using a single shared UTC-safe date helper, increasing future maintenance risk.
- **Evidence:** PSS_2.0_Backend/.../ApplicationBusiness/VolunteerHourLogs/CreateQuery/CreateVolunteerHourLog.cs:37,39; .../LogAndApproveVolunteerHourLog.cs:33,35; .../UpdateVolunteerHourLog.cs:40; .../GetSummaryQuery/GetVolunteerHourLogSummary.cs:24; .../GetAggregateByVolunteerQuery/GetVolunteerHourLogAggregateByVolunteer.cs:30
- **Reviewer note:** not adversarially verified (Medium/Low)

### #315 · CrowdFund public/admin stats & listing (5 query handlers) — CrowdFund FX-fallback conversion logic  — `Low`

- **Module:** Currency / FX / Decimal / Timezone  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** GetCrowdFundStats.cs, GetCrowdFundBySlug.cs, GetCrowdFundById.cs, GetAllCrowdFundList.cs, and GetCrowdFundPublicStats.cs each contain an independently duplicated, identical inline LINQ expression implementing the same FX-fallback conversion logic for CrowdFund currency amounts, rather than sharing a single helper (unlike the Grant module's shared GrantFxSnapshot.cs).
- **Gap identified:** The same currency-fallback business rule is copy-pasted five times across independent query handlers instead of being centralized.
- **Why it's a problem:** Any future correction to the CrowdFund FX-fallback policy (e.g., to fix the same class of silent-1:1-fallback issue found in ResolveOnlineDonationStaging.cs) requires five synchronized edits; a missed file leaves an inconsistent/incorrect FX behavior in production for that specific query while the others are fixed.
- **Recommended solution:** Extract the duplicated LINQ expression into a shared static helper (mirroring GrantFxSnapshot.cs's pattern for Grant flows) and have all five CrowdFund query handlers call it.
- **Production impact:** Maintainability/consistency risk rather than an active production defect today, but elevates regression risk on any future FX policy change to CrowdFund.
- **Business impact:** Increases the chance that a future FX bug-fix is applied inconsistently across CrowdFund's public and admin surfaces, producing user-visible discrepancies between screens showing the same underlying campaign.
- **Technical impact:** DRY violation across 5 files in the DonationBusiness/CrowdFunds/Queries folder; no single source of truth for CrowdFund FX handling.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/CrowdFunds/Queries/GetCrowdFundStats.cs; GetCrowdFundBySlug.cs; GetCrowdFundById.cs; GetAllCrowdFundList.cs; GetCrowdFundPublicStats.cs
- **Reviewer note:** not adversarially verified (Medium/Low)

### #316 · Saved Filters (Duplicate) / Report Catalog (Last Run Date) — Timestamp assignment on entity duplication / report metadata  — `Low`

- **Module:** Currency / FX / Decimal / Timezone  |  **Category:** technical  |  **Verification:** CONFIRMED
- **Current implementation:** DuplicateSavedFilter.cs:113 assigns `var now = DateTime.Now;` and NotifyBusiness/ReportBusiness/ReportCatalog/GetReportCatalogQuery/GetReportCatalog.cs:199 assigns `LastRunDate = kv.Value ?? DateTime.Now;` — both use server-local time (Kind=Local/Unspecified) rather than DateTime.UtcNow, in a codebase whose DB columns are Postgres timestamptz requiring Kind=Utc at Npgsql parameter bind.
- **Gap identified:** Two more concrete instances of the naive local-time anti-pattern already established elsewhere in the codebase (Ambassador, Volunteer modules), this time in cross-cutting Notify/Report infrastructure rather than a single business module.
- **Why it's a problem:** Depending on the Npgsql provider version/configuration, a Kind=Local DateTime can either throw at bind time or silently be persisted as if it were UTC (shifting the actual instant by the server's UTC offset), corrupting 'last run' / 'duplicated at' timestamps used for scheduling and audit ordering across timezones.
- **Recommended solution:** Replace both instances with `DateTime.UtcNow`, consistent with the project-wide convention documented in feedback_db_utc_only.md.
- **Production impact:** Timestamp drift/exception risk in report scheduling metadata and saved-filter duplication audit trail.
- **Business impact:** Report 'Last Run' times and duplicated-filter timestamps may not reflect true UTC instants for tenants outside the app server's local timezone.
- **Technical impact:** Confirms the DateTime.Now/Today anti-pattern is not confined to the Ambassador/Volunteer modules already found — it recurs in shared cross-cutting infrastructure code too, suggesting no lint rule currently blocks it project-wide.
- **Evidence:** PSS_2.0_Backend/.../NotifyBusiness/SavedFilters/Commands/DuplicateSavedFilter.cs:113; PSS_2.0_Backend/.../ReportBusiness/ReportCatalog/GetReportCatalogQuery/GetReportCatalog.cs:199
- **Reviewer note:** not adversarially verified (Medium/Low)

## Case Management

### #11 · Program Fund Allocation / Case Service Log (disbursements) — Multi-currency funding-pool rollups  — `Critical`

- **Module:** Case Management  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** ProgramFundingSource.CurrencyId (Base.Domain/Models/CaseModels/ProgramFundingSource.cs:32) and ProgramFundingTransaction.CurrencyId (ProgramFundingTransaction.cs:27) let each funding source/transaction carry its own currency, independent of Program.BudgetCurrencyId (Program.cs:30). ProgramFundingTransaction even has ExchangeRate/GrantCurrencyAmount FX-snapshot fields (ProgramFundingTransaction.cs:42-43) explicitly commented as mirroring the Grant module's normalization pattern, but no Case/Program code ever reads them.
- **Gap identified:** Verified in ServiceLogFundingGuard.cs: the per-source branch (lines 36-42) sums `t.Amount` filtered to one FundingSourceId, so it is internally currency-safe only because a single source has one CurrencyId; but the program-level fallback (lines 79-85, used whenever a service log has no FundingSourceId) sums `t.Amount` across ALL of a program's funding sources/transactions with zero currency filter or grouping. The same raw-sum pattern is repeated in GetProgramFundingAllocation.cs (`totalTransferred = srcDtos.Sum(s => s.TransferredAmount ?? 0m)` at line 162, `usedCents`/`totalUsed` at 168-171, top-level DTO at 186-190) and GetServiceLogFundingContext.cs (`totalTransferred` at 63-69, `usedCents`/`totalUsed` at 74-77, per-source `transferred`/`spent` at 125-149) — all confirmed by direct read. I also verified SaveProgramFundingAllocation.cs (grep for CurrencyId at lines 145, 221, 272, 289) performs no same-currency validation when creating/editing funding sources or transactions against the Program's BudgetCurrencyId or against each other. BeneficiaryServiceLog.AmountCents indeed has no CurrencyId of its own (confirmed via the DTOs/handlers, which never reference such a column). Nothing in the codebase rejects or normalizes a mixed-currency program.
- **Why it's a problem:** A Program with a USD grant-funded source and an INR sponsor-funded source will have its program-level 'available pool' computed as USD-number + INR-number treated as one currency, both in the hard-cap TOCTOU guard (ServiceLogFundingGuard's program-level branch) that actually blocks/allows real disbursements, and in the two GraphQL query results the FE renders as a single BudgetCurrencyCode-labeled total. Staff can be shown a materially wrong 'available' figure and either over-disburse real cash or be wrongly blocked.
- **Recommended solution:** Add CurrencyId to BeneficiaryServiceLog; normalize every pool computation (guard + both queries) through an FX-converted amount using the already-present but unused ExchangeRate/GrantCurrencyAmount fields (COALESCE pattern from the Grant module), or alternatively enforce same-currency-as-Program at FundingSource/Transaction save time (SaveProgramFundingAllocation.cs) so the mixed-currency scenario cannot occur. Surface per-currency subtotals in the FE when sources legitimately differ.
- **Production impact:** Real money can be over-disbursed, or valid disbursements wrongly blocked, once a Program has funding sources in more than one currency — a setup the schema explicitly allows and provides no guardrail against.
- **Business impact:** Financial misstatement of program funding balances shown to program managers/auditors; risk of disbursing beyond actually-received cash.
- **Technical impact:** Silent numeric corruption — no exception thrown; the wrong-but-plausible number is trusted by the hard-cap concurrency guard and rendered as the program's single funding total.
- **Evidence:** Base.Application/Business/CaseBusiness/BeneficiaryServiceLogs/ServiceLogFundingGuard.cs:36-42 (per-source, currency-safe by construction) vs 79-85 (program-level fallback, no currency filter — confirmed by direct read); Base.Application/Business/CaseBusiness/Programs/GetFundingAllocationQuery/GetProgramFundingAllocation.cs:162,168-171,186-190; Base.Application/Business/CaseBusiness/BeneficiaryServiceLogs/GetFundingContextQuery/GetServiceLogFundingContext.cs:63-69,74-77,125-149; Base.Domain/Models/CaseModels/ProgramFundingTransaction.cs:27,42-43 (CurrencyId/ExchangeRate/GrantCurrencyAmount unused outside Grant module); Base.Domain/Models/CaseModels/ProgramFundingSource.cs:32; Base.Application/Business/CaseBusiness/Programs/SaveFundingAllocationCommand/SaveProgramFundingAllocation.cs:145,221,272,289 (no cross-currency validation)
- **Reviewer note:** Read all cited handlers directly; the raw-sum-across-sources pattern with no currency grouping/conversion is real in both the write-side guard's program-level fallback and both read-side rollup queries. No save-time currency-consistency validation exists to prevent the scenario. Original evidence lines are accurate (within a few lines).

### #98 · Case / Beneficiary / Case Service Log (disbursements) — Branch-scoped spend enforcement  — `High`

- **Module:** Case Management  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** Case.BranchId and Beneficiary.BranchId exist and are stored/filterable (confirmed via grep across Base.Application/Business/CaseBusiness: BranchId appears in exactly 6 files — GetBeneficiaries.cs, CreateBeneficiary.cs, UpdateBeneficiary.cs, UpdateCase.cs, CreateCase.cs, GetAllCases.cs — all pure CRUD storage/filter/display).
- **Gap identified:** Read CreateBeneficiaryServiceLog.cs (full validator + handler) and ServiceLogFundingGuard.cs (full file): neither references BranchId anywhere. The write path validates funding-source ownership/status and enforces the pool ceiling via a Postgres advisory lock, but performs zero check that the acting staff's branch matches the Case/Beneficiary branch. Also confirmed CustomAuthorizeAttribute.cs (the RBAC mechanism gating this endpoint) is purely menu-code + capability-code based (MenuCode/CapabilityCode/MenuCodes/CapabilityCodes) with no branch dimension, and no global EF query filter or branch-claim check exists in the application layer that would implicitly scope this elsewhere.
- **Why it's a problem:** Any staff member with BeneficiaryServiceLog Create/Modify permission can log a disbursement against ANY program's funding pool for ANY beneficiary regardless of branch — there is no tenant-internal segregation of spend authority by branch at all, confirmed at both the specific handler level and the generic authorization-attribute level.
- **Recommended solution:** Add a branch-scope check in ServiceLogFundingGuard or the Create/Update handlers: require the acting staff's branch (or an explicit implementing-branch list on the Program/FundingSource) to match the Case/Beneficiary branch before allowing a disbursement write; or explicitly document this as a deferred/known gap analogous to the Grant module's implementing-branch tag.
- **Production impact:** Any staff member with BeneficiaryServiceLog create/modify rights can post real disbursements against beneficiaries and programs outside their own branch in production, with no server-side block.
- **Business impact:** Cross-branch financial control bypass — branch managers lose the ability to restrict who can spend against their branch's beneficiaries/programs, undermining segregation-of-duties expected in NGO fund controls.
- **Technical impact:** The RBAC/authorization layer and funding-guard logic carry no branch dimension at all, leaving branch segregation entirely unenforced at the data-write level.
- **Evidence:** Base.Application/Business/CaseBusiness/BeneficiaryServiceLogs/CreateCommand/CreateBeneficiaryServiceLog.cs:1-136 (full file read, no BranchId reference); Base.Application/Business/CaseBusiness/BeneficiaryServiceLogs/ServiceLogFundingGuard.cs:1-109 (full file read, no BranchId reference); Base.Application/Security/CustomAuthorizeAttribute.cs:1-36 (menu/capability only, no branch dimension); grep -rln BranchId Base.Application/Business/CaseBusiness -> exactly the 6 CRUD files cited
- **Reviewer note:** Read both the specific service-log handler/guard files in full and the CustomAuthorize attribute that gates the endpoint's RBAC — confirmed no branch-scoping exists at any layer for this write path. Grep result matches the original finding exactly (same 6 files, no more).

### #99 · Program Management / Beneficiary enrollment — Program.MaximumCapacity enforcement  — `High`

- **Module:** Case Management  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** Program.cs:22-23 documents MaximumCapacity as a hard cap distinct from TargetBeneficiaries (goal reach). Confirmed via grep it is referenced in exactly 3 places, all display-only: GetAllPrograms.cs:163-164 and GetProgramById.cs:105-106 (CapacityPercent = EnrolledCount/MaximumCapacity*100), and ProgramFundingMath.cs:45 (`var capacity = program.MaximumCapacity ?? program.TargetBeneficiaries ?? 0;`, used only for funding-need math, not enrollment gating).
- **Gap identified:** Read EnrollBeneficiaryInProgram.cs in full: the validator checks only required fields, FK validity (Beneficiary/Program/Staff), and a MustAsync duplicate-active-enrollment guard (lines 30-38). The handler (lines 46-87) inserts a new BeneficiaryProgramEnrollment unconditionally after resolving the status MasterData — it never queries current enrollment count nor compares against Program.MaximumCapacity anywhere in validator or handler.
- **Why it's a problem:** A program configured with a hard capacity limit (shelter beds, scholarship slots) can be over-enrolled without limit; the 'hard cap' promised in the code comment is enforced nowhere in the write path, only shown as a cosmetic percentage on read screens.
- **Recommended solution:** In EnrollBeneficiaryInProgramValidator, add a MustAsync that counts active (IsDeleted==false, and ideally IsActive/non-terminal-status) BeneficiaryProgramEnrollment rows for the target ProgramId and rejects (or requires an explicit override permission) when Program.MaximumCapacity is set and would be exceeded.
- **Production impact:** Programs with hard capacity limits (e.g. shelter beds, scholarship slots) can be over-enrolled in production with no system block, only a cosmetic percentage on read screens.
- **Business impact:** Programs with hard physical/budgetary capacity constraints (shelter beds, scholarship slots) can silently overcommit, creating downstream operational and funding shortfalls.
- **Technical impact:** The write path (validator and handler) never queries current enrollment count against Program.MaximumCapacity, so the documented hard cap has no enforcement anywhere in the code.
- **Evidence:** Base.Domain/Models/CaseModels/Program.cs:22-23; Base.Application/Business/CaseBusiness/Beneficiaries/UpdateCommand/EnrollBeneficiaryInProgram.cs:14-87 (full file read — no capacity check present); grep confirms MaximumCapacity referenced only in GetAllPrograms.cs:163-164, GetProgramById.cs:105-106, ProgramFundingMath.cs:45
- **Reviewer note:** Read the full EnrollBeneficiaryInProgram.cs file; confirmed no capacity check exists anywhere in the validator or handler. Grep confirms MaximumCapacity has exactly the 3 display-only usages the original finding cites — nothing more.

### #206 · Beneficiary Registration — Duplicate beneficiary detection  — `Medium`

- **Module:** Case Management  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** CreateBeneficiaryValidator (CreateBeneficiary.cs) validates NationalIdNumber only for string length (line 42, max 50 chars) and does not check uniqueness; no MustAsync/uniqueness rule exists for NationalIdNumber, Phone, or (FirstName+LastName+DateOfBirth) combinations anywhere in the validator (lines 14-104).
- **Gap identified:** The same person (same national ID) can be registered as a beneficiary multiple times with no duplicate-detection warning or block.
- **Why it's a problem:** Duplicate beneficiary records fragment a person's case/service history across multiple BeneficiaryId rows, enable double-dipping on sponsorship/aid programs, and corrupt program capacity/impact reporting (KPI widgets counting beneficiaries would double-count the same person).
- **Recommended solution:** Add a server-side duplicate check (exact match on NationalIdNumber when present, and/or fuzzy match on Name+DOB+Phone) that at minimum warns the caller and requires an explicit override/merge decision before creating a new Beneficiary row.
- **Production impact:** Duplicate beneficiary registrations can occur in production undetected, inflating caseloads and enabling repeat aid claims by the same person.
- **Business impact:** Risk of fraud (multiple aid claims by the same individual) and skewed impact/reporting metrics.
- **Technical impact:** No uniqueness validation exists for NationalIdNumber, Phone, or name/DOB combinations, so the data model permits multiple BeneficiaryId rows for the same real individual.
- **Evidence:** Base.Application/Business/CaseBusiness/Beneficiaries/CreateCommand/CreateBeneficiary.cs:14-104 (no uniqueness/duplicate check on NationalIdNumber or Name+DOB combination)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #207 · Case creation / Program linkage — Program lifecycle gate on Case creation  — `Medium`

- **Module:** Case Management  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** CreateCase.cs FK-validates dto.ProgramId (line 42) but ProgramLifecycle.cs enforces a strict DRAFT->PENDINGAPPROVAL->ACTIVE state machine elsewhere for the Program entity itself.
- **Gap identified:** CreateCase.cs never checks that the linked Program.StatusId is ACTIVE - a case (and therefore later disbursements against that program's funding pool) can be opened against a Program still in DRAFT, PENDINGAPPROVAL, PAUSED, or even COMPLETED status.
- **Why it's a problem:** A program that has not been approved (or has since been paused/completed) should not be accepting new cases/beneficiary engagements tied to it; this silently bypasses the approval workflow's intent of gating program activity.
- **Recommended solution:** Add a check in CreateCaseHandler/Validator: when ProgramId is supplied, require Program.Status code to be ACTIVE (or PAUSED-with-explicit-override) before allowing case creation.
- **Production impact:** Cases can be opened and spend committed against programs that are still unapproved, paused, or already completed, bypassing the intended approval gate in live operation.
- **Business impact:** Programs can accrue case-load and downstream spend commitments before/after their approved operating window, undermining the approval lifecycle's control purpose.
- **Technical impact:** CreateCase only FK-validates ProgramId without checking Program.StatusId, so the case-creation write path is decoupled from the Program lifecycle state machine enforced elsewhere.
- **Evidence:** Base.Application/Business/CaseBusiness/Cases/CreateCommand/CreateCase.cs:42,74-94 (beneficiary status checked, Program status never checked); Base.Application/Business/CaseBusiness/Programs/LifecycleCommand/ProgramLifecycle.cs (strict state machine defined but not consulted by CreateCase)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #208 · Case List (all cases query) — Row-level branch/staff scoping on case listing  — `Medium`

- **Module:** Case Management  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** GetAllCasesListQuery scopes only by CompanyId (multi-tenant filter, line 43) plus OPTIONAL filter parameters: statusId, priorityId, programId, assignedStaffId, branchId, and myCasesOnly (lines 57-105) - all client-supplied and off by default.
- **Gap identified:** There is no server-enforced default restriction limiting a caseworker to their own branch or caseload; myCasesOnly/branchId are opt-in query parameters the FE may or may not send. Any user holding Case Read permission for the tenant can retrieve every case (and embedded Beneficiary PII via Include(c => c.Beneficiary), lines 44) across every branch simply by omitting those filters.
- **Why it's a problem:** In a multi-branch NGO, case records contain sensitive beneficiary PII (vulnerability level, health/education fields via the Beneficiary include) that should typically be restricted to the branch/program a staff member is authorized for; relying entirely on optional client-side filters for this is not real access control.
- **Recommended solution:** Enforce branch/caseload scoping server-side based on the acting staff's assigned branch(es) and role (e.g., branch managers see their branch, caseworkers see myCasesOnly by default, org-level roles see all), rather than trusting FE-supplied filter flags.
- **Production impact:** Any authenticated user with basic Case Read permission can pull every case and its embedded beneficiary PII across all branches in production simply by omitting optional filters.
- **Business impact:** Beneficiary PII (health, vulnerability, income indicators) is exposed tenant-wide to any role with basic Case Read permission, regardless of branch assignment - a data-privacy exposure in a sector where beneficiary confidentiality is often contractually/legally required.
- **Technical impact:** Branch/caseload scoping exists only as client-supplied, off-by-default query parameters, with no server-enforced default restriction or query filter.
- **Evidence:** Base.Application/Business/CaseBusiness/Cases/GetAllQuery/GetAllCases.cs:41-53 (CompanyId-only mandatory scope), 87-105 (branchId/myCasesOnly are optional, not defaulted)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #209 · Case Service Log — Disbursement against a closed case  — `Medium`

- **Module:** Case Management  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** CreateBeneficiaryServiceLog.cs requires CaseId (validator line 15, FK-validated line 24) and enforces per-source APPROVED-status and funding-pool checks (lines 70-84, 118-120), all inside a concurrency-safe advisory-locked transaction.
- **Gap identified:** Neither CreateBeneficiaryServiceLog.cs nor UpdateBeneficiaryServiceLog.cs loads the referenced Case or checks its StatusId/IsActive - a service log (real disbursement) can be created or edited against a case that is already CLOSED.
- **Why it's a problem:** A case is closed with a ClosureSummary/CaseOutcome signaling the engagement has ended; allowing new money to be logged against it afterward contradicts the case lifecycle and can hide post-closure financial activity from the closure audit trail (CaseNote STATUSCHANGE audit only fires on explicit status-change commands, not on service-log writes).
- **Recommended solution:** In both Create/UpdateBeneficiaryServiceLog handlers, load the Case and reject (or require an explicit Reopen first) when Case.Status is CLOSED, mirroring the state-machine discipline already applied in UpdateCaseStatus.cs/CloseCase.cs.
- **Production impact:** New or edited disbursements can be posted against already-closed cases in production, with no runtime block tied to case status.
- **Business impact:** Financial activity can occur outside the bounds of the case lifecycle, weakening audit integrity for closed cases.
- **Technical impact:** CreateBeneficiaryServiceLog and UpdateBeneficiaryServiceLog never load or check the parent Case's StatusId/IsActive, leaving the service-log write path disconnected from the case lifecycle's audit trail.
- **Evidence:** Base.Application/Business/CaseBusiness/BeneficiaryServiceLogs/CreateCommand/CreateBeneficiaryServiceLog.cs:1-136 (no Case status load/check anywhere); Base.Application/Business/CaseBusiness/BeneficiaryServiceLogs/UpdateCommand/UpdateBeneficiaryServiceLog.cs:1-134 (same)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #210 · Case Service Log (disbursements) — Maker-checker / second approval on disbursement writes  — `Medium`

- **Module:** Case Management  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** CreateBeneficiaryServiceLog/UpdateBeneficiaryServiceLog are gated only by `[CustomAuthorize(DecoratorCaseModules.BeneficiaryServiceLog, Permissions.Create/Modify)]` - a single permission check - with strong TOCTOU/pool-ceiling and payment-detail guards, but no second-approver workflow.
- **Gap identified:** Unlike Program's own approval lifecycle (Submit -> Approve/Reject with SubmittedByStaffId/ApprovedByStaffId audit trail) and unlike Grant's funder-communication approvals, an actual money-movement action - creating or editing a beneficiary disbursement, including changing amount/destination bank details/payment reference after the fact via Update - requires only one person's Modify permission with no maker-checker or supervisor sign-off.
- **Why it's a problem:** Disbursement is real cash leaving/being logged as leaving the organization to individual beneficiaries; allowing a single actor to both create and later edit destination bank/UPI details and amounts (UpdateBeneficiaryServiceLog.cs lines 43-56) without a second reviewer is a fraud-control gap for a nonprofit's largest attack surface (misdirected payments).
- **Recommended solution:** Introduce an approval/verification step for BeneficiaryServiceLog above a configurable threshold amount, or at minimum make post-creation edits to payment-destination fields (Bank/UPI/reference) require a distinct approver role and produce an audit trail, similar to CaseNote STATUSCHANGE auditing used elsewhere in this module.
- **Production impact:** A single staff member can create and later modify disbursement amounts and destination bank/UPI details in production with no second reviewer catching errors or fraud before funds move.
- **Business impact:** Elevated fraud/error risk on the module responsible for actual beneficiary payments, with no compensating control beyond basic RBAC.
- **Technical impact:** The write path relies solely on a single `[CustomAuthorize]` permission check with no maker-checker workflow or approval state machine backing it.
- **Evidence:** Base.Application/Business/CaseBusiness/BeneficiaryServiceLogs/CreateCommand/CreateBeneficiaryServiceLog.cs:3 ([CustomAuthorize] single-permission gate only); Base.Application/Business/CaseBusiness/BeneficiaryServiceLogs/UpdateCommand/UpdateBeneficiaryServiceLog.cs:3,43-56 (bank/UPI/reference fields freely editable post-creation with no additional approval); contrast with Base.Application/Business/CaseBusiness/Programs/LifecycleCommand/ProgramLifecycle.cs (Submit/Approve/Reject pattern exists for Program but not replicated for money-movement rows)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #211 · Case Service Log / Beneficiary money fields — Currency field missing on BeneficiaryServiceLog  — `Medium`

- **Module:** Case Management  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** BeneficiaryServiceLog stores AmountCents (long?) with no CurrencyId column at all, while the Program it's attributed to (via ProgramId/FundingSourceId) can be denominated in any currency via Program.BudgetCurrencyId or ProgramFundingSource.CurrencyId.
- **Gap identified:** A disbursement row carries no explicit record of what currency its AmountCents actually represents; the currency is only implicitly assumed to match whatever the program/source happens to be configured with at read time, with no snapshot at write time (contrast with ProgramFundingTransaction, which does snapshot ExchangeRate/GrantCurrencyAmount).
- **Why it's a problem:** If a Program's BudgetCurrencyId or a FundingSource's CurrencyId is later changed, or if per-currency reporting/reconciliation with donors is required, historical BeneficiaryServiceLog rows have no way to know what currency they were actually recorded in - a fundamental accounting-record gap for money leaving the organization.
- **Recommended solution:** Add a CurrencyId (snapshot, not FK-live) column to BeneficiaryServiceLog, populated at write time from the attributed FundingSource/Program, mirroring the snapshot-rule already established for Grant/donation money rows.
- **Production impact:** Once a program's or funding source's currency configuration changes, historical disbursement amounts in production become ambiguous as to what currency they were actually recorded in.
- **Business impact:** Disbursement records cannot be reliably reconciled or reported by currency after the fact; audit trail for actual beneficiary payments is incomplete.
- **Technical impact:** BeneficiaryServiceLog persists AmountCents with no CurrencyId column, so no currency snapshot exists at write time, unlike ProgramFundingTransaction which does snapshot exchange rate and currency amount.
- **Evidence:** Base.Domain/Models/CaseModels/BeneficiaryServiceLog.cs (AmountCents long?, no CurrencyId field); Base.Domain/Models/CaseModels/ProgramFundingTransaction.cs (contrast: has CurrencyId + ExchangeRate + GrantCurrencyAmount snapshot fields)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #212 · Program Fund Allocation (frontend) — Currency display for mixed-currency funding sources  — `Medium`

- **Module:** Case Management  |  **Category:** uiux  |  **Verification:** CONFIRMED
- **Current implementation:** program-fund-allocation-page.tsx surfaces per-source currency (f.currencyId/f.currencyCode at lines 43, 56, 179-180, 203-204) in the sources grid, but the summary tiles (computedAnnualNeed, totalExpected, totalTransferred, totalUsed, totalAvailable) all call formatCurrency with the single program-level budgetCurrencyCode (lines 305, 392-409).
- **Gap identified:** When funding sources have differing currencies, the page presents one blended, mislabeled currency total with no visual warning that a currency mismatch exists across sources.
- **Why it's a problem:** End users (program managers, finance reviewers) have no way to notice from the UI that the displayed total is not a valid single-currency figure - compounding Finding #1's backend rollup bug into a user-facing trust issue.
- **Recommended solution:** When sources span more than one currency, either show per-currency subtotals or an explicit warning banner instead of a single blended total.
- **Production impact:** Program managers viewing the fund allocation page in production could act on a blended total that mixes currencies without any warning banner or per-currency breakdown.
- **Business impact:** Program managers and finance staff make funding decisions based on a number that may be currency-invalid, with no indication in the UI to prompt a second look.
- **Technical impact:** The summary tiles format multi-currency sums using a single program-level currency code, hiding the currency mismatch that the sources grid itself correctly displays per row.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/page-components/crm/casemanagement/program/program-fund-allocation-page.tsx:43,56,179-180,203-204 (per-source currency present), 305,392-409 (single budgetCurrencyCode used for all summary totals)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #309 · Beneficiary Enrollment — Cross-check between Case.BranchId and Beneficiary.BranchId  — `Low`

- **Module:** Case Management  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** Beneficiary.BranchId is a non-nullable int (every beneficiary belongs to exactly one branch); Case.BranchId is a nullable int independently FK-validated in CreateCase.cs (line 47) with no relationship enforced to the beneficiary's own branch.
- **Gap identified:** CreateCaseHandler never reads Beneficiary.BranchId nor cross-validates it against the submitted Case.BranchId (or defaults Case.BranchId from the Beneficiary when omitted) - a case can be created with BranchId left null, or set to a branch different from the beneficiary's actual branch, with no rejection.
- **Why it's a problem:** This allows silent data drift between a beneficiary's home branch and the branch under which their case (and its downstream funding/spend reporting) is recorded, corrupting branch-level reporting and compounding the missing branch-scoped-spend gap above.
- **Recommended solution:** Default Case.BranchId from Beneficiary.BranchId at creation, and reject (or warn) if a caller supplies a conflicting BranchId.
- **Production impact:** Cases can go live in production with a null BranchId or a branch that disagrees with the beneficiary's actual branch, silently skewing branch-level reporting from the moment of creation.
- **Business impact:** Branch-level case/spend reporting can be inconsistent or misleading due to unenforced branch alignment between a beneficiary and their case record.
- **Technical impact:** CreateCaseHandler never reads Beneficiary.BranchId or cross-validates it against the submitted Case.BranchId, so the two independently-stored branch values can permanently diverge for the same record.
- **Evidence:** Base.Domain/Models/CaseModels/Case.cs (BranchId nullable int); Base.Domain/Models/CaseModels/Beneficiary.cs (BranchId non-nullable int); Base.Application/Business/CaseBusiness/Cases/CreateCommand/CreateCase.cs:47,63-94 (BranchId only FK-validated, never cross-checked against Beneficiary.BranchId)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #310 · Case Reassignment — New assignee branch/role eligibility check  — `Low`

- **Module:** Case Management  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** ReassignCase.cs validates only that NewStaffId is a valid, existing Staff record (validator line 17) and unconditionally sets caseEntity.AssignedStaffId = req.NewStaffId (line 50).
- **Gap identified:** There is no check that the new staff member is active, belongs to the case's branch, or holds the case-worker role/permission needed to manage cases - any existing Staff row (e.g., a finance-only or inactive staff member) can be assigned a live case.
- **Why it's a problem:** A case could be reassigned to a staff member who has no caseload responsibility or Case module access, leaving the case effectively unmanaged/unmonitored (e.g., the FE 'My Cases' view for that person would surface it, but they may lack the permission to act on it, or the branch mismatch means their supervisor has no visibility).
- **Recommended solution:** Add a check in ReassignCaseValidator that the target Staff is active, holds Case Modify permission, and (once branch-scoping above is implemented) belongs to the case's branch.
- **Production impact:** A live case can be reassigned in production to a staff member with no caseload responsibility, wrong branch, or no Case module access, leaving it effectively unmonitored.
- **Business impact:** Cases can be silently misassigned to staff who cannot or should not act on them, risking dropped follow-ups on vulnerable beneficiaries.
- **Technical impact:** ReassignCase.cs validates only that NewStaffId references an existing Staff row and then unconditionally overwrites AssignedStaffId with no role, branch, or active-status check.
- **Evidence:** Base.Application/Business/CaseBusiness/Cases/ReassignCommand/ReassignCase.cs:8-19 (validator: FK existence only), 42-50 (handler: unconditional assignment, no active/role/branch check)
- **Reviewer note:** not adversarially verified (Medium/Low)

## Prayer · Certificate · General Masters

### #55 · Certificate Management — Process/Print tab — Print/Preview certificate — cross-tenant record access  — `Critical`

- **Module:** Prayer · Certificate · General Masters  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** PrintContactCertificate.cs (lines 27-33) assigns tenantId at line 27 but never uses it; the ContactCertificates query at lines 29-33 is `.IgnoreQueryFilters()...FirstOrDefaultAsync(c => c.ContactCertificateId == command.ContactCertificateId && c.IsDeleted != true, ...)` with no CompanyId predicate. Contact (lines 37-41) and CertificateTemplate (lines 43-49) lookups are likewise IgnoreQueryFilters() and scoped only by the untrusted cert.ContactId/cert.CompanyId. PreviewContactCertificate.cs (lines 27-47) is byte-for-byte the same pattern, with no ITenantContext injected at all. Contrast: GetApprovedContactCertificate.cs line 40 correctly adds `c.CompanyId == tenantId` after IgnoreQueryFilters, and ApproveContactCertificate.cs line 20-21 uses the plain filtered DbSet (no IgnoreQueryFilters).
- **Gap identified:** Any authenticated staff user (only Permissions.Read required) in any tenant can pass an arbitrary ContactCertificateId belonging to a different company and receive that company's donor PII (name, image, donation amounts, purpose) rendered into HTML/PDF. This is a genuine IDOR/omission, proven by the correct pattern existing two files away in the same feature area.
- **Why it's a problem:** Direct cross-tenant PII leak in a multi-tenant SaaS, reachable by any low-privilege authenticated user via simple ID enumeration on a sequential integer PK.
- **Recommended solution:** Add `&& c.CompanyId == tenantContext.GetCurrentTenantId()` to the ContactCertificates predicate in both PrintContactCertificate.cs and PreviewContactCertificate.cs (inject ITenantContext into the latter); ensure the CertificateTemplate lookup uses the caller's tenant, not the target row's CompanyId.
- **Production impact:** Live cross-tenant PII disclosure on every Print/Preview call once a ContactCertificateId from another tenant is guessed or observed.
- **Business impact:** Regulatory/compliance exposure and reputational/contractual risk across every tenant on the platform.
- **Technical impact:** IDOR bypassing the global multi-tenant EF query-filter architecture; unused tenantContext variable is a visible smell confirming the omission.
- **Evidence:** Base.Application/Business/ContactBusiness/ContactCertificates/Commands/PrintContactCertificate.cs lines 22-49 (tenantId at 27 unused, query 29-33 has no CompanyId filter); Commands/PreviewContactCertificate.cs lines 22-47 (identical, no tenant context injected at all); contrast Queries/GetApprovedContactCertificate.cs line 40 and Commands/ApproveContactCertificate.cs lines 20-21.

### #163 · Certificate Management — Process/Print tab — Print action produces no reachable output for the user  — `High`

- **Module:** Prayer · Certificate · General Masters  |  **Category:** functional  |  **Verification:** ADJUSTED
- **Current implementation:** Backend PrintContactCertificate.cs writes the PDF to a hardcoded server path `Path.Combine("D:", "PSS2.0_Certificates")` (line 113) and returns it as PdfPath on the result. ContactCertificateMutations.cs (lines 37-59) maps this to `PrintCertificateResultDto.PdfFilePath`, and the FE mutation CertificateMutation.ts (lines 25-30) DOES select `data { contactCertificateId, certificateStatusId, printedAt, pdfFilePath }` — so, contrary to the initial claim, pdfFilePath is selected over GraphQL. However print-tab.tsx's handlePrintRow (lines 105-129) only reads `result?.result?.success`/`.message` to fire a toast — it never reads, opens, downloads, or links to `pdfFilePath` anywhere. `renderedHtml` is genuinely never selected/used either. The path returned would be useless to a browser regardless (server-local disk path, e.g. `D:\PSS2.0_Certificates\...`), so even if the FE read it, it could not be used to obtain the file — only the separate Preview flow (use-certificate-preview.ts, streaming a blob from `/Certificate/preview`) actually delivers a PDF to the browser.
- **Gap identified:** Clicking "Print" flips PrintedById/PrintedAt server-side and shows a success toast, but no PDF is ever opened/downloaded by the browser — the FE silently discards the (unusable, server-local-path) pdfFilePath value it does receive. The button named "Print" is a functional no-op for actually obtaining a document; only "Preview" works.
- **Why it's a problem:** Staff will believe the certificate was produced (success toast, status flips to Printed) but no physical/digital document is ever delivered through this path, and the record is now marked Printed, making a later legitimate reprint look like a duplicate.
- **Recommended solution:** Have printContactCertificate stream PDF bytes or a signed download URL (mirroring PreviewContactCertificate's GeneratePdfBytesAsync) and have handlePrintRow trigger a real download/print dialog on success; do not rely on the FE-unreachable hardcoded D:\ server path. Do not mark PrintedAt until the client confirms it obtained the file.
- **Production impact:** Every 'Print' click in production leaves staff without a deliverable while flipping audit-state fields (PrintedAt/PrintedById), though a working Preview/download alternative exists on the same screen.
- **Business impact:** Staff cannot fulfill donor certificate requests via the primary 'Print' action; must rely on 'Preview' instead, undermining trust in the named workflow and its audit trail.
- **Technical impact:** GraphQL field pdfFilePath IS wired through (selected in the FE query) but is a dead value on the client — never consumed — and even if consumed, points to a server-local path that breaks under horizontal scaling/containerized deployment.
- **Evidence:** PrintContactCertificate.cs line 113 (hardcoded D:\PSS2.0_Certificates path), lines 121-123 (PrintedById/PrintedAt written unconditionally); ContactCertificateMutations.cs lines 37-59 (maps PdfPath -> PdfFilePath); CertificateMutation.ts lines 11-32 (pdfFilePath IS present in the selection set, correcting the initial claim that it was omitted); print-tab.tsx lines 105-129 (handlePrintRow reads only success/message, never pdfFilePath); contrast use-certificate-preview.ts lines 16-45 (Preview streams a real blob and triggers a browser download).
- **Reviewer note:** ADJUSTED: the specific claim that the FE mutation 'never selects pdfPath' is factually wrong — it selects it as `pdfFilePath` and the field is wired end-to-end at the GraphQL layer. The underlying functional gap is nonetheless real: the FE never uses that value, so Print is still a no-op from the user's perspective. Downgraded from Critical to High because a working alternative (Preview) exists on the same screen and no data is lost, only a confusing audit-state flip and a missing deliverable via the primary action.

### #164 · Certificate Management — Process/Print tab — ContactCertificate Create — mass-assignment / tenant-injection risk  — `High`

- **Module:** Prayer · Certificate · General Masters  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** CreateContactCertificate.cs (lines 25-34) does `command.contactCertificate.Adapt<ContactCertificate>()` and saves directly with zero field allowlisting. ContactCertificateRequestDto (ContactCertificateSchemas.cs lines 21-41) is the direct Create-mutation input type and exposes client-writable CompanyId (line 24), ApprovedById/ApprovedAt (36-37), and PrintedById/PrintedAt (38-39). TenantSaveChangesInterceptor.cs (lines 69-79) only auto-stamps CompanyId when `isUnset` (null or 0) on Added entities; a non-zero client-supplied CompanyId for Added rows is never overwritten or rejected (only Modified-entity CompanyId edits are blocked, line 83-87).
- **Gap identified:** A client calling the CreateContactCertificate GraphQL mutation directly can submit an explicit non-zero CompanyId for a different tenant, or pre-set ApprovedById/ApprovedAt/PrintedById/PrintedAt to fabricate an already-approved/printed certificate — none of these are stripped or re-validated server-side.
- **Why it's a problem:** Combined with the Print/Preview IDOR, this allows forging certificate records into another tenant's data or falsifying the approval/print audit trail for a compliance-sensitive donation-receipt document.
- **Recommended solution:** Split the Create-input DTO from the response DTO; strip CompanyId/ApprovedById/ApprovedAt/PrintedById/PrintedAt from the Create input entirely and set CompanyId explicitly from ITenantContext in the handler, matching the documented server-stamp pattern used elsewhere (e.g. PrayerRequestReply's CompanyId/DraftedByContactId).
- **Production impact:** Exploitable at Create time in production via direct GraphQL calls; a single crafted request can inject data into another company's certificate ledger or forge audit timestamps.
- **Business impact:** Falsified financial/compliance documents undermine audit integrity and donor trust.
- **Technical impact:** Mass-assignment vulnerability compounded by an interceptor that only guards unset (null/0) values, not attacker-supplied non-zero ones, on newly Added entities.
- **Evidence:** Base.Application/Business/ContactBusiness/ContactCertificates/Commands/CreateContactCertificate.cs lines 25-34 (Adapt<ContactCertificate>() with no stripping); Base.Application/Schemas/ContactSchemas/ContactCertificateSchemas.cs lines 21-41 (CompanyId, ApprovedById/At, PrintedById/At all on the Create-input DTO); Base.Infrastructure/Data/Interceptors/TenantSaveChangesInterceptor.cs lines 69-87 (isUnset-only auto-stamp on Added; Modified-only CompanyId-change block).

### #165 · General Masters — Bank/Blood Group/Gender/Language/Occupation/Payment Mode/Relation/Salutation/City/District/Locality/Pincode/State grids — Delete command missing referential-integrity guard  — `High`

- **Module:** Prayer · Certificate · General Masters  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** DeleteCountry.cs (lines 18-23) is the only master-data delete command that calls the shared helper ValidateNotReferencedInAnyCollection<Country,int> before soft-deleting. A full listing of Delete*.cs under Base.Application/Business/SharedBusiness (21 files total: Banks, BloodGroups, Cities, Countries, CountryPaymentMethods, Currencies, CurrencyConversions, Districts, DocumentTypes, Genders, Languages, Localities, Nationalities, Occupations, PaymentGateways, PaymentModeTransactions, PaymentModes, Pincodes, Relations, Salutations, States, StorageAccounts) plus a targeted grep for the helper name confirms it is present ONLY in DeleteCountry.cs. DeleteBank.cs and DeleteGender.cs (both read in full) perform a bare `entity.IsDeleted = true; SaveChangesAsync()` with zero reference check.
- **Gap identified:** Deleting any of these 20 other master-data types that is still referenced by Contact/Donation/other records silently soft-deletes the master row while leaving orphaned FK references pointing at a now-inactive master value, with no warning to the operator.
- **Why it's a problem:** Downstream screens/reports joining to these master tables will show blank/stale labels for any record referencing a deleted master value, with no indication to the operator who performed the delete — an easy-to-trigger, hard-to-detect data-integrity gap present in the overwhelming majority of master grids in this module.
- **Recommended solution:** Apply the same ValidateNotReferencedInAnyCollection<TEntity,TKey> helper already proven in DeleteCountry.cs to the other 20 Delete commands, referencing their actual dependent collections (Contact.GenderId, Contact.BloodGroupId, Donation.PaymentModeId, etc.).
- **Production impact:** Any accidental delete of an in-use master-data row in production breaks referential display/reporting for every record that referenced it, with no guard rail.
- **Business impact:** Silent data corruption in core donor/contact records is costly to detect and repair after the fact in a live NGO donor database.
- **Technical impact:** Inconsistent application of an existing, proven shared validator — a mechanical fix, currently applied to only 1 of 21 master Delete commands in this business area (broader than the initially claimed 1-of-15).
- **Evidence:** Base.Application/Business/SharedBusiness/Countries/Commands/DeleteCountry.cs lines 18-23 (guarded); Base.Application/Business/SharedBusiness/Banks/Commands/DeleteBank.cs (full file, plain soft-delete, no guard); Base.Application/Business/SharedBusiness/Genders/Commands/DeleteGender.cs (full file, plain soft-delete, no guard); directory listing of Base.Application/Business/SharedBusiness/**/Delete*.cs shows 21 files, and grep of ValidateNotReferencedInAnyCollection across them returns exactly one match (DeleteCountry.cs).
- **Reviewer note:** CONFIRMED and count corrected: 20 of 21 master Delete commands (not 14 of 15) lack the guard.

### #269 · Certificate Management — Process tab — CertificateTemplate IsActive/Toggle has no effect on which template Print/Preview use  — `Medium`

- **Module:** Prayer · Certificate · General Masters  |  **Category:** functional  |  **Verification:** CONFIRMED
- **Current implementation:** ToggleCertificateTemplate.cs simply flips entity.IsActive with no downstream effect; PrintContactCertificate.cs and PreviewContactCertificate.cs both select the template via `.OrderByDescending(t => t.CreatedDate).FirstOrDefaultAsync()` scoped only by CompanyId/TemplateTypeId (per prior findings, lines ~43-49 / ~41-47) with no `IsActive` filter applied.
- **Gap identified:** An administrator who deactivates a certificate template (e.g. because it contains an error or outdated branding) via the Toggle action has no actual effect on live Print/Preview output — the most-recently-created template row for that type is always used regardless of its IsActive flag.
- **Why it's a problem:** The IsActive toggle gives operators false confidence that they've disabled a bad template; certificates keep being generated from it in production until a newer row is created, which is a functional/business-logic disconnect between the admin control surface and the actual rendering path.
- **Recommended solution:** Add `&& t.IsActive == true` to the template selection query in both PrintContactCertificate.cs and PreviewContactCertificate.cs, and decide/clarify precedence when multiple active templates exist for the same TemplateTypeId (e.g. prefer IsDefault, then most recent).
- **Production impact:** Reachable the moment more than one template exists per TemplateTypeId and an operator tries to retire the older/wrong one via Toggle.
- **Business impact:** Wrong/outdated certificate content (branding, legal wording) can keep being issued to donors after staff believe they disabled it.
- **Technical impact:** Admin toggle control is disconnected from the actual template-selection query used at render time.
- **Evidence:** Base.Application/Business/ContactBusiness/CertificateTemplates/Commands/ToggleCertificateTemplate.cs (entity.IsActive = !entity.IsActive with no other effect); Commands/PrintContactCertificate.cs and Commands/PreviewContactCertificate.cs template lookup (.OrderByDescending(t => t.CreatedDate).FirstOrDefaultAsync(), no IsActive predicate).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #270 · Certificate Management — Process/Print tab — No template snapshot stored on ContactCertificate at Generate/Approve time  — `Medium`

- **Module:** Prayer · Certificate · General Masters  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** ContactCertificateConfiguration.cs (EF configuration, full file reviewed) has no HtmlContent/template-snapshot column on ContactCertificate. PrintContactCertificate.cs and PreviewContactCertificate.cs always re-render from the CURRENT live CertificateTemplate.HtmlContent at print/preview time, not from whatever template version was in effect when the certificate was Generated or Approved.
- **Gap identified:** If an administrator edits the CertificateTemplate's HtmlContent (wording, amounts formatting, legal disclaimer) after a certificate has already been Generated/Approved for a donor, re-printing or previewing that same certificate later renders the NEW template content, not what was originally approved.
- **Why it's a problem:** For a compliance-sensitive document like a donation tax certificate, the content that was approved should be immutable and reproducible on reprint; re-rendering live means the same ContactCertificateId can produce materially different documents on different dates, undermining audit trails and potentially producing legally inconsistent duplicate certificates for the same donation.
- **Recommended solution:** Persist the fully-rendered HTML (or at minimum the CertificateTemplateId + version) on ContactCertificate at Generate or Approve time, and have Print/Preview render from that stored snapshot rather than the live template.
- **Production impact:** Reachable whenever a template is edited between a certificate's approval and any later reprint.
- **Business impact:** Inconsistent/legally-risky donation certificates for tax-receipt purposes if templates are corrected/updated over time.
- **Technical impact:** Missing snapshot/versioning column; architecture treats certificates as always-live-rendered rather than point-in-time documents.
- **Evidence:** Base.Infrastructure/Data/Configurations/ContactConfigurations/ContactCertificateConfiguration.cs (no HtmlContent/snapshot column); Base.Application/Business/ContactBusiness/ContactCertificates/Commands/PrintContactCertificate.cs and Commands/PreviewContactCertificate.cs (both re-render from live CertificateTemplate.HtmlContent each call).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #271 · Prayer Request Entry / Reply Queue / Review Reply — Prayer Request moderation status transitions have no prior-state guard  — `Medium`

- **Module:** Prayer · Certificate · General Masters  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** ApprovePrayerRequest.cs sets entity.Status = 'Approved' unconditionally with no check of the entity's current Status; RejectPrayerRequest.cs (lines 51-55, reviewed) likewise sets Status='Rejected' with no guard on the prior state; BulkModeratePrayerRequests.cs (lines 69-104) applies the same unconditional status overwrite for Approve/Reject/MarkPraying/MarkAnswered/Archive in a switch statement with no case validating the entity's current Status before transitioning.
- **Gap identified:** There is nothing stopping an Archived or Answered prayer request from being 're-approved', or an Approved request from being 'archived' and then 're-approved' again, etc. — any status can transition to any other status at any time via these commands, individually or in bulk.
- **Why it's a problem:** A moderation workflow with no state-machine enforcement allows accidental or malicious out-of-order transitions (e.g. re-approving something a supervisor deliberately rejected, or reviving an archived request), and — combined with PrayerWallEligible being recomputed on approve — could cause a previously rejected/archived prayer to reappear on the public Prayer Wall.
- **Recommended solution:** Add an explicit allowed-prior-status check to each transition handler (e.g. Approve only valid from New/Rejected; Reject only valid from New; Archive only valid from Approved/Praying/Answered) and reject with a clear error otherwise, matching the guard pattern already used correctly in PrayerRequestReplies (SubmitPrayerRequestReplyForReview.cs requires Status==Draft; ApprovePrayerRequestReply.cs re-checks Status==SubmittedForReview).
- **Production impact:** Reachable in production any time staff (or a race between two staff members / bulk + single actions) act on a request not in the expected state.
- **Business impact:** Public-facing Prayer Wall could show content a supervisor already rejected, or a moderation trail loses meaning when transitions are freely reversible.
- **Technical impact:** No state-machine validation in the single most state-sensitive part of the module, despite the same codebase demonstrating the correct guard pattern one level down (PrayerRequestReply).
- **Evidence:** Base.Application/Business/ContactBusiness/PrayerRequests/ModerationCommands/ApprovePrayerRequest.cs (Handle method, unconditional entity.Status='Approved'); RejectPrayerRequest.cs lines 51-55; BulkModeratePrayerRequests.cs lines 69-104 (switch with no prior-status case checks); contrast Base.Application/Business/ContactBusiness/PrayerRequestReplies/SubmitCommand/SubmitPrayerRequestReplyForReview.cs lines 66-68 and ApproveCommand/ApprovePrayerRequestReply.cs lines 98-101 (both properly guard on prior Status).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #272 · Prayer Request Page (public) / Prayer Request Entry — Public prayer submission resolves tenant via 'first active company', not by page slug  — `Medium`

- **Module:** Prayer · Certificate · General Masters  |  **Category:** multitenancy  |  **Verification:** CONFIRMED
- **Current implementation:** SubmitPrayerRequest.cs lines 84-89 resolves CompanyId via `dbContext.Companies.AsNoTracking().Where(c => c.IsDeleted==false && c.IsActive==true).OrderBy(c => c.CompanyId).Select(c => (int?)c.CompanyId).FirstOrDefaultAsync(...)` instead of deriving it from the requested page's slug/route. GetPrayerRequestPageBySlug.cs doc-comment (lines 18-20) explicitly labels this 'ISSUE-1 from OnlineDonationPage... one-tenant-per-deployment MVP... deferred to future sprint' and implements the identical 'first active company' resolution at lines 47-53.
- **Gap identified:** In any deployment hosting more than one active tenant/company, every public prayer-submission and every public prayer-page-by-slug lookup resolves to whichever company happens to sort first by CompanyId, regardless of which tenant's page/slug the visitor actually requested.
- **Why it's a problem:** This is a known, already-tracked defect pattern (see existing bug-report artifacts for Online Donation Page ODP-B5) now confirmed replicated verbatim in the Prayer module; it silently misattributes public submissions to the wrong tenant the moment a second active company exists in the same deployment, with no error or warning.
- **Recommended solution:** Resolve CompanyId from the requested page's own CompanyId (already loaded via the slug lookup) rather than a separate 'first active company' query, consistent with the eventual fix planned/tracked for the Online Donation Page sibling issue; apply the same fix to both modules together since they share the root cause.
- **Production impact:** Only manifests once a given deployment hosts 2+ active tenants sharing this code path — not exploitable in a genuinely single-tenant-per-deployment environment, which is presumably why it shipped as MVP.
- **Business impact:** If/when this product model changes to multi-tenant-per-deployment, all public prayer submissions silently land on the wrong charity's data until fixed.
- **Technical impact:** Same root-cause tenant-resolution shortcut duplicated across two independent modules (Online Donation Page and Prayer Request Page), doc-commented as a known, deferred limitation rather than an oversight.
- **Evidence:** Base.Application/Business/ContactBusiness/PrayerRequests/PublicMutations/SubmitPrayerRequest.cs lines 84-89; Base.Application/Business/ContactBusiness/PrayerRequestPages/PublicQueries/GetPrayerRequestPageBySlug.cs lines 18-20 (doc-comment naming ISSUE-1) and lines 47-53 (implementation); .claude/screen-tracker/bug-reports/onlinedonationpage-ODP-B5-HANDOFF.md (sibling tracked issue).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #273 · Prayer Request Reply Queue / Review Reply — Approved prayer replies are never actually sent to the submitter  — `Medium`

- **Module:** Prayer · Certificate · General Masters  |  **Category:** business  |  **Verification:** ADJUSTED
- **Current implementation:** PrayerRequestReply.cs doc-comment (lines 3-19) explicitly scopes this build to Create->Draft, SubmitForReview, Recall, SoftDelete, and Approve/Reject (owned by screen #138), stating 'Send/Fail -> owned by future Send-Service' is explicitly out of scope; SentAt (line 90) and DeliveryRefId (lines 92-96) are documented SERVICE_PLACEHOLDER fields, null in this build. ApprovePrayerRequestReply.cs (full handler, lines 74-197) validates channel-conditional edits and flips Status='Approved' with zero dispatch/queue/email-send call. REGISTRY.md confirms: screen #137 (Reply Queue) is COMPLETED and explicitly lists 'Service placeholders (deferred): actual reply transport (Email/SMS/WhatsApp)...' as a disclosed, tracked scope item; screen #138 (Review/Approve tab) status is PARTIALLY_COMPLETED — BE done, FE explicitly NOT STARTED ('FE Developer agent stalled... ZERO files written', ISSUE-FE-PENDING marked High) — so the end-to-end Draft->Submit->Approve workflow described in the finding is not yet even shippable/visible to end users.
- **Gap identified:** The reviewed BE code path does terminate at Status='Approved' with SentAt/DeliveryRefId permanently null and no transport integration — this part of the finding is accurate. However this is an explicitly documented, deliberately phased scope decision (visible in the entity doc-comment and the registry's tracked 'Service placeholders (deferred)' + open FE-pending issue), not a silently-shipped illusion of completeness: the Approve UI (#138) that would let staff believe they 'completed' the workflow is not built yet per the registry.
- **Why it's a problem:** Once #138's FE ships and a future Send-Service is not yet wired, staff will be able to complete Draft->Submit->Approve with no observable outbound delivery and no in-UI warning — this remains a real pre-production gap to close before go-live, but it is currently a tracked/disclosed placeholder on a not-yet-complete screen rather than a hidden defect in a 'Completed' feature.
- **Recommended solution:** Before #138 ships to production, either add an explicit 'not yet sent — awaiting Send-Service' UI indicator on Approved replies, or implement the minimum Send-Service (reuse the notify.EmailSendQueues pattern already used in SubmitPrayerRequest.cs) so Approve actually dispatches. Track as a release gate tied to #138 completion and the future Send-Service work item, not as a standalone High-severity production defect today.
- **Production impact:** No current production exposure for #138 (FE not built); becomes a real go-live blocker only once #138's FE and any 'Approved' surfacing ship without the Send-Service.
- **Business impact:** If shipped without disclosure, prayer submitters would never receive replies despite staff completing a full moderation workflow — but this is currently an openly tracked, disclosed gap (registry ISSUE-FE-PENDING + doc-comment scope note), not a silent one.
- **Technical impact:** Missing integration between the moderation workflow and any transport/notification service; SentAt/DeliveryRefId schema exists but is dead until the Send-Service is built.
- **Evidence:** Base.Domain/Models/ContactModels/PrayerRequestReply.cs lines 3-19, 90, 92-96; Base.Application/Business/ContactBusiness/PrayerRequestReplies/ApproveCommand/ApprovePrayerRequestReply.cs lines 74-197 (no send/dispatch call); .claude/screen-tracker/REGISTRY.md rows for #137 (COMPLETED, lists transport as deferred placeholder) and #138 (status PARTIALLY_COMPLETED, FE NOT STARTED, ISSUE-FE-PENDING High).

### #326 · Certificate Management — Process tab — DeleteContactCertificate has no status guard  — `Low`

- **Module:** Prayer · Certificate · General Masters  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** DeleteContactCertificate.cs (full file reviewed) performs a plain soft-delete (`entity.IsDeleted = true`) with no check of the certificate's current CertificateStatusId (e.g. Generated/Approved/Printed).
- **Gap identified:** An already-Approved or already-Printed certificate — a document that may already have been physically handed/mailed to a donor — can be soft-deleted with no warning or restriction, removing it from all future listings/reports while the physical/PDF copy already in the donor's hands remains unaccounted for in the system.
- **Why it's a problem:** Deleting a certificate record that documents a real donation-related event issued to a donor creates a reporting/audit gap: the system will no longer show that this certificate was ever issued, but the donor may still hold the physical or digital copy.
- **Recommended solution:** Block or require an explicit confirmation/reason when deleting a certificate that is already Approved/Printed; consider superseding instead of deleting when a correction is needed.
- **Production impact:** Reachable any time staff delete a certificate row after it has already been approved/printed.
- **Business impact:** Audit/reporting gap for issued donation certificates.
- **Technical impact:** Missing status guard consistent with the general pattern of missing guards seen elsewhere in this module (masters delete, prayer status transitions).
- **Evidence:** Base.Application/Business/ContactBusiness/ContactCertificates/Commands/DeleteContactCertificate.cs (full file, plain soft-delete with no CertificateStatusId check).
- **Reviewer note:** not adversarially verified (Medium/Low)

## Performance & Scalability

### #54 · All MASTER_GRID screens (system-wide) — Grid custom-field (JSONB) sorting  — `Critical`

- **Module:** Performance & Scalability  |  **Category:** performance  |  **Verification:** CONFIRMED
- **Current implementation:** CommonExtension.ApplyGridFeatures<T,TDto> (Base.Application/Extensions/CommonExtension.cs:60,79-95): when gridFeatureRequest.sortColumn starts with 'CustomFields.' (GridQueryBuilderHelper.IsCustomFieldSortColumn, GridQueryBuilderHelper.cs:229-245), the non-custom-sort branch pushes ORDER BY + Skip/Take to SQL (line 100), but the custom-sort branch runs `await filterquery.ToListAsync(cancellationToken)` with no Take()/limit at all (line 83), sorts the full in-memory list via ApplyCustomFieldSortingToList, then does an in-memory Skip/Take.
- **Gap identified:** Any grid screen sorting by a custom/dynamic (JSONB) field loads the ENTIRE filtered result set into application memory before paginating, with zero row ceiling.
- **Why it's a problem:** ApplyGridFeatures is the shared pagination engine used by ~196 query handlers across every business module. Once a tenant's filtered set for any of these grids grows large and a user sorts by a custom field, the API process must materialize and hold the full result set in memory per request -- unbounded, with no cap -- risking GC pressure, latency spikes, or OOM under concurrent load, and this is a systemic shared-code-path issue rather than isolated to one screen.
- **Recommended solution:** Push JSONB custom-field sorting into SQL (Postgres can ORDER BY `column->>'key'` expressions) so pagination stays server-side; if some columns genuinely cannot be expressed in SQL, add a hard cap (e.g. MaxCustomSortRows = 5,000) before the ToListAsync and surface a UI warning when the filtered set exceeds it.
- **Production impact:** Any tenant with a moderately sized dataset will see grid requests degrade into multi-second/timeout responses or memory pressure the moment a user sorts by a custom field -- a systemic, shared-code-path failure.
- **Business impact:** Slow or failing list screens across the entire product for growing tenants; support escalations and perceived platform instability at the accounts with the highest data volume and value.
- **Technical impact:** Unbounded server memory usage per concurrent request; risk of app-pool/process-level OOM or GC-induced latency spikes affecting other tenants on the same instance (noisy-neighbor effect).
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Extensions/CommonExtension.cs:60,79-95 (isCustomFieldSort branch: ToListAsync with no Take, then in-memory Skip/Take); line 100 shows the correct SQL-side ApplyPagination pattern used in the non-custom-sort branch; GridQueryBuilderHelper.cs:229-245 confirms trigger is any sortColumn prefixed 'CustomFields.'.

### #162 · Membership Renewals (Export), Email Analytics (Export Recipient Activity) — CSV export handlers  — `High`

- **Module:** Performance & Scalability  |  **Category:** performance  |  **Verification:** CONFIRMED
- **Current implementation:** ExportMembershipRenewalsHandler.Handle (ExportMembershipRenewals.cs:67): `var rows = await realRowsQuery.ToListAsync(cancellationToken)` with no .Take()/row cap (query is CompanyId-scoped and filterTab-scoped, e.g. Overdue/DueThisMonth, at lines 39,49-65), builds CSV via StringBuilder, returns `data:text/csv;base64,{base64}` inline. ExportEmailAnalyticsRecipientActivityHandler.Handle (ExportEmailAnalyticsRecipientActivity.cs:58-74) does the identical unbounded pattern, scoped to a single EmailSendJobId's recipient queue.
- **Gap identified:** Neither export handler caps exported rows or offloads to a background job; both build the full CSV + base64 payload synchronously in the request thread.
- **Why it's a problem:** A tenant with a large membership renewal backlog or a high-volume single email campaign can produce a large in-memory row set, StringBuilder, and a base64 payload ~33% larger than raw bytes -- all synchronously in one GraphQL request -- risking timeouts and memory spikes. The team has the correct bounded pattern elsewhere in the codebase (ExportAuditTrailCsv.cs) but didn't apply it here.
- **Recommended solution:** Apply the same MaxExportRows + .Take() guard used in ExportAuditTrailCsv.cs (MaxExportRows = 250_000, .Take(MaxExportRows) at line 100) to both handlers, and for exports at real scale move the work off the synchronous request path onto a background job that writes to blob/temp storage and returns a download link.
- **Production impact:** CSV exports on these two screens can time out or spike memory once a tenant's renewal backlog or a single campaign's recipient list grows large; degrades precisely as the corresponding feature is used more heavily.
- **Business impact:** Growing/enterprise tenants (larger membership rosters, bigger email campaigns) are most likely to hit this ceiling.
- **Technical impact:** Synchronous large-payload generation on the request thread; base64 inflates memory ~33% over raw CSV bytes; no row ceiling to bound worst-case cost.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/MemBusiness/MembershipRenewals/Commands/ExportMembershipRenewals.cs:67-96; PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/NotifyBusiness/EmailAnalytics/Queries/ExportEmailAnalyticsRecipientActivity.cs:58-110; contrast pattern verified at PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ReportAuditBusiness/AuditLogs/ReportExport/ExportAuditTrailCsv.cs:52 (MaxExportRows = 250_000) and :100 (.Take(MaxExportRows)).

### #265 · All GraphQL screens (system-wide) — GraphQL server hardening / query cost limiting  — `Medium`

- **Module:** Performance & Scalability  |  **Category:** performance  |  **Verification:** CONFIRMED
- **Current implementation:** GraphQLRegistrationExtensions.AddGraphQLWithAutoRegistration (Base.API/Extensions/GraphQLRegistrationExtensions.cs:14-61): configures AddGraphQLServer(), AddAuthorization(), AddInMemorySubscriptions(), and ModifyOptions(options => options.StrictValidation = false) — no MaxExecutionDepth, no request/operation complexity limiting, no explicit introspection disablement, no per-request timeout configuration.
- **Gap identified:** There is no query-depth limit, no cost/complexity analysis, and no execution timeout configured anywhere in the GraphQL server setup.
- **Why it's a problem:** HotChocolate supports depth/complexity limiting specifically to prevent a single request from fanning out into an unbounded number of nested resolver calls or an extremely deep query tree; without it, any authenticated (or, if introspection is left on, any unauthenticated schema-probing) client can submit a deeply nested or overly broad query that consumes disproportionate CPU/DB connections on the shared multi-tenant API process, degrading service for all tenants on that instance.
- **Recommended solution:** Add `.AddMaxExecutionDepthRule(...)` and/or HotChocolate's complexity analysis (`AddComplexityAnalyzer` / cost directives) sized to the deepest legitimate query used by the frontend, set an explicit request timeout, and explicitly disable introspection outside Development via `.ModifyOptions(o => o.EnableSchemaRequestTimeout = ...)`/`.ModifyRequestOptions` (or IntrospectionAllowedRule) for production.
- **Production impact:** No current evidence of exploitation, but this is a standing DoS/resource-exhaustion vector against a multi-tenant shared API process with no compensating control at the framework layer.
- **Business impact:** A single misbehaving client integration or malicious actor can degrade the platform for all tenants sharing the instance; also elevates blast radius of any future frontend bug that accidentally builds an over-broad query.
- **Technical impact:** Nested/deep GraphQL queries can multiply resolver and DB round-trips (especially combined with the custom-field-sort in-memory-load issue above) with no framework-level ceiling.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/Extensions/GraphQLRegistrationExtensions.cs:14-61 (full AddGraphQLServer setup, no depth/complexity/timeout configuration present).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #266 · All grid/list screens (system-wide) — read-only query handlers — EF change tracking on read-only grid queries  — `Medium`

- **Module:** Performance & Scalability  |  **Category:** performance  |  **Verification:** CONFIRMED
- **Current implementation:** CommonExtension.ApplyGridFeatures<T,TDto> (Base.Application/Extensions/CommonExtension.cs) never calls AsNoTracking() itself; whether the underlying IQueryable is tracked depends entirely on whether the calling handler added .AsNoTracking() before passing baseQuery/filterquery in. A repo-wide check of all 196 files that call ApplyGridFeatures shows 110 of them (over half) contain no AsNoTracking() call anywhere in the file (example: GetProducts.cs:22-32 builds `dbContext.Products...` and passes it straight into ApplyGridFeatures with no AsNoTracking).
- **Gap identified:** More than half of all grid/list query handlers across the system load and materialize entities with full EF Core change-tracking enabled even though these are read-only GraphQL query resolvers whose results are immediately mapped to DTOs and discarded.
- **Why it's a problem:** EF change tracking allocates a snapshot per tracked entity/navigation for concurrency and identity-map bookkeeping that is pure overhead for read-only list endpoints — it increases per-request memory allocation and materialization time, and this waste is multiplied across every one of the (likely thousands of) grid page-loads per day system-wide.
- **Recommended solution:** Default AsNoTracking() inside ApplyGridFeatures itself (or require/enforce it via a Roslyn analyzer/code-review rule at the call site) so every list/grid query is untracked by default; leave tracked queries only for the small set of handlers that genuinely need entity mutation in the same context.
- **Production impact:** Cumulative, distributed CPU/memory overhead across virtually every grid load in the system; individually invisible, but compounds materially under concurrent multi-tenant load.
- **Business impact:** Higher infrastructure cost and lower headroom for concurrent users per instance than necessary, since read-only traffic (the majority of all traffic) pays for write-tracking machinery it never uses.
- **Technical impact:** Unnecessary per-entity change-tracker snapshots and identity-map entries for read-only DTO-projected results across >100 query handlers.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Extensions/CommonExtension.cs:1-165 (no AsNoTracking call in ApplyGridFeatures); PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ApplicationBusiness/Products/Queries/GetProducts.cs:22-32 (representative handler with no AsNoTracking before ApplyGridFeatures); confirmed via repo-wide search: 110 of 196 files calling ApplyGridFeatures contain zero AsNoTracking occurrences.
- **Reviewer note:** not adversarially verified (Medium/Low)

### #267 · Grid/list screens on core transactional tables (Donations, Cases) — Database indexing for list-query shape  — `Medium`

- **Module:** Performance & Scalability  |  **Category:** performance  |  **Verification:** ADJUSTED
- **Current implementation:** Verified in ApplicationDbContextModelSnapshot.cs: GlobalDonation (lines 11150-11299) has only single-column indexes (CompanyId, ContactId, PaymentStatusId, CurrencyId, DonationModeId, etc.) and zero composite indexes; Case (lines 6770-6839) has single-column indexes (AssignedStaffId, BranchId, StatusId, ProgramId, etc.) plus one composite `HasIndex("CompanyId","CaseCode").IsUnique()` uniqueness constraint only (line 6834). Confirmed GetGlobalDonationsHandler (GetGlobalDonations.cs:38-51) and GetCampaignsHandler default their base query to `.OrderByDescending(x => x.CreatedDate)`, matching the composite-key gap.
- **Gap identified:** No composite (CompanyId, CreatedDate) or (CompanyId, StatusId) indexes exist on the highest-traffic transactional tables (GlobalDonation, Case), despite this being the actual filter+sort shape every grid list handler executes on every page load.
- **Why it's a problem:** Postgres can only use the single-column CompanyId index for the tenant-scope equality predicate (also applied automatically via the global EF query filter, see multitenancy note) and must then perform an explicit in-memory sort for CreatedDate/StatusId ORDER BY -- for the tables that dominate day-to-day list traffic -- as tenant row counts grow, this becomes an increasingly expensive index-scan-plus-sort per request.
- **Recommended solution:** Add composite indexes matching the actual query shape: (CompanyId, CreatedDate DESC) and (CompanyId, StatusId) at minimum for GlobalDonation and Case; verify via EXPLAIN ANALYZE against production-sized data before/after.
- **Production impact:** Donation and Case list screens will see increasing query latency as data accumulates within a tenant, since no index matches the actual filter+sort shape -- but this degrades gradually with data volume rather than failing outright, and single-column CompanyId + StatusId/CreatedDate indexes still allow reasonably efficient plans up to moderate scale.
- **Business impact:** Core day-to-day screens used by every staff user will show gradually increasing latency as a tenant's operational history grows; a legitimate scaling risk but not an immediate release blocker.
- **Technical impact:** Query planner falls back to single-column index scan + explicit sort (or heap sort) for CompanyId-filtered, CreatedDate/StatusId-sorted queries on the largest tables in the schema.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Migrations/ApplicationDbContextModelSnapshot.cs:11263-11296 (GlobalDonation: single-column HasIndex calls only, no composite); :6816-6838 (Case: single-column indexes plus one CompanyId+CaseCode uniqueness index only); PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/GlobalDonations/Queries/GetGlobalDonations.cs:38-51 (base query default-sorted by CreatedDate).
- **Reviewer note:** Gap confirmed exactly as described (no composite indexes on GlobalDonation/Case matching the CompanyId+CreatedDate/StatusId query shape). However, original priority of High is overstated for a release-blocking audit: this is a gradual scaling concern, not a functional break or unbounded-memory bug like findings #1/#2 -- a single-column CompanyId index (present, and further reinforced by the automatic tenant query filter) still gives Postgres a reasonably efficient starting point at small-to-moderate per-tenant volumes. Downgraded to Medium; recommend as a proactive index addition validated by EXPLAIN ANALYZE rather than a pre-release blocker.

### #268 · Membership renewals, email analytics, ambassador dashboard export screens — Synchronous long-running export generation  — `Medium`

- **Module:** Performance & Scalability  |  **Category:** performance  |  **Verification:** CONFIRMED
- **Current implementation:** ExportAmbassadorDashboard.cs (Base.Application/Business/FieldCollectionBusiness/Ambassadors/Queries/ExportAmbassadorDashboard/ExportAmbassadorDashboard.cs) builds an 8-sheet Excel workbook by opening a brand-new NpgsqlConnection and issuing a separate `SELECT ... FROM fund.fn_...(...)` call sequentially for each of ~14 widget functions (CallWidgetFunction, lines 154-204, invoked serially via `await` in a `foreach` at lines 238 and from 8 separate `await BuildTabularSheet(...)` call sites), all within one synchronous GraphQL request/response cycle; similarly, ExportMembershipRenewalsHandler and ExportEmailAnalyticsRecipientActivityHandler run entirely inline on the request thread with no background-job offload, unlike StartImportCommand.cs which explicitly enqueues heavy work to a Hangfire job (`importService.StartImportJob`).
- **Gap identified:** Multi-step, multi-query report/export generation is done synchronously inline in the GraphQL request instead of being offloaded to the background-job infrastructure the team already uses for imports.
- **Why it's a problem:** As the widget/sheet count or underlying data volume grows, or if any one of the 14 sequential Postgres round trips is slow, the whole GraphQL request (and the HTTP connection serving it) is held open for the cumulative duration of all of them — there is no progress reporting, no timeout resilience, and no ability to cancel/retry a partial failure the way the SignalR-backed import job flow supports.
- **Recommended solution:** Route dashboard/report exports through the same Hangfire background-job + SignalR-progress pattern already established for imports (see StartImportCommand.cs), returning a job id immediately and pushing completion/download-ready status asynchronously, and parallelize the independent widget-function calls (Task.WhenAll) rather than awaiting them strictly in sequence.
- **Production impact:** Export requests block a request thread/HTTP connection for the full duration of many sequential DB round trips; no user-facing progress indicator for a genuinely multi-second operation.
- **Business impact:** Perceived unresponsiveness on dashboard export actions, particularly for tenants with larger ambassador/branch datasets where each widget function query grows proportionally.
- **Technical impact:** 14 sequential (not parallelized) ad-hoc NpgsqlConnection round trips per export request, executed synchronously in the request pipeline.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/FieldCollectionBusiness/Ambassadors/Queries/ExportAmbassadorDashboard/ExportAmbassadorDashboard.cs:60-134 (sequential awaits for BuildKpiSummarySheet + 6 BuildTabularSheet calls + BuildCollectionTrendSheet) and :154-204 (CallWidgetFunction opens a new NpgsqlConnection per call); contrast with PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ImportBusiness/Sessions/Commands/StartImport.cs:64-65 (`importService.StartImportJob(...)` offloading to Hangfire).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #324 · All MASTER_GRID screens (frontend) — auto-refresh polling — Client-side auto-refresh interval  — `Low`

- **Module:** Performance & Scalability  |  **Category:** performance  |  **Verification:** CONFIRMED
- **Current implementation:** useInitializeDataTableDatas (PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/advanced/data-table-fetch-data.tsx:154-172): when `capability?.canAutoRefresh && tableConfig?.enableAutoRefresh` is true, a `setInterval` fires `refetch()` (which forces `fetchPolicy: "network-only"`, line 189) every 120000ms per mounted grid instance, for as long as that grid component stays mounted, with no visibility/tab-focus check and no jitter/stagger across users.
- **Gap identified:** Auto-refreshing grids issue an unconditional network-only GraphQL request every 2 minutes regardless of whether the browser tab is visible/focused, and with no staggering, so many users with auto-refresh-enabled grids open simultaneously produce synchronized load spikes against the API every 2 minutes.
- **Why it's a problem:** network-only bypasses Apollo's cache entirely (by design, per the in-code comment about Apollo v4's fetchPolicy quirks), so each tick is a full round trip to the GraphQL resolver and DB for every open auto-refreshing grid tab across the tenant base — with no `document.visibilityState` gating, backgrounded/inactive browser tabs keep polling and consuming server resources at the same rate as active ones.
- **Recommended solution:** Gate the interval on `document.visibilityState === 'visible'` (pause when tab is hidden, resync on focus), add a small random jitter to the interval per client to avoid thundering-herd synchronization, and consider a server-push (SignalR, already used elsewhere in the app for import progress) model for auto-refresh instead of unconditional polling.
- **Production impact:** Not a hard blocker at current scale, but a straightforward, cheap-to-fix inefficiency that scales linearly with concurrent auto-refresh-enabled sessions.
- **Business impact:** Unnecessary infrastructure load/cost from background-tab polling that provides the user no visible benefit while the tab isn't being viewed.
- **Technical impact:** Fixed 120s interval per mounted grid instance with no visibility gating or jitter; network-only fetch policy guarantees a full DB round trip on every tick.
- **Evidence:** PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/advanced/data-table-fetch-data.tsx:154-172 (auto-refresh interval setup) and :188-189 (`policy = isManualRefresh ? "network-only" : ...` — refetch from auto-refresh routes through the same isManualRefresh/network-only path since it calls the shared refetch() at line 150-152 which bumps refreshTrigger).
- **Reviewer note:** not adversarially verified (Medium/Low)

### #325 · Import module — dynamic field/lookup generation (used by all bulk-import wizards) — Import lookup value caching  — `Low`

- **Module:** Performance & Scalability  |  **Category:** performance  |  **Verification:** CONFIRMED
- **Current implementation:** LookupService (Base.Infrastructure/Services/Import/LookupService.cs:15-20) declares a constructor parameter `IMemoryCache cache` but never assigns it to a field or uses it anywhere in the class; GetAllGridLookupValuesAsync (lines 23-69) unconditionally opens a raw DB connection and executes `import.fn_get_grid_lookup_values(@p_grid_id)` every single call, with no caching despite the cache dependency being injected.
- **Gap identified:** Caching was clearly intended (the IMemoryCache dependency is injected) but never wired up — every call to load grid lookup values (called once per import-template-generation request, per DynamicFieldGeneratorService.GenerateFieldsAsync at Base.Infrastructure/Services/Import/DynamicFieldGeneratorService.cs:45) re-executes the underlying Postgres function against master-data/foreign-key tables that change infrequently.
- **Why it's a problem:** Lookup/master-data values for a given import grid definition change rarely; re-querying them from scratch on every field-generation request (each import-wizard session, each template regeneration) is avoidable DB load with an already-present, unused caching mechanism.
- **Recommended solution:** Either use the injected IMemoryCache (keyed by gridId, short TTL e.g. 5-10 minutes, invalidated on master-data/import-grid-definition changes) or remove the unused dependency if caching was deliberately deferred — as written it's dead code masking a missed caching opportunity.
- **Production impact:** Minor avoidable DB load per import-wizard session; not a scaling blocker on its own but indicates an incomplete implementation.
- **Business impact:** Negligible directly, but signals a pattern of caching intentions not carried through to completion across the codebase.
- **Technical impact:** Unused DI dependency (IMemoryCache) — dead code that misrepresents the actual caching behavior to future maintainers.
- **Evidence:** PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Services/Import/LookupService.cs:15-20 (cache parameter injected, never stored/used) and :23-69 (GetAllGridLookupValuesAsync has no cache lookup/set); called from PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Services/Import/DynamicFieldGeneratorService.cs:45.
- **Reviewer note:** not adversarially verified (Medium/Low)

## Grants

### #148 · Grant Delete (DeleteGrant) — Grant delete cascade & guard  — `High`

- **Module:** Grants  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** DeleteGrantHandler simply flips Grant.IsDeleted=true with no cascade to child entities and no check for existing financial history.
- **Gap identified:** DeleteGrantHandler (DeleteGrant.cs) only sets Grant.IsDeleted=true. It never cascades soft-delete to GrantExpenses, GrantFundReceipts, GrantBudgetLines, GrantAttachments, GrantMilestones or GrantCommunications, and never checks whether the grant already has recorded fund receipts/expenses. A grant with real financial history can be deleted, leaving orphaned financial-ledger rows that still reference a 'deleted' Grant and will corrupt any reporting/rollup that doesn't independently re-check Grant.IsDeleted.
- **Why it's a problem:** A grant with real expenses, fund receipts, budget lines or attachments can be soft-deleted while its children remain active, leaving financial-ledger rows pointing at a 'deleted' parent.
- **Recommended solution:** Add a pre-delete guard that blocks deletion when GrantExpenses/GrantFundReceipts/allocations exist (or requires an explicit cascade), and cascade IsDeleted=true to GrantBudgetLines, GrantAttachments, GrantMilestones and GrantCommunications inside the same transaction/handler.
- **Production impact:** Reports and rollups that don't independently filter IsDeleted will surface orphaned or double-counted financial rows after a grant delete.
- **Business impact:** Financial history tied to a grant can vanish from grant-level views while still counting in global ledgers, breaking audit trust.
- **Technical impact:** Referential/soft-delete integrity is broken between Grant and its child aggregates, complicating future migrations and reporting joins.
- **Evidence:** Base.Application/Business/GrantBusiness/Grants/DeleteCommand/DeleteGrant.cs lines 22-41 (no child cascade, no financial-history guard)

### #149 · Grant Fund Receipt — Void (VoidGrantFundReceipt) — Grant fund receipt void re-validation  — `High`

- **Module:** Grants  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** VoidGrantFundReceiptHandler flips a receipt's status to CANCELLED immediately, with no check against existing GrantExpenses or ProgramFundingSource allocations already booked against it.
- **Gap identified:** VoidGrantFundReceiptHandler (VoidGrantFundReceipt.cs) flips a receipt's status straight to CANCELLED with zero downstream checks. CreateGrantExpense and AllocateGrantToFundingSource both compute 'cash available' as a live SUM over non-cancelled receipts minus expenses/commitments, but that guard only runs at the moment a NEW expense/allocation is created. Voiding an already-counted receipt after expenses/allocations were booked against it retroactively makes the grant's committed/spent total exceed its now-lower received total, with no re-validation or rebalancing at void time.
- **Why it's a problem:** Cash-on-hand and allocation-ceiling checks only run at the moment a new expense/allocation is created, so voiding an already-counted receipt after money has been committed/spent against it can push committed+spent totals above the now-lower received total, undetected.
- **Recommended solution:** Before allowing void, recompute cash-on-hand (SUM non-cancelled receipts minus committed/spent) and block or warn if voiding would drive it negative; alternatively require an offsetting reversal/adjustment workflow rather than a bare status flip.
- **Production impact:** Grant cash-on-hand can go negative in the data model with no system alert, breaking any downstream balance assumption.
- **Business impact:** Finance staff may report a grant as solvent when it has effectively over-spent against voided/reversed funding.
- **Technical impact:** State transition (void) bypasses the same invariant checks enforced at creation time, creating an inconsistent business-rule enforcement surface.
- **Evidence:** VoidGrantFundReceipt.cs lines 25-50 (no check against existing GrantExpenses/ProgramFundingSource.AllocatedAmount before cancelling); cash-on-hand formula in CreateGrantExpense.cs lines 54-91 relies on receipts staying non-cancelled

### #150 · Grant Lifecycle — Generic Stage Mover (UpdateGrantStage) — Grant approval bypass via generic stage mover  — `High`

- **Module:** Grants  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** UpdateGrantStageHandler permits a direct UNDERREVIEW→APPROVED transition through a generic mutation that only checks AwardedAmount>0, entirely bypassing ApproveGrantHandler's mandatory award-letter URL validation, GRANT_AWARD_LETTER attachment upsert, and GRANT_APPROVED_INTERNAL notification.
- **Gap identified:** UpdateGrantStageHandler (Base.Application/Business/GrantBusiness/Grants/UpdateCommand/UpdateGrantStage.cs) allows a direct UNDERREVIEW→APPROVED transition (permitted by GrantStageHelper.AllowedTransitions) through a generic mutation that only checks AwardedAmount>0. It completely bypasses the dedicated ApproveGrantHandler's mandatory business rules: requiring a valid http(s) award-letter evidence URL (ApproveGrant.cs lines 56-61), upserting the GRANT_AWARD_LETTER attachment (lines 68-101), and firing the GRANT_APPROVED_INTERNAL notification (lines 122-125). A caller can approve a grant with no funder evidence on file and no stakeholders notified, simply by calling updateGrantStage instead of approveGrant.
- **Why it's a problem:** A caller can approve a grant with no funder evidence on file and no stakeholders notified simply by invoking updateGrantStage instead of the dedicated approveGrant mutation, undermining the business rules the dedicated handler was built to enforce.
- **Recommended solution:** Remove UNDERREVIEW→APPROVED from GrantStageHelper.AllowedTransitions for the generic mover (or route that specific transition internally to ApproveGrantHandler's logic) so the award-letter validation, attachment upsert, and notification are always enforced regardless of entry point.
- **Production impact:** Any client or integration calling the generic stage-update mutation in production can silently approve grants without required evidence.
- **Business impact:** Grants could be marked approved without funder award-letter documentation on file, creating audit and funder-compliance exposure.
- **Technical impact:** Duplicate/divergent business-rule enforcement across two mutations for the same state transition is a maintainability and correctness risk.
- **Evidence:** Base.Application/Business/GrantBusiness/Grants/UpdateCommand/UpdateGrantStage.cs lines 50-69; ApproveGrant.cs lines 53-101, 122-125; GrantStageHelper.cs lines 36-48

### #249 · Grant / GrantExpense / GrantFundReceipt entities — optimistic concurrency — Grant concurrency control  — `Medium`

- **Module:** Grants  |  **Category:** concurrency  |  **Verification:** CONFIRMED
- **Current implementation:** Grant.cs, GrantExpense.cs and GrantFundReceipt.cs have no RowVersion column, and handlers like ApproveGrant, ActivateGrant, CreateGrantExpense and DeleteGrantExpense do read-then-mutate-then-save on shared fields (TotalSpent, StageId, AwardedAmount) with no concurrency token.
- **Gap identified:** Grant.cs, GrantExpense.cs and GrantFundReceipt.cs carry no RowVersion/concurrency-token column, yet many handlers (ApproveGrant, ActivateGrant, RejectGrant, UpdateGrantStage, CreateGrantExpense, DeleteGrantExpense, AllocateGrantToFundingSource) all do read-then-mutate-then-SaveChanges on shared fields like Grant.StageId, Grant.TotalSpent and Grant.AwardedAmount without any optimistic-concurrency check. Two concurrent requests can race and silently overwrite each other's TotalSpent/StageId update — last-writer-wins with no conflict detection.
- **Why it's a problem:** Two concurrent requests mutating the same grant (e.g. two expenses booked at once) can race, and the second SaveChanges silently overwrites the first's update with no conflict detected.
- **Recommended solution:** Add a `RowVersion` (byte[] concurrency token, EF `IsRowVersion()`) to Grant, GrantExpense and GrantFundReceipt, and catch `DbUpdateConcurrencyException` in the affected handlers to retry-reload or surface a conflict error to the client.
- **Production impact:** Under real concurrent staff usage, financial totals (TotalSpent, AwardedAmount) will intermittently be wrong with no error surfaced.
- **Business impact:** Grant budget/spend figures reported to funders or leadership can silently drift from the true sum of underlying transactions.
- **Technical impact:** Lost-update race conditions on shared aggregate fields with no detection, audit trail, or retry mechanism.
- **Evidence:** Base.Domain/Models/GrantModels/Grant.cs (no RowVersion); CreateGrantExpense.cs lines 93-100 and DeleteGrantExpense.cs lines 36-49 mutate grant.TotalSpent without a concurrency token

### #250 · Grant Expense — Create (CreateGrantExpense) — Grant expense budget-line cross-grant validation  — `Medium`

- **Module:** Grants  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** CreateGrantExpenseHandler loads the GrantBudgetLine only by GrantBudgetLineId, without verifying that line's GrantId matches the expense's input.GrantId.
- **Gap identified:** CreateGrantExpenseHandler (CreateGrantExpense.cs lines 95-100) loads the GrantBudgetLine solely by GrantBudgetLineId, with no check that the fetched line's GrantId matches input.GrantId. A caller can pass a GrantBudgetLineId belonging to a different grant, and the handler will silently increment that other grant's GrantBudgetLine.SpentAmount — corrupting a budget/spend rollup that belongs to an unrelated grant.
- **Why it's a problem:** A caller (buggy FE state, stale dropdown, or crafted request) can attach an expense to one grant while incrementing SpentAmount on a budget line belonging to an entirely different grant.
- **Recommended solution:** Add `b.GrantId == input.GrantId` to the FirstOrDefaultAsync filter (or an explicit post-fetch equality check that throws a validation error), and add the same guard in GrantBudgetLineHelper.
- **Production impact:** Cross-grant data corruption can occur silently in production with no error thrown to the caller.
- **Business impact:** Budget-vs-spend figures reported to an unrelated grant/funder become inaccurate, risking funder trust and compliance reporting.
- **Technical impact:** Missing tenant/entity-relationship validation lets unrelated aggregates be mutated cross-entity, a data-integrity hole that's hard to detect after the fact.
- **Evidence:** CreateGrantExpense.cs lines 95-100 (FirstOrDefaultAsync(b => b.GrantBudgetLineId == input.GrantBudgetLineId.Value) — no b.GrantId == input.GrantId filter); GrantBudgetLineHelper.cs has no such check either

### #251 · Grant Expense — Delete (DeleteGrantExpense) — Grant expense delete lifecycle lock  — `Medium`

- **Module:** Grants  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** DeleteGrantExpenseHandler soft-deletes a GrantExpense and decrements Grant.TotalSpent / GrantBudgetLine.SpentAmount with no check on the parent grant's lifecycle stage, and GrantExpense itself has no status field (Approved/Paid/Reconciled).
- **Gap identified:** DeleteGrantExpenseHandler (DeleteGrantExpense.cs) has no stage/lock check — it will soft-delete a GrantExpense and decrement Grant.TotalSpent / GrantBudgetLine.SpentAmount even if the parent grant has since moved to CLOSED or CANCELLED. GrantExpense has no status field (no Approved/Paid/Reconciled state), so any staff with Grant Modify permission can delete a booked expense at any time regardless of the grant's lifecycle stage, silently altering historical financial totals on a closed grant.
- **Why it's a problem:** Any user with Grant Modify permission can delete a booked expense on a CLOSED or CANCELLED grant at any time, silently altering historical financial totals that should be frozen.
- **Recommended solution:** Add an IsEditLocked/IsFundingActive check (grant stage must not be CLOSED/CANCELLED) before allowing delete, and introduce an expense status field so reconciled/paid expenses require a separate reversal flow rather than a hard delete.
- **Production impact:** Closed-grant financial reports can change after close-out with no system-level block or warning.
- **Business impact:** Auditors/funders relying on final reported spend for a closed grant may see numbers change retroactively, a compliance red flag.
- **Technical impact:** No lifecycle-state enforcement on financial mutations, undermining the integrity of any 'closed' or 'locked' period.
- **Evidence:** DeleteGrantExpense.cs lines 18-55 (no IsEditLocked/IsFundingActive check before mutating grant.TotalSpent); GrantExpense.cs lines 1-34 (no status field)

### #252 · Grant Fund Receipt — Create (CreateGrantFundReceipt) FX snapshot — Grant fund receipt FX snapshot fallback  — `Medium`

- **Module:** Grants  |  **Category:** currency  |  **Verification:** CONFIRMED
- **Current implementation:** CreateGrantFundReceiptHandler only populates ExchangeRate/GrantCurrencyAmount when a direct-pair FX rate is found; on a rate miss both columns stay NULL and downstream COALESCE logic in cash-on-hand and allocation-ceiling calculations falls back to the raw foreign-currency Amount as if already converted.
- **Gap identified:** CreateGrantFundReceiptHandler only snapshots ExchangeRate/GrantCurrencyAmount when receipt.CurrencyId != grant.CurrencyId AND a direct-pair FX rate is found (lines 82-94); on an FX-rate miss both columns stay NULL, and every downstream rollup (cash-on-hand in CreateGrantExpense, allocation ceiling in AllocateGrantToFundingSource) then falls back to the raw foreign-currency Amount via COALESCE as if it were already in the grant's currency. This silently mixes currency units in financial totals whenever an FX rate for that pair/date is not configured — no error, no visible degradation, and no re-conversion path once a rate later becomes available.
- **Why it's a problem:** Missing FX configuration for a currency pair/date causes silent unit-mixing in financial totals with no error, no visible flag, and no later re-conversion once the rate becomes available.
- **Recommended solution:** Fail loudly (validation error or a 'PendingFxConversion' status) instead of COALESCE-ing raw amounts on a rate miss, and add a background job/admin action to re-snapshot once the missing FX rate is entered, consistent with the direct-pair-only FX design.
- **Production impact:** Financial rollups can silently mix currencies whenever a rate is missing, producing materially wrong totals with no operator visibility.
- **Business impact:** Cash-on-hand and allocation figures reported to program/finance teams may be understated or overstated by the FX differential, undetected.
- **Technical impact:** Nullable FX snapshot fields plus COALESCE fallback create an implicit and undocumented currency-unit assumption baked into downstream SQL/LINQ aggregates.
- **Evidence:** CreateGrantFundReceipt.cs lines 79-94; GrantFxSnapshot.cs lines 26-42 (returns (null,null) on rate miss); consuming COALESCE in CreateGrantExpense.cs lines 54-60 and AllocateGrantToFundingSource.cs lines 90-96

### #320 · Grant Approve / Activate / Reject — internal notifications audit — Grant internal notification audit reliability  — `Low`

- **Module:** Grants  |  **Category:** observability  |  **Verification:** CONFIRMED
- **Current implementation:** ApproveGrant, ActivateGrant, RejectGrant and CreateGrantFundReceipt call SendInternalNotifyAsync inside a try/catch that swallows all exceptions and only LogWarning's, with the GrantCommunication audit row written inside that same try block.
- **Gap identified:** ApproveGrant, ActivateGrant, RejectGrant and CreateGrantFundReceipt all call GrantCommunicationHelper.SendInternalNotifyAsync in a try/catch that swallows all exceptions and only LogWarning's. Because the GrantCommunication audit row is only written inside that same try block, a failure anywhere in placeholder resolution or email dispatch means the state transition succeeds but there is NO GrantCommunication audit trail row at all for that event — the audit log silently under-reports notification failures with no alert, no retry, and no visible indicator to staff that a notification never went out.
- **Why it's a problem:** Any failure in placeholder resolution or email dispatch means the state transition still succeeds but leaves zero audit trail for that notification event, with no alert or retry.
- **Recommended solution:** Decouple audit-row persistence from notification dispatch (write the GrantCommunication row unconditionally, mark send-status separately), and add a retry queue or alerting on notification failures instead of a bare LogWarning.
- **Production impact:** Notification failures accumulate silently in production logs with no operational alert.
- **Business impact:** Staff may believe a funder/internal stakeholder was notified of a grant milestone when they were not, damaging relationship management.
- **Technical impact:** Audit log under-reports real system events, undermining its use as a reliable compliance/troubleshooting record.
- **Evidence:** GrantCommunicationHelper.cs lines 122-248 (whole SendInternalNotifyAsync body in try/catch, catch only logs a warning at line 246)

### #321 · Grant Fund Receipt — Create — tenant scoping defense-in-depth — Grant fund receipt tenant-scoping defense-in-depth  — `Low`

- **Module:** Grants  |  **Category:** security  |  **Verification:** CONFIRMED
- **Current implementation:** CreateGrantFundReceiptHandler resolves the grant via a bare GrantId lookup with no explicit CompanyId predicate, relying solely on the DbContext's global tenant query filter, then stamps the receipt with the current caller's CompanyId.
- **Gap identified:** CreateGrantFundReceiptHandler resolves grant via a bare dbContext.Grants.FirstOrDefaultAsync(g => g.GrantId == command.receipt.GrantId) with no explicit CompanyId predicate (line 56-59), then unconditionally stamps receipt.CompanyId = companyId from the current user's context. This relies entirely on the DbContext global tenant query filter; if CurrentTenantId is ever null/misconfigured for a non-SuperAdmin path (e.g. a background job), this handler would attach a fund receipt for a GrantId belonging to a different company under the caller's own CompanyId, with no defense-in-depth check at the handler level.
- **Why it's a problem:** If CurrentTenantId is ever null or misconfigured on a non-SuperAdmin path (e.g. a background job or service account), the handler would attach a fund receipt for another company's grant under the caller's own CompanyId with no handler-level check to catch it.
- **Recommended solution:** Add an explicit `g.CompanyId == companyId` predicate (or a post-fetch assertion) in the handler as defense-in-depth alongside the global query filter, matching the pattern used elsewhere for tenant-sensitive writes.
- **Production impact:** A tenant-context misconfiguration in a background/service path could cross-contaminate financial records between companies with no immediate error.
- **Business impact:** Cross-tenant data leakage in a multi-tenant SaaS is a severe trust and contractual risk for NGO customers.
- **Technical impact:** Single point of tenant isolation (global filter only) with no per-handler redundancy increases blast radius of any tenant-context bug.
- **Evidence:** CreateGrantFundReceipt.cs lines 56-69; ApplicationDbContext.cs lines 61-133 (global tenant filter is the sole isolation mechanism, no per-handler CompanyId re-check)

## Payments & Financial Integrity

### #256 · Payment Reconciliation (Screen #14) / RunAutoReconciliation — Bulk auto-matching of gateway transactions to donations  — `Medium`

- **Module:** Payments & Financial Integrity  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** RunAutoReconciliationHandler scores unmatched PaymentTransaction rows against unmatched GlobalDonation rows: base score 50, +25 for exact date match, +25 for contact match; rows scoring >= AutoMatchScoreThreshold (90) are auto-linked and committed in batches of 100 with no staff review or confirmation step before persisting.
- **Gap identified:** Only rows achieving BOTH bonuses (score 100) clear the threshold, but the scoring has no additional disambiguation when multiple GlobalDonation candidates tie at the same score (e.g., two different donors giving the identical round amount on the same day, both with a contact on file) - the code takes .FirstOrDefault() without further tie-breaking, and commits directly.
- **Why it's a problem:** This links real payment-gateway money movements to donation records automatically and irreversibly (no undo/review queue) based on a fuzzy heuristic; a mis-match would attribute one donor's payment to another donor's donation record, corrupting both donors' giving histories and potentially their tax receipts.
- **Recommended solution:** Require at least one additional disambiguating signal (e.g., exact amount + exact reference number) before auto-committing, or route score>=90 matches to a 'confirm in bulk' staff review screen rather than committing directly; add an audit trail entry per auto-match specifically flagging it as system-inferred (not staff-confirmed) so it can be distinguished and reversed later.
- **Production impact:** Automated reconciliation can mis-attribute real payments to the wrong donor record with no review gate.
- **Business impact:** Incorrect donor giving history and potential tax-receipt errors; reputational/compliance risk if discovered by a donor or auditor.
- **Technical impact:** Fuzzy-match auto-commit with no staff confirmation step and no tie-break beyond FirstOrDefault at equal scores.
- **Evidence:** Base.Application/Business/DonationBusiness/Reconciliation/RunAutoReconciliationCommand/RunAutoReconciliation.cs lines 41 (AutoMatchScoreThreshold=90), 181-207 (scoring formula), 221-282 (direct AddRange/commit in batches of 100, no review gate)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #257 · Recurring Donation Promotion (ODP-B5) / PromoteOnlineDonationStaging, PromoteRecurringCycle — Gateway fee capture for reconciliation  — `Medium`

- **Module:** Payments & Financial Integrity  |  **Category:** data  |  **Verification:** CONFIRMED
- **Current implementation:** Both PromoteOnlineDonationStaging.cs (lines 237-239) and PromoteRecurringCycle.cs (lines 205-207) hardcode GatewayFee = 0m, PlatformFee = 0m, TotalFee = 0m on the GlobalOnlineDonation record regardless of what the payment gateway actually charged in processing fees.
- **Gap identified:** The actual gateway-deducted fee (which every major processor - Braintree/Razorpay/PayU - reports per transaction) is never captured or stored, even though the DTO has dedicated fields for it.
- **Why it's a problem:** Net-of-fee reconciliation against the gateway's settlement report (bank deposit = gross donations - fees) becomes impossible to automate from PSS data alone; finance must manually re-derive fees from a separate gateway export for every settlement reconciliation, undermining the reconciliation-correctness goal this dimension is measuring against.
- **Recommended solution:** Populate GatewayFee/PlatformFee/TotalFee from the actual gateway API response (Braintree/Razorpay/PayU each return a fee/charge amount in their transaction detail response) at promotion time instead of hardcoding 0m.
- **Production impact:** Fee fields are structurally present but always zero, making gateway settlement reconciliation impossible without external data.
- **Business impact:** Finance team cannot reconcile bank deposits to donation totals without manually cross-referencing gateway fee reports.
- **Technical impact:** Fee-capture fields hardcoded to 0m at the only two write sites for GlobalOnlineDonation.
- **Evidence:** Base.Application/Business/DonationBusiness/OnlineDonations/Commands/PromoteOnlineDonationStaging.cs lines 237-239 (GatewayFee=0m, PlatformFee=0m, TotalFee=0m); PromoteRecurringCycle.cs lines 205-207 (same pattern)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #258 · Recurring Donation Promotion (ODP-B5) / ResolveOnlineDonationStaging — Recurring schedule creation failure handling  — `Medium`

- **Module:** Payments & Financial Integrity  |  **Category:** payments  |  **Verification:** CONFIRMED
- **Current implementation:** TryEnsureRecurringScheduleAsync in ResolveOnlineDonationStaging.cs (lines 577-585) wraps CreateRecurringDonationScheduleCommand in a try/catch that silently swallows any exception with only a code comment noting 'FE will surface a warning toast (SERVICE_PLACEHOLDER ISSUE-1)' - no actual toast/notification mechanism is wired at this layer.
- **Gap identified:** If schedule creation fails (e.g., no valid PaymentMethodTokenId, gateway subscription API error), the donation itself is still recorded successfully, but the donor's recurring commitment silently never gets a RecurringDonationSchedule - meaning all future cycles that the donor believes they signed up for will simply never be charged, with no staff-facing alert.
- **Why it's a problem:** A donor who committed to a recurring gift will stop being charged after the first cycle with no one - donor, staff, or system - being notified, resulting in silent revenue loss and a donor whose expressed philanthropic intent is not honored.
- **Recommended solution:** Replace the swallowed catch with a logged, alertable failure (e.g., write to the same Donation Inbox as a distinct 'recurring setup failed' item) so staff can manually complete the recurring schedule setup rather than the donor's commitment silently lapsing.
- **Production impact:** Recurring donor commitments can silently fail to convert into an active billing schedule after the first charge.
- **Business impact:** Lost recurring revenue with no detection mechanism; donor believes they are giving monthly but are not being charged.
- **Technical impact:** Exception swallowed with only a comment referencing a non-existent FE toast mechanism at this layer.
- **Evidence:** Base.Application/Business/DonationBusiness/OnlineDonationInbox/Commands/ResolveOnlineDonationStaging.cs lines 577-585 (catch swallows exception, comment 'SERVICE_PLACEHOLDER ISSUE-1'); PromoteOnlineDonationStaging.cs lines 405-414 (identical swallow pattern in the auto-promotion path)
- **Reviewer note:** not adversarially verified (Medium/Low)

### #323 · Refund Processing (Screen #13) / CreateRefund — Multi-tranche partial refund support  — `Low`

- **Module:** Payments & Financial Integrity  |  **Category:** business  |  **Verification:** CONFIRMED
- **Current implementation:** CreateRefund.cs's validator (lines 139-149) enforces via MustAsync that no non-deleted Refund row already exists for a given GlobalDonationId - i.e., at most one Refund row per donation, ever.
- **Gap identified:** A donation that was partially refunded once can never receive a second, later partial refund (e.g., a donor initially refunded 20% for a program-cancellation adjustment, then later needs an additional partial refund for a separate reason) - the second CreateRefund call is unconditionally blocked.
- **Why it's a problem:** While this rule does help prevent double-refunding, it also blocks a legitimate real-world business scenario (multiple partial refund tranches against one donation), forcing staff into manual workarounds (e.g., voiding and recreating the donation) that themselves risk data-integrity issues.
- **Recommended solution:** Relax the uniqueness rule to 'sum of all active refunds for this GlobalDonationId must not exceed DonationAmount' rather than 'at most one refund row ever', preserving the over-refund protection while allowing legitimate multi-tranche refunds.
- **Production impact:** Staff cannot process a second partial refund against a donation that was previously partially refunded.
- **Business impact:** Business-flexibility limitation requiring manual workaround for a legitimate multi-tranche refund scenario.
- **Technical impact:** Validator rule is overly restrictive (existence check instead of running-sum check).
- **Evidence:** Base.Application/Business/DonationBusiness/Refunds/Commands/CreateRefund.cs lines 139-149 (MustAsync !exists check blocking any second refund per GlobalDonationId)
- **Reviewer note:** not adversarially verified (Medium/Low)
