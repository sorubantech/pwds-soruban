# S8 — Tenant onboarding wizard: business-completeness gaps

**Scope:** the first-login tenant setup wizard (`/[lang]/setup`) and its relationship to the go-live
checklist. **Not** the ops provisioning wizard (that runs before the tenant ever logs in and is out of
scope here).

**Why now:** onboarding is the centrepiece of tonight's demo. Everything below was verified against
source, not assumed. Each item says explicitly whether it is demo-blocking or not, so nothing gets
built tonight that did not need to be.

---

## What the wizard is today (verified, do not re-derive)

Eight task codes, from `TenantSetupDto.ts`:

`ORG_PROFILE_CONFIRM` · `ORG_LOCALE` · `BRANDING` · `EMAIL_SENDER` · `PAYMENT_GATEWAY` ·
`INVITE_TEAM` · `WHATSAPP_SENDER` · `SMS_SENDER`

**Exactly one is required to finish: `ORG_LOCALE`.** Everything else is optional or skippable
(`skippedTaskCodes`). `ORG_LOCALE` is timezone + date format + time format + financial-year start +
default language — five MasterData ids, resolved to display *names* before being written.

One mutation, one transaction, all-or-nothing:
`SaveTenantSetupCommandHandler`
([SaveTenantSetup.cs](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/TenantSetup/Commands/SaveTenantSetupCommand/SaveTenantSetup.cs)).
It writes exactly nine `sett.OrganizationSettings` ParamCodes — `TIME_ZONE`, `DATE_FORMAT`,
`TIME_FORMAT`, `FINANCIAL_YEAR_START`, `DEFAULT_LANGUAGE`, `LOGO_URL`, `FAVICON_URL`,
`PRIMARY_COLOR_HEX`, `SECONDARY_COLOR_HEX` — and delegates email / gateway / WhatsApp / SMS / invites
to the same commands their own admin screens use.

