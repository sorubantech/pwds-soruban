# PROMPT-09 — Platform communication providers: control-plane CRUD + `(master)` screen

**Task ID:** T-A15 (Phase A.4 — completes T-A14 / PROMPT-08)
**Surface:** BE + FE
**Model:** Sonnet — §④ (write-only credentials) and §⑤ (the one-default-per-channel index) are the two places to slow down.
**Depends on:** T-A14 (PROMPT-08) — **BUILT**. Sequence **after PROMPT-14** finishes; see §0.2.
**Schema change:** **NONE.** No entity edit, no EF migration, no snapshot touch. This is the cheapest prompt in the sequence — do not turn it into a data-model exercise.

---

## §⓪ Why this exists

PROMPT-08 shipped the **read** half of platform-owned sending and stopped there. Verified on disk today:

| Exists | Missing |
|---|---|
| `Base.Domain/Models/OpsModels/PlatformCommunicationProvider.cs` | any Command |
| `Base.Infrastructure/Data/Configurations/OpsConfigurations/PlatformCommunicationProviderConfiguration.cs` | any Query |
| `Base.Application/Data/Services/IPlatformCommunicationProviderResolver.cs` | any Schema DTO |
| `Base.Infrastructure/Services/PlatformCommunicationProviderResolver.cs` | any `EndPoints/Ops/` resolver |
| `Base.Application/Data/Services/IPlatformCommunicationService.cs` | any frontend file — `grep` over `PSS_2.0_Frontend/src` for `PlatformCommunicationProvider` returns **zero** matches |
| `Base.Infrastructure/Services/PlatformCommunicationService.cs` | |
| migration `20260729062510_Add_PlatformCommunicationProvider` | |

**The consequence is not cosmetic.** `ops.PlatformCommunicationProviders` is the table the platform sends its **own** mail from — the tenant-admin welcome/activation email out of provisioning Step 9. With no write path:

1. The only way to configure the platform sender is hand-written SQL against production.
2. The seed is user-owned and **still unapplied**, so `GetDefaultAsync("EMAIL")` returns `null` today and every platform welcome email falls through to the legacy global `appsettings` SendGrid key — **which is the exact silent no-mail failure PROMPT-08 was written to fix.** The root cause is fixed in code and unreachable in practice.
3. Rotating a leaked SendGrid API key is a DBA task with no audit trail.

This prompt closes that: a control-plane screen that lets platform staff create, edit, default, test and retire platform senders.

### §0.1 What this prompt is *not*
It is **not** the tenant-facing comms config (`notify.CompanyEmailProviders` / `SmsSettings` / `WhatsAppSettings`). Those are per-tenant and already have their own screens. This table has **no `CompanyId` and must never grow one** — the multi-tenant query filter does not apply to it, and `IgnoreQueryFilters()` is never needed.

### §0.2 Ordering against PROMPT-14
PROMPT-14 is in flight and is writing to the same two neighbourhoods: `Base.API/EndPoints/Ops/` (or a new `Billing` endpoints folder) and the `(master)/platform/` route group. **Run this prompt only after PROMPT-14 reports done.** Two mitigations:

- **No migration** here, so there is no `ApplicationDbContextModelSnapshot.cs` race — the usual serialisation blocker does not apply.
- If PROMPT-14 has already created `(master)/platform/layout.tsx` sibling routes, **extend** that group; do not restructure it.

---

## §① Read first (grounding)

The backend tree is **gitignored** — the Grep tool returns zero `.cs` matches. Use absolute-path `Read`, or `grep -rn --include=*.cs` **scoped to one project subdirectory** (a repo-wide backend grep exceeds the 120 s timeout).

Base path: `PSS_2.0_Backend/PeopleServe/Services/Base/`

