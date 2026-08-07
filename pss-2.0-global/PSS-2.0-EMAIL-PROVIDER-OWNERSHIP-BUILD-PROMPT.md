# PSS 2.0 — Email Provider Ownership (Platform vs BYO) Build Prompt

> **Status:** NOT BUILT — written 2026-08-05
> **Do NOT run before the MVP-1 demo (6 Aug 17:00).** This is backend + security work; §④ changes the credential surface. It goes **after** `PSS-2.0-BULK-EMAIL-JOB-RELIABILITY-BUILD-PROMPT.md`.
> **Hard prerequisite:** the migration `Add_EmailProviderOwnership` must be created **and applied** first — see `PSS-2.0-COMMUNICATION-METERING-MIGRATION-SPEC.md`. Nothing in this prompt can even be read from the DB until that column exists.
> **Companions:** `PSS-2.0-COMMUNICATION-METERING-BUILD-PROMPT.md` (built) · `PSS-2.0-TENANT-COMMS-CONFIG-UI-FIX-PROMPT.md` (this is effectively its Phase 3)

---

## ⚠️ Standing rules (non-negotiable)

1. **Do NOT run `dotnet build`.** The user builds the backend.
2. **Migrations are strictly user-owned.** Never run `dotnet ef migrations add/remove` or `database update`. Never hand-author a migration or a snapshot. If this prompt turns out to need a *new* column, **stop and write a spec** — do not scaffold it.
3. Seeds go to `sql-scripts-dyanmic/`. The user applies them.
4. Frontend typecheck: `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` with **no pipe**. Only exit 0 counts as clean.
5. `PSS_2.0_Backend/` and `PSS_2.0_Frontend/` are gitignored — the Grep/Glob tools return **zero** matches. Use `find -iname`, or scope `grep -rn --include=*.cs` to **one** project subdirectory (a repo-wide backend grep times out at 120 s; a repo-root frontend grep sweeps `node_modules`/`.next` and also times out). Absolute-path `Read` works fine.
6. HotChocolate **strips `Get`** from every resolver name and **appends `Input`** to input types. `tsc` cannot see gql field names — a wrong name builds clean and fails only at runtime. Read the resolver, then name the FE field.
7. Every Postgres date column is `timestamp with time zone`. `DateTime.UtcNow` only; never `DateTime.Today` in an EF predicate.
8. `ops` is platform-global — every read needs `IgnoreQueryFilters()` **and** an explicit `IsDeleted != true` guard. `PlatformCommunicationProvider` has **no `CompanyId`**, so the tenant query filter never applies to it.
9. Never assume a GraphQL field, DTO property, or column name — read the source first.
10. Widget/KPI icon containers and status badges use solid `bg-X-600` + `text-white`. Never `bg-X-50/100`, `text-X-700/800`, or `bg-muted-foreground`.
11. **No fallback.** Everything is configuration-driven and fail-closed. If no provider resolves, we do not send and we tell the user to configure one.

---

## §① The problem, stated plainly

Two defects on `setting/communicationconfig/emailproviderconfig`, reported by the user on 2026-08-05.

### Defect 1 — the screen shows a throttle and calls it a limit

A Growth-plan tenant has `billing.PlanQuota → EMAILS_PLATFORM FLOW 50000`, but the screen's **Sending Limits & Throttling** card reads `hourly 100 · daily 2400 · monthly 72000`.

Those are **two unrelated numbers**:

