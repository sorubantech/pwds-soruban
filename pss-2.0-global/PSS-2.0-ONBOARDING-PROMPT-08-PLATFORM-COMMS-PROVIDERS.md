# DEV PROMPT P-08 — Platform Communication Providers: make Step 9 send for real + generalize the resolver across all platform channels

> Paste everything below the line into a **fresh development session**. It is self-contained.
> When done, report the outcome back to the PM session; do **not** start P-09 (the control-plane CRUD/UI).

---

## Role & mission

You are a Senior Backend Developer on the PSS 2.0 multi-tenant .NET + Next.js platform (**backend target framework `net10.0`**). A previous session built the **org/PLATFORM-level** communication-provider table `ops.PlatformCommunicationProviders` (the control-plane counterpart of the tenant-scoped `notify.CompanyEmailProviders`) and rewired the platform email path to resolve its sender from it. Your job is **P-08: finish the wiring so the platform actually communicates through that table.** Two concrete things:

1. **Part A — Step 9 (SEND_WELCOME) honors the send.** The provisioning welcome/activation email now resolves the platform EMAIL provider inside `EmailTemplateService.SendEmailByTemplateKeyAsync`, **but Step 9 discards that method's `bool` return** — so the step goes green whether or not mail actually left. Capture the result, make the outcome **observable** on the run/step, and confirm the send genuinely succeeds through the seeded platform provider.
2. **Part B — Generalize the resolver to all platform channels.** Extract the inline platform-provider lookup into a **reusable `IPlatformCommunicationProviderResolver`** (behaviour-preserving refactor of the EMAIL path), then wire **SMS** and **WHATSAPP** platform sends through the existing SMS/WhatsApp provider factories by adapting the platform provider's `ProviderConfiguration` JSON — so any platform-owned communication (not just the welcome email) resolves its sender from `ops.PlatformCommunicationProviders` by `Channel`.

The table, its EF config, both DbSets, and the EMAIL resolution block **already exist and are expected to compile** (previous session). You are **not** re-creating the table. You are: (A) a small edit to the Step 9 caller, and (B) a resolver extraction + two new channel send paths.

> ⚠️ **Depends on the migration + seed having been applied first.** Before you test anything, confirm `ops.PlatformCommunicationProviders` exists and holds a default EMAIL row (see Prereq). If the table is missing, **stop** — the migration is user-owned and must be applied before this prompt can be verified.

## Prereq — confirm before you build (do not skip)

The previous session left three user-owned artifacts. Confirm they are applied:

1. **Migration** `Add_PlatformCommunicationProviders` generated from the model and `database update` run → table `ops."PlatformCommunicationProviders"` exists. Reference DDL: `sql-scripts-dyanmic/ops-platform-communication-provider-migration-spec.sql`.
2. **Seed** `sql-scripts-dyanmic/ops-platform-communication-provider-seed.sql` run with a real `SG.` key + verified from-address → one row `Channel='EMAIL', IsDefault=true, IsActive=true`.

If either is missing, note it in the hand-back and ask the PM/user to apply them; do **not** author or run migrations yourself.

## Read first (grounding — do not skip; the backend tree is gitignored, so `Read`/`Bash grep`, not the Grep tool)