1. `Base.Domain/Models/OpsModels/PlatformCommunicationProvider.cs` — every field you will expose.
2. `Base.Infrastructure/Data/Configurations/OpsConfigurations/PlatformCommunicationProviderConfiguration.cs` — **the two indexes are the whole of §⑤.**
3. `Base.Application/Data/Services/IPlatformCommunicationProviderResolver.cs` — `PlatformCommunicationChannels.Email/Sms/WhatsApp` constants; reuse them, do not re-declare string literals.
4. `Base.Application/Data/Services/IPlatformCommunicationService.cs` — the send path your Test action calls.
5. `Base.Application/Business/OpsBusiness/LeadManagement/Commands/CreateCommercialTerm.cs` + `.../Queries/GetCommercialTerms.cs` — **the house CQRS shape for an `ops` entity.** Copy this structure.
6. `Base.Application/Schemas/OpsSchemas/TenantSchemas.cs` — house DTO style (plain classes, setters, XML doc on non-obvious fields).
7. `Base.API/EndPoints/Ops/Queries/TenantQueries.cs` + `Mutations/LeadMutations.cs` — house resolver registration.
8. The tenant email-provider screen (`notify` / company email provider config) — **for the credential-masking pattern only.** Do not copy its components; this is a different route group and a different table.

---

## §② Reuse — do not rebuild

| Need | Use | Note |
|---|---|---|
| Channel constants | `PlatformCommunicationChannels` | `Email`/`Sms`/`WhatsApp`. Never inline `"EMAIL"`. |
| Default-provider lookup | `IPlatformCommunicationProviderResolver.GetDefaultAsync` | Read-only; **do not** add write methods to this interface. Writes belong in your new commands. |
| Test send | `IPlatformCommunicationService` | Already built and dormant. Your Test action is its **first live caller** — that is intended, not scope creep. |
| Provider-type validity | the existing channel factories (`EmailProviderFactory` and the SMS/WhatsApp equivalents) | §⑤ validates against **their** switch keys. Do not invent a new registry. |
| Grid pipeline / Mapster | the `GetCommercialTerms` pattern | Same pagination + sort + filter contract. |
| Soft delete / audit | `Entity` base | `IsDeleted`, `createdDate`/`modifiedDate` — **not** `createdAt`/`modifiedAt`. |

---

## §③ Data model — NO CHANGE

Do **not** add, rename, widen or re-type any column. Do **not** run `dotnet ef migrations add`. Do **not** edit `ApplicationDbContextModelSnapshot.cs`. If you believe a field is missing, **stop and report it in §⑬** rather than adding it — a schema change here forces migration sequencing against PROMPT-14 and destroys this prompt's main advantage.

The one thing to note: `IsActive` and `IsDeleted` come from `Entity`; `IsDefault` is on the entity itself and is index-enforced (§⑤).

---

## §④ Backend

All under `Base.Application/Business/OpsBusiness/PlatformCommunicationProviders/`, mirroring `LeadManagement`'s folder shape.

### 4.1 Queries
- `GetPlatformCommunicationProviders` — paginated list for the grid. Filterable by `Channel`, `IsActive`. Default sort: `Channel`, then `IsDefault` desc, then `Priority` asc nulls last, then `DisplayName`.
- `GetPlatformCommunicationProviderById` — the edit form's loader.

### 4.2 Commands
- `CreatePlatformCommunicationProvider`
- `UpdatePlatformCommunicationProvider`
- `DeletePlatformCommunicationProvider` — **soft** (`IsDeleted = true`), guarded by §5.4.
- `SetDefaultPlatformCommunicationProvider` — see §5.1. A dedicated command, **not** a flag on Update.
- `TestPlatformCommunicationProvider` — operator supplies a destination (email address / phone number); resolves **this specific provider** (not the channel default), sends through `IPlatformCommunicationService`, returns `{ success, errorMessage }`. See trap 4.

### 4.3 Schema DTOs
`Base.Application/Schemas/OpsSchemas/PlatformCommunicationProviderSchemas.cs`:

- `PlatformCommunicationProviderResponseDto` — grid row + detail. **Never carries `ProviderConfiguration` or `WebhookSecret` in plaintext.** Instead:
  - `bool IsConfigured` — `true` when `ProviderConfiguration` is non-empty.
  - `bool HasWebhookSecret`.
  - Everything else (Channel, ProviderType, DisplayName, DefaultFrom*, Priority, IsDefault, IsActive, LastUsedAt, audit) passes through normally.
- `PlatformCommunicationProviderUpsertDto` — the write shape. `ProviderConfiguration` and `WebhookSecret` are **nullable**; see §4.4.
- `TestPlatformCommunicationProviderDto` — `{ int PlatformCommunicationProviderId, string Recipient }`.