| | Plan quota | Provider throttle |
|---|---|---|
| Table | `billing.PlanQuota` | `notify.CompanyEmailProviders` (that tenant's row) |
| Means | what we **sold** them | how fast that mail account may push without tripping the vendor |
| Set by | platform, per plan | whoever filled in this form |
| Enforced by | Hook A / Hook B (metering, already built) | the sender's throttle |
| Resets | each billing period | rolling hour / day / month |

`100 / 2400 / 72000` appear in **no seed and no code** — verified by grep across `sql-scripts-dyanmic/`, `Base.Application/` and the FE settings tree. Somebody typed them into the form and saved. That is why the monthly throttle (72,000) exceeds the plan allowance (50,000) and reads as nonsense.

The screen never shows the plan allowance at all, so the tenant reads the throttle as their allowance.

### Defect 2 — the screen cannot express "I'm using the platform's provider"

The screen assumes exactly one thing: *you configure a provider*. There is no notion of *you are sending on ours*.

Verified state on disk:

| Fact | Evidence |
|---|---|
| `IsPlatformProvider` exists on the entity | `Base.Domain/Models/NotifyModels/CompanyEmailProvider.cs:41` |
| It is on the **response** DTO only, deliberately | `Base.Application/Schemas/NotifySchemas/CompanyEmailProviderSchemas.cs:48` + its XML doc |
| It is **never projected** by any query | `grep -rn "IsPlatformProvider" Base.Application/Business/NotifyBusiness/` → **no hits**. It therefore always returns `false` to the FE. |
| The FE has **zero** references to it | `grep -rn "isPlatformProvider" PSS_2.0_Frontend/src/` → **no hits** |
| The DB column does not exist yet | absent from every file in `Base.Infrastructure/Migrations/`, including `ApplicationDbContextModelSnapshot.cs` |
| The sender only ever reads tenant rows | `Base.Support/Email/Services/EmailSenderService.cs:96` → `GetCompanyEmailProvidersAsync(companyId, …)`. No `ops` lookup anywhere in `Base.Support/`. |
| `ops.PlatformCommunicationProviders` is wired only to **platform** mail | referenced from `OpsBusiness/LeadManagement/…` and the provisioning path — never from the tenant send path |

**Conclusion: a tenant cannot use the platform provider today. There is no code path.** The only way is to hand-insert a `CompanyEmailProvider` row containing our SendGrid key — which then means the tenant can read our credentials off this very screen.

---

## §② The design

### ②.1 Two modes, mutually exclusive

| Mode | Meaning | `IsPlatformProvider` |
|---|---|---|
| **PLATFORM** | Tenant sends on our infrastructure. Default for a newly provisioned tenant. | `true` |
| **OWN (BYO)** | Tenant brought their own SendGrid account. | `false` |

A company has **at most one** email provider row in PLATFORM mode, and a company in PLATFORM mode has **no** BYO rows. Switching modes is an explicit command, never a field edit. (Mixed platform-primary + BYO-fallback is out of scope — see §⑨ Q1.)

### ②.2 ★ Credentials are never copied into the tenant row

This is the security spine of the whole build. Read it twice.

A PLATFORM-mode `CompanyEmailProvider` row stores **`ProviderConfiguration = "{}"`** — an empty JSON object. It holds **no API key, no webhook secret, nothing**.

At send time, when `IsPlatformProvider == true`, the sender resolves the real credentials from `ops.PlatformCommunicationProviders` where `Channel = 'EMAIL'` and `IsDefault = true`.

**Rejected alternative:** copying our SendGrid key into the tenant's `ProviderConfiguration`. Rejected because (a) the tenant can read it back through `companyEmailProviderById`, and (b) rotating the platform key would then require an UPDATE across every tenant row. One indirection removes both problems permanently.

### ②.3 ★ The From-address trap

In PLATFORM mode the tenant may set a **From name** freely, but the **From email must be on our sending domain**.

If a tenant can set `DefaultFromEmail = ceo@somebank.com` and we send it on our infrastructure, we have built a phishing relay with our own SPF/DKIM alignment. It also poisons our domain reputation for every other tenant.

Rule:

- PLATFORM mode: `DefaultFromEmail` must end with `@<platform sending domain>` — take the domain from the ops row's `DefaultFromEmail`. Server-validated, not just FE.
- The tenant's real address goes in **Reply-To** (`EmailSendingIdentity.ReplyToEmail`), which is unauthenticated and safe.
- OWN mode: unchanged — it is their domain and their reputation.

### ②.4 What each mode shows

| Field | PLATFORM | OWN |
|---|---|---|
| Provider name | read-only text ("PeopleServe — SendGrid") | picker |
| API key / secret | **hidden** | required |
| Webhook URL + secret | **hidden** | shown |
| Sending domain + DNS records table | **hidden** — ours | shown, theirs to verify |
| Sending identities | shown (Reply-To editable, From locked to our domain) | shown, unrestricted |
| From name | editable | editable |
| From email | editable, **suffix-locked to our domain** | editable |
| Hourly / daily / monthly throttle + rate limit | **hidden** — we manage it | editable |
| IP & Reputation card | **hidden** | shown |
| **Plan allowance panel** | **shown** | **shown** |
| Primary action | `Use my own provider →` | `Switch back to platform sending` |

Note the last two rows. A BYO send still consumes `EMAILS` — the plan sells the *feature*, not just our infrastructure — so the allowance panel appears in **both** modes. Only `EMAILS_PLATFORM` is platform-only. That is INV-8 from the metering build and it must not be re-litigated here.

---

## §③ Schema

**No new migration.** This prompt is buildable entirely on `Add_EmailProviderOwnership`, which is already specced and pending.

Before starting, confirm the column landed:

```sql
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'notify'
  AND table_name   = 'CompanyEmailProviders'
  AND column_name  = 'IsPlatformProvider';
```

Expect one row: `boolean`, `NO`, `false`. **If this returns nothing, stop and tell the user.** Do not scaffold it yourself.

If any step below appears to need a further column, **stop and write a spec file** rather than inventing one.

---

## §④ Backend build steps

### ④.1 — Project `IsPlatformProvider` in every read path

It is on `CompanyEmailProviderResponseDto:48` but no query sets it, so the FE receives `false` unconditionally.

Add it to the projection in each of:

- `Base.Application/Business/NotifyBusiness/…` — the handler behind `GetCompanyEmailProviders` (list)
- …behind `GetCompanyEmailProviderById`
- …behind `ActiveCompanyEmailProvider`

Locate them from the resolvers in `Base.API/EndPoints/Notify/Queries/CompanyEmailProviderQueries.cs` (`:18`, `:51`, `:80`). Read each handler before editing — do not assume they share a mapper.

**Do not** add it to `CompanyEmailProviderRequestDto`. The XML doc at `:41–47` explains why: a tenant that can assert its own row is platform-owned can delete itself from the COGS meter.

### ④.2 — ★ Redact platform credentials on read

`CompanyEmailProviderResponseDto` **inherits** `ProviderConfiguration`, `WebhookUrl` and `WebhookSecret` from the request DTO. So today a PLATFORM row would hand our SendGrid key to any tenant user with provider-read rights.

In all three query handlers, after projection:

```csharp
if (dto.IsPlatformProvider)
{
    dto.ProviderConfiguration = "{}";
    dto.WebhookSecret = null;
    dto.WebhookUrl = null;
}
```

Redact **on the way out**, in the handler — not in the resolver, not on the FE. Anything that projects this DTO must inherit the redaction.

Then verify nothing else leaks it:

```
grep -rn "ProviderConfiguration" --include=*.cs Base.Application/Business/NotifyBusiness/
```

Every hit that reaches a response DTO needs the same guard.

### ④.3 — ★ Resolve platform credentials at send time

`Base.Support/Email/Services/EmailSenderService.cs:96` currently does:

```csharp
var emailProviders = await _emailProviderConfigRepository.GetCompanyEmailProvidersAsync(companyId, cancellationToken);
var primaryProvider = emailProviders …     // :97
if (primaryProvider == null) …             // :102 — fail closed, keep this
```

When `primaryProvider.IsPlatformProvider` is `true`, its `ProviderConfiguration` is `"{}"` and the SendGrid factory will fail. So before the config is handed to the factory:

1. Look up `ops.PlatformCommunicationProviders` where `Channel = "EMAIL"`, `IsDefault = true`, `IsActive`, `IsDeleted != true`, with `IgnoreQueryFilters()`.
2. Use **that row's** `ProviderConfiguration` for the factory.
3. If it is missing → **fail closed** with a distinct, actionable message: *"Platform email sending is not configured. Contact support."* Never fall back to `appsettings`. Never fall back to the tenant's empty config.
4. `DefaultFromName` / `DefaultFromEmail` still come from the **tenant** row (that is the point of the mode) — only the credentials come from `ops`.

Add a repository method rather than reaching into `OpsDbContext` from `Base.Support` — follow whatever pattern `Base.Support/Email/Repositories/` already uses, and read `ICompanyEmailConfigurationRepository.cs` / `IEmailProviderConfigRepository.cs` first.

**Leave `:130` alone.** `MeterDeliveredEmailsAsync(…, primaryProvider.IsPlatformProvider, …)` is already correct and is the metering build's INV-8.

### ④.4 — `UsePlatformEmailProvider` command

New: `Base.Application/Business/NotifyBusiness/CompanyEmailProviders/Commands/UsePlatformEmailProvider.cs`

Behaviour, in order:

1. Resolve the default `ops` EMAIL provider. **If none exists, fail** — do not create a half-configured row.
2. Deactivate (`IsActive = false`) every existing `CompanyEmailProvider` row for the company. Do not hard-delete — a tenant may switch back, and the row carries send history via `EmailSendQueues`.
3. Upsert the company's PLATFORM row:
   - `IsPlatformProvider = true`, `IsDefault = true`, `IsActive = true`, `Priority = 1`
   - `ProviderConfiguration = "{}"`
   - `EmailProviderId` / `EmailProviderTypeId` → the SENDGRID MasterData ids (see §⑤ — do **not** hard-code integers, resolve by code)
   - `DefaultFromName` from the input, defaulting to the company name
   - `DefaultFromEmail` from the input; if absent, derive `<company-slug>@<platform domain>`
   - throttle columns **null** — server-managed
   - `SendingDomainName` = the platform domain, `DomainStatus` = verified
4. Validate the From-email suffix per §②.3.
5. Return the redacted response DTO.

Idempotent: calling it twice is a no-op, not a duplicate row.

### ④.5 — `UseOwnEmailProvider` command

Same folder. The reverse:

1. Deactivate the PLATFORM row (keep it — switching back must not re-derive settings).
2. Activate or create a BYO row with `IsPlatformProvider = false`, `IsActive = true`, `IsDefault = true`, and the credentials supplied.
3. Full BYO validation applies — API key required, sending domain required, etc. Reuse whatever `SaveCompanyEmailProvider` (`CompanyEmailProviderMutations.cs:150`) already validates rather than writing a second rule set.

**Neither command may set `IsPlatformProvider` from client input.** The value is decided by which command was called. That is the entire point of keeping it off the request DTO.

### ④.6 — Guard the existing write paths

`SaveCompanyEmailProvider`, `UpdateCompanyEmailProvider`, `DeleteCompanyEmailProvider` and `ActivateDeactivateCompanyEmailProvider` (`CompanyEmailProviderMutations.cs:150 / :54 / :122 / :89`) must all **refuse** to operate on a row where `IsPlatformProvider == true`, with a message pointing at `useOwnEmailProvider`.

Otherwise a tenant edits the platform row's throttle, or deletes it, and their mail stops with no explanation.

Exception: `DefaultFromName`, `DefaultFromEmail` and sending identities remain editable on a platform row — those are the only tenant-owned fields in PLATFORM mode, and the From-email suffix rule from §②.3 applies to them.

### ④.7 — GraphQL surface

Add to `Base.API/EndPoints/Notify/Mutations/CompanyEmailProviderMutations.cs`:

| Resolver method | Schema field (HotChocolate strips nothing here — no `Get` prefix) |
|---|---|
| `UsePlatformEmailProvider` | `usePlatformEmailProvider` |
| `UseOwnEmailProvider` | `useOwnEmailProvider` |

And a query so the FE can render the PLATFORM card without any credential round-trip. Add to `…/Queries/CompanyEmailProviderQueries.cs`:

| Resolver method | Schema field | Returns |
|---|---|---|
| `GetPlatformEmailSenderInfo` | **`platformEmailSenderInfo`** ← `Get` **is** stripped | `{ displayName, sendingDomainName, isAvailable }` — **never** credentials |

Follow the capability/authorisation attributes already on the neighbouring resolvers in each file. Read them; do not invent a new policy.

---

## §⑤ MasterData lookups

`CompanyEmailProvider.EmailProviderId` and `EmailProviderTypeId` are non-null FKs to `MasterData`. §④.4 needs the SENDGRID pair.

Resolve them **by code at runtime** — never hard-code the integer ids, which differ per environment. Find the existing lookup pattern first:

```
grep -rn "EmailProviderId\|SENDGRID" --include=*.cs Base.Application/Business/NotifyBusiness/
```

If the SENDGRID MasterData rows are missing in an environment, the command must fail with a clear message naming the missing code — **not** with an FK violation.

If a seed turns out to be needed, write it to `sql-scripts-dyanmic/` and list it in §⑧ for the user to apply.

---

## §⑥ Frontend build steps

All files under `src/presentation/components/page-components/setting/communicationconfig/emailproviderconfig/`.

### ⑥.1 — Mode state

`email-provider-config-page.tsx` currently renders one unconditional form (`FormState` at `:98`, cards 1–6 from roughly `:600` down).

Derive:

```ts
const mode: "PLATFORM" | "OWN" = activeProvider?.isPlatformProvider ? "PLATFORM" : "OWN";
```

Add `isPlatformProvider` to `CompanyEmailProviderDto.ts` and to the gql selection set in `infrastructure/gql-queries/notify-queries/CompanyEmailProviderQuery.ts`. **A field absent from the selection set arrives `undefined` and reads as OWN mode** — check every query in that file, not just the by-id one.

### ⑥.2 — PLATFORM card

New `platform-sender-card.tsx`:

```
┌─ Email Sending ─────────────────────────────────────┐
│  ✉ Sending through PeopleServe        [● Active]    │
│  You're using our email infrastructure.             │
│  No setup needed.                                   │
│                                                     │
│  From name  [ Hope Foundation           ]           │
│  From email [ hope        ]@mail.peopleserve.com    │
│  Reply-to   [ contact@hopefoundation.org ]          │
│                                                     │
│  Plan allowance  ████████░░  12,430 / 50,000        │
│                  resets 1 Sep 2026                  │
│                                                     │
│                        [ Use my own provider → ]    │
└─────────────────────────────────────────────────────┘
```

The From-email input is a **local-part field with the domain rendered as a fixed suffix** — the tenant cannot type a domain, so §②.3 cannot be violated from the UI. The server still validates it.

Status chip: solid `bg-green-600` + `text-white`.

### ⑥.3 — Conditional rendering of the existing cards

Per the §②.4 table. Hide, do not disable — a greyed-out API-key field on a platform tenant invites a support ticket.

Cards affected, with current anchors in `email-provider-config-page.tsx`:

| Card | PLATFORM |
|---|---|
| Provider selector (`provider-card-selector.tsx`) | hide |
| Connection / API key + Webhook URL (`~:730`) | hide |
| Sending domain + `DnsRecordsTable` (`~:849`) | hide |
| Sending Identities (`~:864`) | **show** — Reply-To is the tenant's own |
| Sending Limits & Throttling (`~:893`) | hide |
| IP & Reputation (`~:988`) | hide |

### ⑥.4 — ★ Plan allowance panel (fixes Defect 1) — **both modes**

New `plan-allowance-panel.tsx`, rendered **above** the throttle card.

Data source: **`myCommunicationUsage`** — already shipped by the metering build (`Base.API/EndPoints/Billing/Queries/PlanCatalogQueries.cs:82`, resolver `GetMyCommunicationUsage`). Read that resolver's return type before writing the selection set.

Copy rules:

- Heading: **"Your plan includes"**
- Never write *"this month"*. Always **"resets on {date}"** — the metering build's §⑤.4 wording rule, because a billing period is not a calendar month.
- Bar colours: under 80 % `bg-green-600`, 80–99 % `bg-amber-600`, at/over 100 % `bg-red-600`. Solid, white text.

### ⑥.5 — Relabel the throttle card (OWN mode only)

Rename **"Sending Limits & Throttling"** → **"Provider Throttling"**, and replace the helper line at `~:981` ("Limits nest: hourly ≤ daily ≤ monthly…") with:

> These protect your provider account from rate-limiting. They are **not** your plan allowance — see *Your plan includes* above.

Keep the nesting validation (`:480`). Add one non-blocking warning: if the monthly throttle exceeds the plan allowance, show *"Higher than your plan allowance of {n} — sending will stop at the plan limit first."* A warning, not an error: the throttle is legitimately allowed to be larger.

### ⑥.6 — Mode switch

`Use my own provider →` opens a confirm dialog: *"You'll need a SendGrid API key and a verified sending domain. Your emails will stop until setup is complete."* On confirm → `useOwnEmailProvider` → refetch → the form renders empty in OWN mode.

`Switch back to platform sending` → confirm → `usePlatformEmailProvider` → refetch.

Both invalidate the provider query **and** `myCommunicationUsage`.

---

## §⑦ Explicitly out of scope

| Excluded | Why |
|---|---|
| SMS and WhatsApp ownership modes | Same design applies, but MVP-1 ships them disabled with "Coming soon". Do not touch `smssetup/` or `whatsappsetup/`. |
| A platform screen to manage `ops.PlatformCommunicationProviders` | Already built — `Base.API/EndPoints/Ops/…/PlatformCommunicationProvider*` |
| Mixed platform-primary + BYO-fallback | §⑨ Q1 |
| Per-tenant platform sub-domains (`hope.mail.peopleserve.com`) | MVP-2. One shared platform domain for now. |
| Changing any plan quota number | `PSS-2.0-COMMUNICATION-METERING-BUILD-PROMPT.md` §⑨ D1, still unratified |
| Anything that needs a new column | Rule 2 — write a spec instead |

---

## §⑧ Acceptance

1. ☐ `information_schema` confirms `notify."CompanyEmailProviders"."IsPlatformProvider"` exists **before** any code is written
2. ☐ `grep -rn "IsPlatformProvider" Base.Application/Business/NotifyBusiness/` returns hits in **all three** query handlers
3. ☐ ★ A PLATFORM row read through `companyEmailProviderById` returns `providerConfiguration = "{}"`, `webhookSecret = null` — verified in the GraphQL playground, not by reading code
4. ☐ ★ `usePlatformEmailProvider` writes `ProviderConfiguration = "{}"` — assert the platform API key is **not** in `notify."CompanyEmailProviders"` anywhere:
   `SELECT "CompanyEmailProviderId" FROM notify."CompanyEmailProviders" WHERE "ProviderConfiguration" LIKE '%SG.%';` → **0 rows**
5. ☐ ★ A send from a PLATFORM-mode tenant delivers, using the `ops` credentials
6. ☐ ★ With the `ops` default EMAIL row deactivated, the same send **fails closed** with the §④.3 message — no appsettings fallback, no silent success
7. ☐ A PLATFORM send increments **both** `EMAILS` and `EMAILS_PLATFORM` (INV-8 still holds)
8. ☐ A BYO send increments `EMAILS` **only**
9. ☐ ★ Setting `DefaultFromEmail` to an off-domain address in PLATFORM mode is **rejected server-side**, not only in the UI
10. ☐ `updateCompanyEmailProvider` against a PLATFORM row is refused with the §④.6 message
11. ☐ `usePlatformEmailProvider` called twice produces one row, not two
12. ☐ Switching OWN → PLATFORM → OWN preserves the original BYO row's credentials
13. ☐ PLATFORM mode renders no API-key, webhook, DNS, throttle or reputation field anywhere in the DOM
14. ☐ The plan allowance panel renders in **both** modes and never says "this month"
15. ☐ `npx tsc --noEmit --incremental false` exits **0**
16. ☐ Backend compiles — **the user runs this**
17. ☐ No migration file and no snapshot change in the diff

Items marked ★ are security or fail-closed acceptance. If one cannot be demonstrated, the build is **not** done.

---

## §⑨ Open questions

| # | Question | Blocks | Recommendation |
|---|---|---|---|
| Q1 | Can a tenant run platform-primary **with** a BYO fallback? | §②.1 exclusivity, §④.4 step 2 | **No for MVP.** Exclusive modes. Mixed ownership makes "which meter" ambiguous per send and doubles the test matrix. |
| Q2 | What is the platform sending domain? (`mail.peopleserve.com`?) | §②.3, §⑥.2 suffix | Needed before §④.4 can validate anything |
| Q3 | Is BYO gated by plan feature, or open to every tenant? | §④.5 authorisation | **Open to all.** Gating BYO means a small tenant is forced onto our infrastructure, which raises our COGS on the cheapest plan — backwards. |
| Q4 | On provisioning, does a new tenant land in PLATFORM mode automatically? | `ProvisionTenantCommand` step ordering | **Yes** — otherwise every new tenant's welcome flow has no sender. Would add a step to the provisioning engine; confirm before building. |
| Q5 | Do the SENDGRID `MasterData` rows exist in every environment? | §⑤ | Check before building; a seed may be owed |
| Q6 | When a tenant exceeds the plan allowance in PLATFORM mode, do we stop sending or soft-warn? | Hook A behaviour is already "block" | Metering already blocks. Confirm that is the commercial intent for platform-mode tenants specifically. |

> **Q2 is a hard blocker** — §②.3, §④.4 and §⑥.2 all need the literal domain.

---

## §⑩ Build log

| Date | Section | What was done | Result |
|---|---|---|---|
| 2026-08-05 | — | Prompt written. Not started. | — |