**Not a gap — checked and cleared:** base currency. `ProvisionTenant.AlignRegionalSettingsToCountryAsync`
([ProvisionTenant.cs:1166](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/OpsBusiness/TenantProvisioning/Commands/ProvisionTenant.cs#L1166))
derives `DEFAULT_CURRENCY` / `ALLOWED_CURRENCIES` / `DEFAULT_COUNTRY` from `com.Countries.CurrencyId`
at step 6. Currency is set. It is just never *shown* — see G-2.

---

## The gaps, in priority order

### G-1 · The wizard's finish bar and the go-live bar are disjoint · **DEMO-BLOCKING**

`GoLiveChecklistBuilder`
([GoLiveChecklistBuilder.cs](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/GoLive/GoLiveChecklistBuilder.cs))
requires five things before a tenant can go live:

| Go-live item | Rule | Wizard requires it? |
|---|---|---|
| `BRANDING` | logo **and** primary colour | optional |
| `TEAM_INVITED` | `userCount > 1` | optional |
| `CHANNELS_CONFIGURED` | required when the plan entitles it | optional |
| `CONTACTS_IMPORTED` | required, skippable via `GOLIVE_CONTACTS_SKIPPED` | **not in the wizard at all** |
| `TEST_DONATION` | `GlobalDonations count > 0` | **not in the wizard at all** |

So the intended demo path — finish the wizard, land on the dashboard — produces a tenant that is
**0/5 or 1/5 on go-live**, with no forewarning anywhere in the wizard. On stage that reads as "the
product told me I was done and then told me I was not."

**Fix (smallest correct change, no schema):** on the wizard's completion step, render the go-live
checklist inline — same `GoLiveChecklistBuilder` output, no second source of truth — under a heading
that frames it honestly: *"Setup is done. Here is what is left before you can go live."* Each row
deep-links to the section that satisfies it. Do **not** promote go-live items into wizard-required
tasks; a tenant must be able to finish setup without importing contacts.

Additionally: make `BRANDING` **required to finish** (not skippable). It is the one go-live item the
wizard already collects, it takes fifteen seconds, and it is what makes the demo tenant look like a
real charity instead of the platform.

---

### G-2 · Regional card never shows the currency or country it is operating on · **DEMO-BLOCKING (cheap)**

`ORG_LOCALE` shows timezone / date / time / FY-start / language. The tenant's **base currency** and
**operating country** were decided by whoever filled in the ops provisioning wizard and are never
surfaced to the tenant again during onboarding.

This is not theoretical. `sql-scripts-dyanmic/fix-tenant-currency-from-country-backfill.sql` exists
because step 6 previously cloned `__TEMPLATE__`'s currency verbatim and every tenant came out with
the wrong one. The code path is fixed; the *blind spot* is not — a wrong `CountryId` at provisioning
still yields a silently wrong `DEFAULT_CURRENCY`, and the first symptom is a donation receipt in the
wrong currency.

**Fix:** add two **read-only** rows to the Regional settings card — *Base currency* (`DEFAULT_CURRENCY`,
with symbol) and *Country* (`DEFAULT_COUNTRY`) — each with a one-line note: *"Set from the country on
your account. Contact support to change it."* No new field on `TenantSetupLocaleDto`, no new ParamCode,
no migration. Read them through `IOrgSettingsService` in `GetTenantSetup`.

Do **not** make these editable in the wizard. Currency is not a preference — changing it after money
has moved is a data-migration problem, and the wizard is the wrong place to offer it.

---

### G-3 · No receipt identity step · **NOT demo-blocking — build after the demo**

`RECEIPT_NUMBER_PREFIX`, `NEXT_RECEIPT_NUMBER` and `RECEIPT_VALIDITY_DAYS` are real ParamCodes
([OrgSettingsValueValidator.cs:336-347](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/OrganizationSettings/Validators/OrgSettingsValueValidator.cs#L336-L347)),
and the receipt is the single most legally-loaded artefact a fundraising tenant emits. Onboarding
never asks about it, so the first receipt a new tenant issues carries platform defaults.

**Fix, when it is picked up:** a ninth task code `RECEIPT_IDENTITY`, optional, collecting receipt
number prefix + starting number, written through the same `ParamCatalog` upsert the locale section
uses. Validate server-side: prefix `^[A-Z0-9/-]{1,10}$`, starting number `>= 1`, and — this is the
part that matters — **reject a starting number lower than the highest receipt number already
issued for the tenant**, or the sequence collides.

Registration number and tax id already exist on `ORG_PROFILE_CONFIRM` and are optional. They print
on statutory receipts. Leave them optional (a tenant may genuinely not have one yet) but mark them
with a *"required before you issue receipts"* hint rather than treating them as ordinary fields.

---

### G-4 · Go-live demands a test donation; nothing in onboarding creates something to donate to · **NOT demo-blocking**

`TEST_DONATION` requires `GlobalDonations count > 0`. To record a donation a tenant needs at least
one donation purpose / fund, and provisioning seeds those only by cloning `__TEMPLATE__` — a clone
that step 5 **skips silently when the template company is absent**.

**Fix, when it is picked up:** make the go-live `TEST_DONATION` row state its own precondition — if
the tenant has no active donation purpose, the row's evidence label must say *"Create a donation
purpose first"* and link there, instead of pointing at a donation form the tenant cannot complete.
This is a label + link change in `GoLiveChecklistBuilder`, not a new wizard step.

---

### G-5 · Invited users are created with `UserTypeId = creatorUserTypeId ?? 0` · **NOT demo-blocking — but do not leave it**

In the invite delegation path, a new user whose creator has no resolvable user type is written with
`UserTypeId = 0`. Zero is not a user type; it is the same shape as the `CompanyId = 0` code paths
already logged as C-3 on the production cutover checklist.

**Fix:** resolve the tenant's default staff user type explicitly and fail the invite section with
`SETUP_SECTION_INVALID` if it cannot be resolved. A rejected invite is recoverable; a user row with
a meaningless type is not, and it will surface much later as an authorization anomaly.

---

## What to build tonight

**G-1 and G-2 only.** Both are frontend-plus-read-query changes with no migration, no new ParamCode
and no change to the `saveTenantSetup` contract:

1. Wizard completion step renders the live go-live checklist, honestly framed, with deep links.
2. `BRANDING` becomes required-to-finish (server-side too — add it to the finish guard in
   `SaveTenantSetup`, not just the UI, so the rule survives a direct mutation call).
3. Regional card gains two read-only rows: base currency and country, sourced from
   `IOrgSettingsService` via `GetTenantSetup`.

G-3, G-4 and G-5 are specified above and deliberately left for after the demo.

## Constraints for whoever builds this

- **Server-side validation is not optional.** If `BRANDING` becomes required, the finish guard in
  `SaveTenantSetup` enforces it. A UI-only rule is not a rule.
- **One source of truth for go-live.** Call `GoLiveChecklistBuilder`; do not re-implement its five
  rules in the wizard, or the two screens will disagree within a sprint.
- **`null` means "untouched", not "clear".** The existing `Blank()` idiom in the save handler must
  not be disturbed by the new read-only fields — they are display-only and must never round-trip
  into the request DTO.
- No EF migration is needed for tonight's scope. If you find yourself wanting one, you have gone
  past G-1/G-2 — stop and hand it back.