### 4.4 Write-only credentials (mandatory, mirrors PROMPT-14 §7.2)
`ProviderConfiguration` and `WebhookSecret` are **write-only**:

- Reads never return them. The FE renders `••••••••` when `IsConfigured`/`HasWebhookSecret` is true, and an empty field otherwise.
- On **Update**, a `null` or empty submitted value means **"unchanged"** — retain the stored value. It does **not** mean "clear". There is deliberately no way to blank a credential through this screen; retiring a provider is `IsActive = false` or soft-delete.
- On **Create**, `ProviderConfiguration` is **required** (the column is `IsRequired()` and the factory deserializes it).
- Never log either value. Never echo them in an error message.

### 4.5 GraphQL registration
New `Base.API/EndPoints/Ops/Queries/PlatformCommunicationProviderQueries.cs` and `.../Mutations/PlatformCommunicationProviderMutations.cs`.

**HotChocolate naming — verify against the running schema, tsc cannot catch this.** `Get` is stripped from **every** resolver, list and by-id alike, and `Input` is **appended** to input types:

| C# | GraphQL field |
|---|---|
| `GetPlatformCommunicationProviders` | `platformCommunicationProviders` |
| `GetPlatformCommunicationProviderById` | `platformCommunicationProviderById` |
| `PlatformCommunicationProviderUpsertDto` | `PlatformCommunicationProviderUpsertDtoInput` |

A wrong field name compiles clean and fails only at runtime. Check the schema before wiring the FE documents.