1. **`.../Base.Domain/Models/OpsModels/PlatformCommunicationProvider.cs`** — the entity. Fields you will use: `PlatformCommunicationProviderId int`, `Channel string` (`EMAIL|SMS|WHATSAPP`), `ProviderType string` (`SENDGRID|TWILIO|VONAGE|BIRD|CUSTOM|LOCAL|META_CLOUD`), `DisplayName string?`, `ProviderConfiguration string` (provider JSON the factory deserializes), `DefaultFromEmail string?`, `DefaultFromName string?`, `DefaultFromNumber string?`, `Priority int?`, `IsDefault bool`, `WebhookUrl string?`, `WebhookSecret string?`, `LastUsedAt DateTime?`, plus `Entity` base (`IsActive bool?`, `IsDeleted bool?`, `CreatedDate`, `ModifiedDate`). **No `CompanyId`** — the multi-tenant query filter never applies, so **no `IgnoreQueryFilters()` needed** for reads of this table.
2. **`.../Base.Infrastructure/Services/EmailTemplateService.cs`** — read `SendEmailByTemplateKeyAsync` (**lines ~48–150**). The platform-provider resolution block is **lines ~56–127**: query `_context.PlatformCommunicationProviders.Where(Channel=="EMAIL" && IsActive==true && IsDeleted!=true).OrderByDescending(IsDefault).ThenBy(Priority).FirstOrDefaultAsync()`, and if a provider with non-empty `ProviderConfiguration` + `DefaultFromEmail` exists, send via `_emailProviderFactory.CreateEmailProvider(providerType, ProviderConfiguration)` → `emailProvider.SendEmailAsync(message)`; on success return true, else **fall through** to the global appsettings key (`_emailHelperService.SendEmail`). This is the block you extract in Part B. Note the twins `...ForCompanyAsync` (line ~152) and `SendComposedEmailForCompanyAsync` (line ~277) — the tenant equivalents; mirror their structure but keep the platform path company-agnostic.
3. **`.../Base.Application/Business/OpsBusiness/TenantProvisioning/Commands/ProvisionTenant.cs`** — read `Step9_SendWelcomeAsync` (**lines ~883–935**). The `SendEmailByTemplateKeyAsync(emailDto, placeholders, ActivationTemplateCode, moduleId.Value, true)` call at **line ~931 discards the `bool`**. `ActivationTemplateCode = "TENANT_ADMIN_ACTIVATION"`. Note the step is intentionally reached only after the tenant is fully provisioned (steps 1–8 done), and it also stamps lead conversion (`StampLeadConversionAsync`) after the mail.
4. **`.../Base.Application/Data/Services/IEmailTemplateService.cs`** — the interface; `Task<bool> SendEmailByTemplateKeyAsync(EmailDto, Dictionary<string,string>, string emailTemplateKey, Guid ModuleId, bool skipOnMissingPlaceholders=true)`. Read the twin declarations too.
5. **SMS factory:** `.../Base.Support/Sms/Providers/Abstractions/ISmsProviderFactory.cs` → `ISmsProvider Create(SmsSettingSnapshot snapshot)`; `.../Base.Support/Sms/Providers/SmsProviderFactory.cs` (the switch); `.../Base.Support/Sms/Services/SmsSenderService.cs` (how a tenant SMS send is assembled). **Read `SmsSettingSnapshot`** — you must build one from the platform provider's `ProviderConfiguration` JSON + `DefaultFromNumber`.
6. **WhatsApp sender:** `.../Base.Application/BaseSupport/WhatsApp/IWhatsAppSenderService.cs` and its implementation + the WhatsApp provider factory/abstractions under `Base.Support` (Meta Cloud API). Read the send signature and the config/snapshot shape it needs.
7. **`.../Base.Application/Data/Persistence/IOpsDbContext.cs` + `.../Base.Infrastructure/Data/Persistence/OpsDbContext.cs`** — the `PlatformCommunicationProviders` DbSet is already declared on both (partial `ApplicationDbContext`). Consume it; do not re-add.

> Do not assume any property name — open the file. Audit fields are `CreatedDate`/`ModifiedDate` from `Entity`, never `createdAt`/`modifiedAt`. `ProviderConfiguration` is **plaintext JSON** (no encryption in this path — do not invent any).

## Hard constraints (violating any of these fails the task)

- 🔒 **Migrations are strictly user-owned.** Do **NOT** run `dotnet ef migrations add`, `database update`, or `remove`, and do **NOT** hand-author a migration or model-snapshot file. **This prompt needs no schema change** — the table already exists; you add a resolver, edit one caller, and add two channel send paths. If you believe a column is genuinely missing, **stop and produce a markdown migration spec for the user** — add nothing directly.
- **Do NOT run the backend build if the PM/user has said they'll build it** — prove correctness by reading, and say the build was left to the user. (Standing directive: *"avoid BE build, I can build that."*) If asked to build, exit 0 is the only clean result; a run reporting only a "pre-existing" stub error checked zero files → not clean.
- **UTC only.** Every date column is `timestamp with time zone`; Npgsql throws on `Kind=Unspecified`. Any date you write is `DateTime.UtcNow`; any boundary is built with `DateTimeKind.Utc`. When you stamp `LastUsedAt`, use `DateTime.UtcNow`.
- **No secret is ever hardcoded.** Provider keys live only in `ProviderConfiguration` (seeded by the user). Never log a full API key; mask if you must log at all.
- **No password / no PII leak in logs.** Step 9 mails a passwordless activation link only — never generate, email, log, or display a password. Do not log full recipient tokens.
- **The platform table has no `CompanyId`** → never call `IgnoreQueryFilters()` on it (pointless) and never try to filter it by tenant. Conversely, do not break the tenant paths (`...ForCompanyAsync`) — leave them exactly as they are.
- **Verify every property/method name before you use it.** Read the entity/DTO/service first. This especially applies to `SmsSettingSnapshot` and the WhatsApp send signature — they are typed, not free-form JSON.
- **BUSINESSADMIN** role only for tenant context; the platform paths run in control-plane/null-tenant context. No permission re-prompting.

