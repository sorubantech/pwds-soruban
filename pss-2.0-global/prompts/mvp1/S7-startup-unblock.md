# S7 — Startup unblock (post-S1 follow-up)

**RELEASE BLOCKER · ~10 minutes · do this before anything else**
**Repo:** `PSS_2.0_Backend` (nested git repo — stage from inside it)

## Standing rules
- **Never `git commit`.** Stage only (`git add`) and report. No push, amend, or tag.
- No `Co-Authored-By: Claude` / "Generated with Claude Code" line in any commit message you draft.
- You do not run `dotnet build`. You do not create EF migrations.
- **Never print, echo or paste a secret value** into your report, a file, or a log line. Key *names*
  only. If you recover an old value from git history, write it straight to its destination.
- Only two files are yours: `Extensions/RequiredConfigurationExtensions.cs` and the untracked
  local `appsettings.json`. S1 is finished; do not redo its work.

## Context
S1 moved every secret out of `appsettings.json` (now untracked, placeholders only) and added a
fail-loud startup validator. That was correct. Consequence: **the API no longer starts** until the
secrets exist in user-secrets, and one conditional check aborts startup even in Development.

## 1. Fix the SendGrid default mismatch *(real bug — do this first)*

`Extensions/RequiredConfigurationExtensions.cs:139`

```csharp
if (configuration.GetValue("SendGrid:WebhookValidationEnabled", false))
```

`Base.Support/Email/Webhooks/SendGridWebhookValidator.cs:39` reads the **same key with default
`true`**. The two disagree, and the disagreement is reachable: if the key is absent from config,
the startup check skips (believing validation is off), the validator switches itself on, finds no
verification key, and `ValidateSignature` then returns `false` for **every** SendGrid webhook.
Email status events stop, silently, with a passing startup.

**Change the startup default to `true`** so both sides agree on the safe reading. Do not change the
validator.

While you are in that block, the comment above it is wrong:

> "SendGridWebhookValidator logs a Warning and then accepts the webhook, so email status events
> become spoofable"

It does not accept. `SendGridWebhookValidator.cs:89-93` returns `false` when the ECDSA key failed to
load. Enabled-with-no-key is a **loud outage**, not a spoofing hole. The genuine fail-open is
`WebhookValidationEnabled = false`, which returns `true` unconditionally at line 77. Rewrite the
comment to say that — the check stays, only the stated reason changes.

## 2. Make the SendGrid check skippable in Development

That conditional has no `isDevelopment` guard, so a local run with `WebhookValidationEnabled: true`
and a blank key aborts startup. A developer who receives no SendGrid webhooks should not be blocked
by a webhook key.

Keep it hard-required **outside** Development (same treatment as `Auth:PlatformHosts` and
`Cors:AllowedOrigins` — reuse `Requirement.OutsideDevelopment`, do not invent a second mechanism).
In Development, downgrade to a startup **warning**, not silence: a developer who genuinely wants
signature validation locally still needs to be told why every webhook is being rejected.

## 3. Restore the local secrets so the API starts

The on-disk `appsettings.json` now has `""` for `ConnectionStrings:Database`,
`JwtSettings:PrivateKey`, `JwtSettings:PublicKey`, `Security:EncryptionKey` and
`PaymentGateway:CredentialEncryptionKey` — all `Requirement.Always`.

The previous values are recoverable; the file was untracked, not purged:

```
git show HEAD:PeopleServe/Services/Base/Base.API/appsettings.json
```

Put them in **user-secrets**, not back into the JSON file (`UserSecretsId` is already in
`Base.API.csproj`):

```
dotnet user-secrets set "ConnectionStrings:Database" "<old value>"
```

First run `dotnet user-secrets list` — S1 may already have populated the store, in which case do
nothing. **Report which keys were already present and which you added, by name only.**

> ⚠️ **`PaymentGateway:CredentialEncryptionKey` must be the OLD value, byte for byte.** It decrypts
> every stored `CompanyPaymentGateways` row. A freshly generated key silently breaks payment
> configuration for every tenant, and the failure surfaces at transaction time, not at startup.
> The same applies to the UAT environment.

## Acceptance
- [ ] Both `SendGrid:WebhookValidationEnabled` reads default to `true`
- [ ] The misleading comment is corrected
- [ ] The SendGrid check is required outside Development, warns inside it
- [ ] `dotnet user-secrets list` shows every `Requirement.Always` key
- [ ] No secret value appears in any tracked file, staged diff, or your report
- [ ] You did not modify `DependencyInjection.cs`, `Program.cs`, `.gitignore` or
      `appsettings.Example.json` — S1 owns those and they are correct

## Report back
The key names you added to user-secrets, and confirmation that the API's required-config list is
satisfied locally. Do **not** state whether the API is running — the user starts it.

## UAT deploy variables (for the release runbook, not this session)
`ConnectionStrings__Database` · `JwtSettings__PrivateKey` · `JwtSettings__PublicKey` ·
`Security__EncryptionKey` · `PaymentGateway__CredentialEncryptionKey` *(old value)* ·
`Frontend__BaseUrl` · `Auth__PlatformHosts__0` · `Cors__AllowedOrigins__0` ·
`SendGrid__WebhookVerificationKey`