### 4.6 Authorization
Guard every resolver with the platform capability from §⑦ — **not** a tenant capability, and **not** `IsSuperAdmin()` alone (T-A9's rule). These credentials are platform-wide; a tenant BUSINESSADMIN must never reach them.

---

## §⑤ Guards

### 5.1 One default per channel — the index will throw at you
`PlatformCommunicationProviderConfiguration` declares:

```csharp
builder.HasIndex(p => p.Channel)
    .IsUnique()
    .HasFilter("\"IsDefault\" = true AND \"IsDeleted\" = false")
    .HasDatabaseName("IX_PlatformCommunicationProviders_Channel_IsDefault_Filtered");
```

Promoting a provider therefore **cannot** be a bare `IsDefault = true` update — it violates the filtered unique index while the incumbent still holds it. `SetDefaultPlatformCommunicationProvider` must, **in one transaction**: demote the current default for that channel → `SaveChanges` → promote the target. Same rule applies inside `Create` and `Update` when the payload asks for `IsDefault = true`.

### 5.2 Channel × ProviderType must be a pair the factory knows
Validate against the **existing** factory switch keys, read from the source (do not trust this table if it has drifted):

- `EMAIL` → `SENDGRID`
- `SMS` → `TWILIO` | `VONAGE` | `BIRD` | `CUSTOM` | `LOCAL`
- `WHATSAPP` → `META_CLOUD`

An unknown pair is rejected at the command with a clear message. This is a **fail-closed** validation: an unrecognised platform sender would silently break our own outbound mail.

### 5.3 `ProviderConfiguration` must parse as JSON
Reject a payload that is not valid JSON, with a message that does **not** echo the content. Do not attempt to validate the *shape* per provider type — the factory owns that, and a shape check here would rot.

### 5.4 Deletion / deactivation guard
Refuse to soft-delete or deactivate a row that is currently `IsDefault = true` **for a channel that has no other active provider** — that silently returns the channel to the legacy `appsettings` fall-through, reintroducing the original bug. Message must name the channel and say what to do (set another provider as default first). Deleting a non-default row is unguarded.

### 5.5 No tenant leakage
No `CompanyId` filter, no `IgnoreQueryFilters()`, no tenant context read anywhere in these handlers. If you find yourself needing either, you have the wrong table.

---

## §⑥ Frontend

**Route:** `PSS_2.0_Frontend/src/app/[lang]/(master)/platform/communications/page.tsx`
Inside the existing `(master)/platform/` group, alongside `dashboards/`. Reuse `platform/layout.tsx` as-is.

### 6.1 Screen type
`MASTER_GRID` — a list of platform senders with a form. It is **not** a CONFIG singleton: there are legitimately several rows (one default plus fallbacks, across three channels).

### 6.2 Grid
Columns: Channel · Provider Type · Display Name · Default From · Priority · Default · Status · Last Used.

- **Channel** and **Provider Type** as solid badges: `bg-X-600` + `text-white`. Never `bg-X-50`, `text-X-700`, `bg-muted`, or `text-muted-foreground`.
- **Default** as a solid badge when true; blank when false. Not a checkbox column.
- **Last Used** — relative or short date; `—` when null. A default EMAIL provider with a null `LastUsedAt` is a meaningful signal (nothing has sent through it yet) — do not hide the column.
- Shaped `Skeleton` while loading; explicit empty state — **and the empty state matters here.** When there is no EMAIL provider at all, the empty state should say plainly that platform email is falling back to the legacy global key. That is the screen earning its existence.

### 6.3 Form (drawer or dialog, house pattern)
Channel select → Provider Type select **filtered by the chosen channel** per §5.2 (client-side mirror of the server guard; the server remains authoritative). Then Display Name, the credential JSON field, Default From email/name/number **shown per channel** (email fields for EMAIL, number for SMS/WHATSAPP), Priority, Webhook URL + Secret, Is Default, Is Active.

- Credential field: `••••••••` placeholder when `IsConfigured`; helper text stating that leaving it blank keeps the existing credential. Required on create, optional on edit.
- Save button gated on RHF `formState.isValid`, **never** on a capability flag. Capability governs only the visibility of the "+ New" entry point.
- Tokens only — no hex, no arbitrary `px`, no `text-[10px]`. Responsive xs→xl. `@iconify` Phosphor icons.

### 6.4 Row actions
**Set as default** (hidden when already default) · **Test** · Edit · Delete.

**Test** opens a small dialog asking for the destination, calls `testPlatformCommunicationProvider`, and reports success or the returned error inline. Do not fire a test silently from a row click — it sends a real message.

### 6.5 Typecheck
`cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` with **no pipe**. Only **exit 0** counts as clean. A run whose sole output is a pre-existing `TS2688` stub-types error has checked **zero** files and is not a pass.

---

## §⑦ Menu + RBAC (spec only — the user applies the seed)

- New menu item under the platform/control-plane parent, `MenuUrl` = `platform/communications`, `IsLeastMenu = true`, `IsActive = true`.
- New capability pair on the `PLATFORM_*` family: `PLATFORM_COMMS` (view) and `PLATFORM_COMMS_MANAGE` (create/update/delete/set-default/test). Register in `auth.MenuCapabilities`; grant to the platform operator role only.
- Grid registration in `sett.Grids` per house convention.

---

## §⑧ Seed spec — `sql-scripts-dyanmic/platform-comms-crud-menu-capability-seed.sql`

Write the file; **do not apply it**. Idempotent (`WHERE NOT EXISTS` / `ON CONFLICT DO NOTHING`), one transaction.

1. Menu row per §⑦.
2. `PLATFORM_COMMS` + `PLATFORM_COMMS_MANAGE` capabilities.
3. `auth.MenuCapabilities` links.
4. `auth.RoleCapabilities` grants for the platform operator role **only**.
5. Grid row in `sett.Grids`.

Note in the header comment that `auth` holds Roles/Capabilities and `sett` holds Grids — do not qualify these with `app`.

---

## §⑨ Acceptance

1. `platformCommunicationProviders` returns a paginated list; `platformCommunicationProviderById` returns one.
2. Create with a valid `EMAIL`/`SENDGRID` pair succeeds.
3. Create with `EMAIL`/`TWILIO` is **rejected** with a message naming the invalid pair.
4. Create with malformed JSON in `ProviderConfiguration` is rejected, and the response does **not** echo the payload.
5. Create with empty `ProviderConfiguration` is rejected.
6. **Update with a blank credential field leaves the stored credential intact** — verified by a successful test-send afterwards, not by reading the column.
7. No read path ever returns `ProviderConfiguration` or `WebhookSecret` plaintext — confirmed by inspecting the raw GraphQL response, not the UI.
8. `IsConfigured` / `HasWebhookSecret` are `true` for a configured row, `false` for one without.
9. **Set-default on channel EMAIL demotes the incumbent and promotes the target in one transaction** — no unique-index violation, and afterwards exactly one EMAIL row has `IsDefault = true`.
10. Set-default on EMAIL leaves the SMS default untouched.
11. Soft-deleting the only active default for a channel is **blocked** with a message naming the channel.
12. Soft-deleting a non-default row succeeds.
13. Deactivating the only active default for a channel is blocked by the same guard as (11).
14. Test-send against a correctly configured provider **delivers**, and stamps `LastUsedAt`.
15. Test-send against a **non-default** provider with deliberately wrong credentials **fails and reports the failure** — it must not silently succeed by resolving the channel default instead. (This is the trap-4 test; run it explicitly.)
16. A tenant BUSINESSADMIN session cannot reach any of these resolvers.
17. No handler references `CompanyId`, tenant context, or `IgnoreQueryFilters()`.
18. `git status` shows **no** new migration and **no** change to `ApplicationDbContextModelSnapshot.cs`.
19. FE `npx tsc --noEmit --incremental false` exits **0**.
20. Grid, form, badges and empty state verified in a browser — items 6, 14, 15 and the empty-state copy cannot be verified by a compiler.

---

## §⑩ Out of scope — do NOT build

- **Multi-provider failover** (PRIMARY → FALLBACK walking `Priority`). The resolver's own TODO defers this; `Priority` is captured and displayed but nothing consumes it yet. Leave it dormant.
- Per-tenant provider overrides. Different table, different screen.
- Any change to the tenant-facing `notify.*` comms screens.
- PROMPT-14's platform **payment gateway** screen — adjacent route group, unrelated table.
- Provider-shape validation per vendor (the factory owns it).
- Migrating existing `appsettings` credentials into the table. That is a user-owned operational step, listed in §⑫.

---

## §⑪ Traps

1. **Bare `IsDefault = true` update.** The filtered unique index rejects it while the incumbent still holds the flag. Demote-then-promote in one transaction (§5.1).
2. **Blank credential read as "clear".** It means unchanged. Getting this backwards silently wipes the platform's SendGrid key and reintroduces the exact silent no-mail bug (§4.4).
3. **Returning `ProviderConfiguration` to the client** because Mapster mapped the entity straight to the response DTO. Mapster will happily map it — the DTO must simply not have the property (§4.3).
4. **Test-send resolving the channel default instead of the selected row.** `IPlatformCommunicationProviderResolver.GetDefaultAsync` takes a *channel*, so the obvious call tests whichever row is default — reporting green on the exact row being diagnosed. `TestPlatformCommunicationProvider` must load the row **by id** and build the send from *that* configuration.
5. **Adding `CompanyId`** because every other table has one. This table's entire point is not having one (§0.1).
6. **`createdAt`/`modifiedAt`.** The audit fields are `createdDate` / `modifiedDate`.
7. **Adding a migration** for a field that "seems missing." Report it in §⑬ instead (§③).
8. **Restructuring `(master)/platform/`** if PROMPT-14 has already extended it. Add a sibling route; change nothing else.
9. **Hard-coding channel strings.** Use `PlatformCommunicationChannels`.
10. **`bg-X-50` / `text-X-700` badges.** Solid `bg-X-600` + `text-white`, without exception.

---

## §⑫ Hand-off — user-owned, do not perform

1. `dotnet build` the backend (the user builds).
2. Apply `sql-scripts-dyanmic/platform-comms-crud-menu-capability-seed.sql`, then restart the API.
3. Apply the **still-outstanding PROMPT-08 provider seed** (the platform SendGrid row) — or, better, create it through this new screen, which is the whole point.
4. Move the production SendGrid key out of `appsettings` and into a platform provider row; verify a provisioning welcome email actually delivers.
5. Update `PSS-2.0-ONBOARDING-TASK-LIST.md` T-A15 → BUILT.

---

## §⑬ Build log

_(Append one entry per session: date, what landed, deviations from this spec and why, known issues. Cap at the last 5 sessions — git holds the rest. Preserve the Known Issues list in full.)_

### 2026-08-04 — T-A15 built (BE + FE + seed)

**Landed — backend** (`PSS_2.0_Backend`, builds clean: `638 Warning(s) 0 Error(s)`):

- DTOs — `PlatformCommunicationProviderResponseDto` (**no** `ProviderConfiguration`, **no** `WebhookSecret`; exposes `IsConfigured` / `HasWebhookSecret` instead), `PlatformCommunicationProviderUpsertDto`, `TestPlatformCommunicationProviderDto`, `PlatformCommunicationProviderTestResultDto`.
- Queries — list (paginated, filterable by channel / provider type / active / search) + by-id.
- Commands — Create, Update, Delete (soft), SetDefault, Test.
- All resolvers `[CustomAuthorize("PLATFORM_COMMS", "PLATFORM_COMMS_MANAGE")]`. No `CompanyId`, no tenant context, no `IgnoreQueryFilters()` anywhere in the slice.

**Landed — frontend** (`npx tsc --noEmit --incremental false` → **no output, exit 0**):

- `domain/entities/ops-service/PlatformCommunicationProviderDto.ts` — types + `PLATFORM_COMMUNICATION_CHANNEL_OPTIONS`, `PLATFORM_COMMUNICATION_PROVIDER_TYPES`, `providerTypesForChannel()`.
- `infrastructure/gql-queries/ops-queries/PlatformCommunicationProviderQuery.ts` and `gql-mutations/ops-mutations/PlatformCommunicationProviderMutation.ts` (create / update / delete / set-default / test).
- `page-components/ops/communications/` — `comms-chips.tsx`, `comms-form-schemas.ts`, `comms-form-dialog.tsx`, `comms-test-dialog.tsx`, `platform-comms-list-page.tsx`, `index.ts`.
- Route `app/[lang]/(master)/platform/communications/page.tsx` — added as a **sibling** of `billing/`, `dashboards/`, `gateways/`, `webhook-logs/`. Nothing else under `(master)/platform/` was touched (trap 8).

**Landed — seed (written, NOT applied):** `sql-scripts-dyanmic/platform-comms-crud-menu-capability-seed.sql` — menu `PLATFORM_COMMS`, capability pair, `MenuCapabilities` (incl. `ISMENURENDER`), role grants, `sett."Grids"` header row. Idempotent, one transaction, VERIFY block after `COMMIT`.

**Deviations from this spec, and why:**

1. **`MenuUrl` is `/platform/communications`, with a leading slash** — §⑦ writes it without one, but every platform menu row already in the DB carries the slash (`/platform/billing`, `/platform/webhook-logs`). Matched the stored convention; noted in the seed header.
2. **Role grants are PLATFORM_ADMIN + SUPERADMIN only** — narrower than the adjacent gateway seed, which also gives `PLATFORM_FINANCE` / `PLATFORM_SUPPORT` a VIEW. §⑧.4 says "the platform operator role **only**", and this is the one screen where a vendor credential is entered and a billable send is fired. Widen through Access Control if operations asks.
3. **No `sett."Fields"` / `"GridFields"` rows** — §⑦ asks for grid registration "per house convention"; the convention for a developer-owned custom screen (precedent: `organizationbankaccount-menu-seed.sql`) is the `Grids` header row alone. The write-only credential JSON cannot be expressed by the generic RJSF form, so per-field metadata would be dead rows.
4. **Capability gating uses `has("PLATFORM_COMMS")` / `has("PLATFORM_COMMS_MANAGE")`, not the hook's `canView`** — `usePlatformCapabilities().canView` is hardwired to `PLATFORM_TENANT_VIEW` and would have gated this screen on an unrelated capability.
5. **Two empty/fallback states, not one** — §6.2 asks for the "no EMAIL provider" warning. Implemented as `noEmailSenderAtAll` (true empty state) *and* `emailMissingAmongRows` (a red banner when rows exist but none are EMAIL), the second guarded to an unfiltered single-page result set since a filtered page cannot prove the configuration.

**No schema change.** No migration added, `ApplicationDbContextModelSnapshot.cs` untouched. No field was found missing.

### 2026-08-04 (later) — credential entry converted from JSON to named fields

The operator was being asked to author `ProviderConfiguration` as raw JSON. Operations staff do not know
JSON, so the textarea is gone: the form now renders the discrete fields the chosen vendor actually needs
and the **server** assembles the stored document.

**Landed — backend** (`Base.Application` scoped build: `579 Warning(s) 0 Error(s)`):

- New `Business/OpsBusiness/PlatformCommunicationProviders/PlatformCommunicationCredentialSchema.cs` — the single field registry (`Key`, `IsSecret`, `IsRequired` per provider type, keys taken verbatim from the consumers `SendGridConfiguration` / `PlatformSmsConfiguration` / `PlatformWhatsAppConfiguration`) plus `FieldsFor` / `MissingRequiredFields` / `Serialize` / `Split` / `Label`. It is the only place the JSON is built or taken apart.
- `PlatformCommunicationCredentialDto` (30 properties; the property names **are** the JSON keys) replaces the upsert DTO's `ProviderConfiguration` string. The response DTO gained `Credential` + `SecretFieldsSet`.
- Create validates required fields before writing; Update merges per field over the stored document. **Merge rule:** secret blank ⇒ unchanged (the form never held it), non-secret blank ⇒ cleared (the form *did* show it), `bool?`/`int?` null ⇒ unchanged. Unknown/legacy keys already in the document are preserved untouched. Missing-field errors name the **label**, never a value.

**Landed — frontend** (`npx tsc --noEmit --incremental false` → **no output, exit 0**):

- `PlatformCommunicationProviderDto.ts` — `PlatformCommunicationCredentialDto`, `PlatformCredentialFieldMeta`, the `PLATFORM_CREDENTIAL_FIELDS` registry (label / kind / required / secret per vendor) and `credentialFieldsForProviderType()`, mirroring the C# registry.
- `PlatformCommunicationProviderQuery.ts` — selects `secretFieldsSet` and a `credential { … }` block listing **only** non-secret members.
- `comms-form-schemas.ts` — nested `credentialSchema`; the `JSON.parse` refinement is replaced by a registry-driven required-field check that exempts a required secret already present in `secretFieldsSet`.
- `comms-form-dialog.tsx` — per-vendor field group (password inputs for secrets, checkbox/number/textarea by `kind`), re-seeded when the provider type changes, and a `buildCredential()` submit payload that sends trimmed strings so a cleared non-secret actually clears.

**Deviation — authorized by the user, overrides acceptance item 7:**

6. **Acceptance item 7 ("no read path ever returns `ProviderConfiguration` … plaintext") is relaxed to secrets-only.** The user chose "secrets masked, rest readable" so the screen can show what is configured instead of forcing a full re-key on every edit. Non-secret members (Twilio Account SID, endpoint URLs, sender IDs, IP pool, tracking domain, sandbox flag, originators, from-numbers, WABA/phone-number IDs, Graph API version) are returned in plaintext. True secrets — SendGrid `ApiKey`, `TwilioAuthToken`, `VonageApiSecret`, `BirdApiKey`, `LocalApiKey`, `LocalApiSecret`, `CustomAuthValue`, Meta `AccessToken` — are still never returned, never selectable, and never logged; only their names appear in `SecretFieldsSet`. `WebhookSecret` is unchanged: still `HasWebhookSecret` only.

**No schema change.** Values still land in the existing `ProviderConfiguration` column; no migration, no snapshot edit.

**Known issues:**

0. **Unrelated build break outside this slice:** `Base.API/EndPoints/Ops/Queries/LeadQueries.cs` lines 167 and 213 fail with CS0029 — `BaseApiResponse<IReadOnlyList<PlanOptionDto>>` / `<GatewayRouteDto>` cannot convert to `BaseApiResponse<IEnumerable<…>>` (from `ApiResponseHelper.ReturnObjectApiResponse(result.plans)` / `(result.gateways)`). It comes from the PROMPT-23 Lead slice, not T-A15, and was left untouched. The solution will not build until it is fixed.
1. **Acceptance items 6, 14, 15 and 20 are unverified** — blank-credential-preserves-the-key, a real test-send delivering, the trap-4 wrong-credential test failing loudly, and the browser check of grid/form/badges/empty-state. None can be verified by a compiler; all require the seed applied and the API running. They are the first things to run in §⑫.
2. **`Priority` is captured and displayed but consumed by nothing** — multi-provider failover is explicitly out of scope (§⑩). The column reads as if it does something. Left dormant per spec.
3. **The legacy global SendGrid key in `appsettings` still wins nothing and loses nothing here** — the screen tells the operator about it but cannot see or migrate it. That migration is §⑫.4, user-owned.