## Scope — build exactly this

### Part A · Step 9 (SEND_WELCOME) honors the send outcome

In `ProvisionTenant.cs → Step9_SendWelcomeAsync`, **capture** the `bool` from `SendEmailByTemplateKeyAsync` and act on it. Design intent (**keep this**): a mail failure must **not** abandon or fail a fully-provisioned tenant — the tenant exists, and the admin can still be re-invited / the activation link re-sent. So:

- Assign `var welcomeSent = await _emailTemplateService.SendEmailByTemplateKeyAsync(...)`.
- **On `true`:** proceed exactly as today (stamp lead conversion, step SUCCEEDED). Log an info line ("welcome email sent").
- **On `false`:** do **not** throw and do **not** flip the run to `PAUSED_ON_ERROR`. Instead make it **observable**: record a soft warning on the run so an operator sees the mail didn't go out — the cleanest place is the **step row's `ErrorMessage`** (the step still ends `SUCCEEDED`, but `ErrorMessage` carries e.g. `"Provisioning completed but the welcome email could not be sent — resend from the tenant admin."`). If the step-status writer only allows `ErrorMessage` on a `FAILED` step, instead surface it via the run's audit/log path used elsewhere in this file; pick whichever mechanism this engine already exposes for a non-fatal note and **state which you used** in the hand-back. Always `_logger.LogWarning(...)` too.
- Still call `StampLeadConversionAsync` regardless of `welcomeSent` (conversion is about the tenant existing, not the mail).

> **Decision to surface, not to silently make:** if the PM later wants a welcome-mail failure to **hard-fail** Step 9 (so the run pauses and an operator must fix the provider before the run is "done"), that is a one-line change (`if (!welcomeSent) throw new ...`). Do **not** implement hard-fail now — implement the observable-but-non-fatal behaviour above and note the toggle point in the hand-back.

**Verification of "9th step success":** once the seed row exists, `SendEmailByTemplateKeyAsync` resolves the platform SENDGRID provider (EmailTemplateService lines ~56–127) and returns `true`, so Step 9 legitimately succeeds **with mail actually delivered** — that is the definition of done for Part A. If no platform EMAIL provider is seeded, the method falls through to the global appsettings key (unchanged legacy behaviour) and, if that also fails, Step 9 now records the warning instead of a silent green.

### Part B · Reusable resolver + SMS/WhatsApp platform channels

**B1 — Extract `IPlatformCommunicationProviderResolver`** (interface in `Base.Application/Data/Services/`, impl in `Base.Infrastructure/Services/`), a small service that centralizes the platform-provider lookup so all three channels share one code path:

```csharp
public interface IPlatformCommunicationProviderResolver
{
    // Returns the active default provider for the channel (IsDefault desc, then Priority),
    // or null if none configured. Channel: "EMAIL" | "SMS" | "WHATSAPP".
    Task<PlatformCommunicationProvider?> GetDefaultAsync(string channel, CancellationToken ct = default);
}
```

Impl queries `_context.PlatformCommunicationProviders.Where(p => p.Channel == channel && p.IsActive == true && p.IsDeleted != true).OrderByDescending(p => p.IsDefault).ThenBy(p => p.Priority).FirstOrDefaultAsync(ct)` — the exact ordering already used inline for EMAIL. Register it in DI wherever the other Infrastructure services are registered (match the existing registration file/pattern).

**Refactor `SendEmailByTemplateKeyAsync`** to call `_resolver.GetDefaultAsync("EMAIL")` instead of the inline query — **behaviour-preserving**: same null/empty-config fall-through to the global key, same `SendEmailAsync` path, same logs. Do not change the tenant twins. This is a pure extraction; the EMAIL send must behave identically before and after.

**B2 — Platform SMS + WhatsApp send.** Provide a thin platform-comms service that lets platform code send SMS/WhatsApp resolved from the same table, reusing the **existing** provider factories (do not build new provider implementations):

```csharp
public interface IPlatformCommunicationService
{
    Task<bool> SendSmsAsync(string toNumber, string message, CancellationToken ct = default);
    Task<bool> SendWhatsAppAsync(string toNumber, string message, CancellationToken ct = default);
    // (EMAIL already flows through IEmailTemplateService; no duplicate email method here.)
}
```

