# S1 — Configuration & Secrets Hardening (Backend)

**Wave 1 · start FIRST · longest item on the critical path (~1.5–2 h)**
**Repo:** `PSS_2.0_Backend` (nested git repo — stage from inside it)

> ## ⚠️ SCOPE REVISED 2026-08-09 — read before continuing
> **The release target is DEV/UAT, not production.** That cuts this session down hard.
>
> **Do tonight — sections 2 and 3 only.** In UAT these stop being security items and become *functional* ones: with `Auth:PlatformHosts` unset the app is unusable on a real hostname, and with the CORS origin wrong the frontend cannot call the API at all. **Finish these two, then stop and report.** Expect ~20 minutes, not two hours.
>
> **Defer to production cutover — section 1 in full.** Password/JWT rotation, `git rm --cached`, `.gitignore`, `appsettings.Example.json`. Recorded in [`PSS-2.0-PRODUCTION-CUTOVER-CHECKLIST.md`](../../PSS-2.0-PRODUCTION-CUTOVER-CHECKLIST.md).
>
> **Do NOT rotate `PaymentGateway:CredentialEncryptionKey`** (`appsettings.json:41`). It decrypts every stored `CompanyPaymentGateways` credential; rotating it without a re-encryption pass breaks payment config for every tenant. UAT runs sandbox credentials, so there is nothing to gain and a working environment to lose.
>
> **Constraint from S2 — do not break it.** S2 re-enabled signature validation on `sendgrid/events-raw`. Per `SendGridWebhookValidator.cs`: a missing key with validation enabled rejects **every** webhook (loud outage), and `SendGrid:WebhookValidationEnabled = false` accepts **every unsigned request** unconditionally (silent hole). If you touch `SendGrid:*` at all, the key must stay present and the flag must stay `true`.
>
> `"AllowedHosts": "*"` (`appsettings.json:51`) — leave it. Cutover item.

## Standing rules for this session
- **Never `git commit`.** Stage only (`git add`) and report. Never push, amend, or tag.
- Never add a `Co-Authored-By: Claude` trailer or a "Generated with Claude Code" line to any commit message you draft.
- **You do not run `dotnet build`.** Make compiling changes and hand off.
- **You do not create EF migrations** and do not edit `ModelSnapshot`.
- `BaseUrlConfig.ts` is user-managed — do not touch it.
- Do not probe ports or API liveness. The user runs the API and reports failures.
- **Stay inside the file list below.** Sessions S2–S6 are running in parallel on other files; editing outside your scope will collide.

## Why this session exists
A private key and two live database passwords are committed to a tracked file. Until that is rotated, no exposure decision about this release is meaningful — the credentials are compromised the moment the repo is shared, cloned, or forked.

## Scope

### 1. A1 — Secrets out of source control *(the main job)*
File: `PeopleServe/Services/Base/Base.API/appsettings.json` — currently **git-tracked**, contains a `BEGIN PRIVATE KEY` block and `Password=Ba0wKVNnLeCVe`, `Password=sKeIGZ2ejuGr`.

1. **Rotation is the fix, not deletion.** Deleting the file does not un-leak a key that already exists in git history. Produce for the user, as a checklist they execute:
   - rotate both PostgreSQL passwords
   - regenerate the JWT signing keypair
2. Move every secret to environment variables / user-secrets. Keep the *keys* in `appsettings.json` with empty or placeholder values so the shape stays self-documenting.
3. `git rm --cached` the file, add it to `.gitignore`, and commit an `appsettings.Example.json` with placeholders.
4. Verify the app fails **loudly at startup** when a required secret is absent — a null connection string that surfaces as a runtime 500 an hour later is worse than a startup crash.

### 2. A2 — CORS allowlist
File: `PeopleServe/Services/Base/Base.API/DependencyInjection.cs:402-406`

```csharp
app.UseCors(option => option
    .AllowAnyHeader()
    .AllowAnyMethod()
    .SetIsOriginAllowed(_ => true)   // ← any origin on the internet, with credentials
    .AllowCredentials());
```

Replace with an explicit origin allowlist read from configuration (`Cors:AllowedOrigins`). **`AllowCredentials` must stay** — SignalR's WebSocket transport needs it; that is exactly why the origin list has to become finite. Seed the list from config in this session since you own the config file.

### 3. D — Environment configuration
- **`Auth:PlatformHosts` must be set.** `HostTenantResolver.cs:112` returns `false` when it is unset. Localhost passes via the Development bypass, so this looks fine in every local test and then **nobody can log in** on a real hostname in a Production build. Confirm the code path, then document the exact value the user must set for the release host.
- Confirm `ops."PlatformCommunicationProviders"` has an active EMAIL row — without it mail silently never sends and nothing surfaces an error. **Report only; do not write the seed** (bucket E is already done by the user; just verify and flag).

## Acceptance
- [ ] `git ls-files | grep appsettings.json` returns nothing for the secret-bearing file
- [ ] No `BEGIN PRIVATE KEY` and no `Password=` literal anywhere in tracked files
- [ ] App startup throws a clear, named exception when a required secret is missing
- [ ] CORS accepts a finite configured origin list; `AllowCredentials` retained
- [ ] The exact `Auth:PlatformHosts` value for the release hostname is written down for the user

## Out of scope
Authorization attributes (S5), donation/payment logic (S2), anything in `PSS_2.0_Frontend` (S3), menu seeds (S4).

## Report back
The rotation checklist the user must execute by hand, and the config keys they must set before the release build.