Implementation:
- Resolve via `_resolver.GetDefaultAsync("SMS")` / `("WHATSAPP")`. If null → log info ("no platform SMS/WhatsApp provider configured") and return `false` (do not throw — a missing optional channel is not an error).
- **Adapt** the platform provider's `ProviderConfiguration` JSON into the typed snapshot the factory needs. For SMS: deserialize into the shape `SmsSettingSnapshot` expects (map `ProviderType` → the factory's provider discriminator, `DefaultFromNumber` → the sender number) and call `ISmsProviderFactory.Create(snapshot)` → `provider.SendAsync(...)` (verify the real send method name on `ISmsProvider`). For WhatsApp: build the config the WhatsApp factory/sender expects from `ProviderConfiguration` (Meta Cloud creds) and call the existing sender. **Read the snapshot/config types first and match them exactly — these are typed blocks, not loose JSON.**
- On success, best-effort stamp `LastUsedAt = DateTime.UtcNow` on the provider row (fire-and-forget style is fine; a failure to stamp must not fail the send). Never log full credentials.
- Register in DI.

**B3 — Wire existing platform send sites (only if any exist).** Grep for platform-owned (non-tenant) send points that currently have no channel — e.g. control-plane operator notifications, provisioning failure alerts. If a real caller exists and needs SMS/WhatsApp, route it through `IPlatformCommunicationService`. **If none exists yet, do NOT invent callers** — deliver `IPlatformCommunicationService` as **built-but-dormant** (same pattern the codebase already uses for ready-but-unused capabilities) and note in the hand-back that no live SMS/WhatsApp platform caller was found, so those paths are dormant until a caller is added.

## Out of scope for P-08 (do NOT build — these are P-09+)

- **GraphQL CRUD + control-plane `(master)` screen** to manage `ops.PlatformCommunicationProviders` (list/create/update/delete, set-default, masked-key edit, test-send button). That is **P-09** — until then, providers are configured via the seed SQL. Do not build mutations/queries/UI for the table now.
- **Any change to the provisioning 9-step engine beyond Part A's caller edit.** Do not touch step ordering, steps 1–8, or the pricing/entitlement/lead logic.
- **Encryption of `ProviderConfiguration`.** It is plaintext by design in this path; do not add encrypt/decrypt.
- **New provider implementations** (new SendGrid/Twilio/Meta classes). Reuse the existing factories only.
- **Tenant paths** (`CompanyEmailProviders`, `SmsSettings`, `WhatsAppSettings`, `...ForCompanyAsync`). Leave them untouched.
- **Fallback chaining across multiple platform providers** (PRIMARY→FALLBACK by priority within a channel). The resolver returns the single default; multi-provider failover is a later enhancement — note it as a TODO, don't build it.

## Definition of done

1. **Solution builds clean** (or "left to user" per the standing directive — then prove correctness by reading and say so).
2. **Part A:** `Step9_SendWelcomeAsync` captures the `SendEmailByTemplateKeyAsync` result; on success the step proceeds as before, on failure it records an **observable non-fatal warning** (state the mechanism) and logs — the run is **never** paused/abandoned by a mail failure, and lead conversion still stamps. With a seeded platform EMAIL provider, Step 9 succeeds **with mail actually sent**. The hard-fail toggle point is documented but not implemented.
3. **Part B1:** `IPlatformCommunicationProviderResolver` exists, is DI-registered, and `SendEmailByTemplateKeyAsync` now uses it with **identical** EMAIL behaviour (same fall-through, same logs). No tenant path changed.
4. **Part B2:** `IPlatformCommunicationService` exists and is DI-registered; SMS + WhatsApp resolve the default platform provider by `Channel`, adapt `ProviderConfiguration` into the **correct typed snapshot/config**, send through the **existing** factories, best-effort stamp `LastUsedAt`, and return `false` (not throw) when no provider is configured. No credentials logged.
5. **Part B3:** any existing live platform SMS/WhatsApp caller is wired; if none exists, the service is delivered dormant and that is stated.
6. **No schema change / no migration authored or run.** If a column is genuinely missing, a markdown migration spec is produced for the user instead.
7. A short **hand-back note** (below).

## Report back to the PM session

State: build clean (Y/N, or "left to user"); the exact Step 9 edit + which **non-fatal warning mechanism** you used + confirmation the hard-fail toggle is left off (Part A); `IPlatformCommunicationProviderResolver` extracted and EMAIL behaviour preserved (Y/N) (Part B1); `IPlatformCommunicationService` SMS/WhatsApp wired through the existing factories, and the **exact `SmsSettingSnapshot` / WhatsApp config field mapping** you used (Part B2); whether any live platform SMS/WhatsApp caller existed or the paths are dormant (Part B3); and **every property/method/type name that differed from this brief** (esp. `ISmsProvider`'s send method, the WhatsApp sender signature, and the snapshot field names). **Do not start P-09 (the CRUD/UI).**
