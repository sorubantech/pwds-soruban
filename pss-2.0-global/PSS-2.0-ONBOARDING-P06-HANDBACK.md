# PSS 2.0 — Onboarding P-06 (Go-Live) — Hand-back Note

**Prompt executed:** `PSS-2.0-ONBOARDING-PROMPT-06-GOLIVE.md`
**Date:** 2026-07-27
**Scope delivered:** T-C1 (O-04 Go-Live Checklist screen) + T-C2 (`CompleteGoLiveCommand`)

---

## 1. Build status

| Check | Result |
|---|---|
| `dotnet build` (backend solution) | ✅ **0 Errors**, 652 warnings (all pre-existing, in unrelated files), real **EXIT=0** |
| `npx tsc --noEmit --incremental false` (frontend) | ✅ **EXIT=0**, zero diagnostics |

No warnings were introduced by any new file.

---

## 2. Schema: did `OnboardedOn` / `IsInternal` already exist?

**Yes — both already existed.** `Base.Domain/Models/ApplicationModels/Company.cs` already carries the
P-01 T-A2 onboarding block:

```csharp
public string? Status { get; set; }        // PROVISIONING | ACTIVE | SUSPENDED | CHURNED
public bool IsInternal { get; set; }
public DateTime? OnboardedOn { get; set; } // UTC
public int? SourceLeadId { get; set; }
```

⇒ **Zero schema change for P-06. No migration and no migration spec is required.**
No new tables were created. The only persisted checklist state is a `sett.OrganizationSettings`
KV row (below). `IsInternal` is never read or written by P-06.

---

## 3. Checklist items and exactly how each is derived

All derivation lives in **one** place — `GoLiveChecklistBuilder.BuildAsync(...)` — which is used by
**both** the read query and the flip command, so the two can never disagree.

| # | ItemCode | Satisfied when | Source | Required? |
|---|---|---|---|---|
| 1 | `BRANDING` | tenant has non-blank `CurrentValue` for **both** `LOGO_URL` and `PRIMARY_COLOR_HEX` | `sett.OrganizationSettings` rows **owned by this CompanyId** | required |
| 2 | `TEAM_INVITED` | `COUNT(users for this company, not deleted) > 1` | `auth.Users` | required |
| 3 | `CHANNELS_CONFIGURED` | every entitled channel is configured — gateway ⇒ `CompanyPaymentGateways.Any(...)`, email ⇒ `CompanyEmailProviders.Any(...)` | `fund.CompanyPaymentGateways`, `notify.CompanyEmailProviders` | **plan-conditional** (see §4) |
| 4 | `CONTACTS_IMPORTED` | `COUNT(contacts) > 0` **OR** `GOLIVE_CONTACTS_SKIPPED = true` | `crm.Contacts` + `sett.OrganizationSettings` | required-unless-skipped |
| 5 | `TEST_DONATION` | `COUNT(donations) > 0` | `GlobalDonations` | required |

Notes on derivation choices:

- **Branding reads the tenant's own setting rows directly, NOT `IOrgSettingsService`.** The service
  resolves UserSetting → CurrentValue → **ParamDefaultValue** → fallback, so a platform default
  would make branding look satisfied for a tenant that has uploaded nothing. Reading the tenant's
  own row is the only correct evidence.
- The skip flag parse is tolerant (`true` / `1` / `y` / `yes`, case-insensitive).
- No `IgnoreQueryFilters()` anywhere — this runs in ordinary tenant context throughout.

### The skip flag

`GOLIVE_CONTACTS_SKIPPED` — a `sett.OrganizationSettings` ParamCode row
(`ParamDataType = "Boolean"`, `ParamDefaultValue = "false"`, `CanUserOverride = false`), written by
`SkipGoLiveItemCommand` and only ever for `CONTACTS_IMPORTED` (any other itemCode is rejected).
`SettingGroupId` is resolved **at write time by `SettingGroupCode == "ORGANIZATION"`** — no PK is
hard-coded; if that group is missing the command fails loudly rather than writing a bad FK. After
the write the cache is invalidated via `IOrgSettingsService.InvalidateCompany(companyId)` and the
checklist is rebuilt and returned in the same round trip.

**No seed script is required** — the row is created on first use by the upsert.

---

## 4. Plan-conditional behaviour

`CHANNELS_CONFIGURED` is the only conditional item. Relevance is resolved through
`IEntitlementService.HasFeatureAsync(companyId, featureCode, ct)`:

- gateway relevance ⇐ `MODULE:DONATION`
- email relevance ⇐ `CHANNEL:EMAIL`

If **neither** feature is entitled the item is **omitted from `Items` entirely** and does not count
toward `RequiredCount` — exactly as the brief specifies. If either is entitled, the item appears,
is required, and is flagged `IsPlanConditional = true` so the UI can label it "Your plan".

> ⚠️ **Deviation worth PM attention:** the plan catalog has **no payment-gateway feature code**.
> There is nothing like `CHANNEL:GATEWAY` / `MODULE:PAYMENTS` to key off, so gateway relevance is
> inferred from `MODULE:DONATION` (a tenant entitled to take donations needs a gateway). If a
> dedicated gateway feature code is added later, change the one constant `FEATURE_DONATION` in
> `GoLiveChecklistBuilder`.

---

## 5. The flip — idempotent and server-re-derived

`CompleteGoLiveCommand(actingUserId)` order of operations:

1. Load the tenant's own `Company` row (tenant context, **no** `IgnoreQueryFilters`).
2. **Already `ACTIVE` ⇒ success no-op**: returns `Flipped = false` and **does not re-stamp
   `OnboardedOn`**. Fully idempotent.
3. `SUSPENDED` or `CHURNED` ⇒ `BadRequestException` with a clear message. A suspended tenant is
   **never** flipped live.
4. **Re-derives the entire checklist server-side** via `GoLiveChecklistBuilder`. If any required
   item is unmet it throws
   `"Cannot go live — the following required steps are not complete: <titles>"`.
   Client state is never trusted.
5. Sets `Status = "ACTIVE"`, `OnboardedOn = DateTime.UtcNow` (Kind = Utc), plus
   `ModifiedDate`/`ModifiedBy`.
6. `SaveChangesAsync`, then audits.

`IsInternal` is never touched. No email is sent, no external event is emitted.

**Audit:** `IAuditLogWriter.WriteWorkflowEvent(actingUserId, "Company", companyId, "GO_LIVE", ...)`.
There is no `ops.PlatformAuditEvent` entity in the codebase, so the existing workflow-event audit
writer is used — the transition string is `GO_LIVE` as specified.

---

## 6. Surface & gating — confirmed tenant `(core)`, BUSINESSADMIN

- Route: **`/{lang}/setting/orgsettings/golive`** under the **`(core)`** route group (not `(master)`).
- Server gate on all three operations: `[CustomAuthorize(DecoratorSettingModules.CompanySettings, …)]`
  → module `COMPANYSETTINGS`, `Permissions.Read` for the query, `Permissions.Modify` for both
  mutations. **No `PLATFORM_*` capability is used anywhere.**
- Client gate: `useAccessCapability({ menuCode: "COMPANYSETTINGS" })` → `LayoutLoader` /
  `DefaultAccessDenied` / page.
- **No new capability seed is needed** — P-06 reuses the existing `COMPANYSETTINGS` module on both
  sides. (Add a menu entry pointing at the route if you want it in the nav; the page works standalone.)

---

## 7. Names that differed from the brief

| Brief said | Actually built | Why |
|---|---|---|
| query `GetGoLiveChecklist` | handler `GetGoLiveChecklistQuery`; **GraphQL field is `goLiveChecklist`** | HotChocolate strips the `Get` prefix — this is the field the FE queries |
| (skip control unspecified) | extra mutation **`skipGoLiveChecklistItem(itemCode, skipped)`** | the Skip control needs a server round trip that both writes the KV flag and returns the re-derived checklist; a raw settings write would have left the FE computing state |
| "branding settings populated" | ParamCodes **`LOGO_URL`** + **`PRIMARY_COLOR_HEX`**, read from tenant-owned rows | actual ParamCodes; service-resolved read would false-positive on platform defaults |
| "payment gateway / email configured" | one item **`CHANNELS_CONFIGURED`**, gateway ⇐ `fund.CompanyPaymentGateways`, email ⇐ `notify.CompanyEmailProviders` | email evidence is **not** `CompanyEmailConfigurations` (that table is header/footer text only) |
| plan check for gateway | keyed off **`MODULE:DONATION`** (+ `CHANNEL:EMAIL` for email) | no gateway feature code exists in the catalog — see §4 |
| audit `GO_LIVE` | `IAuditLogWriter.WriteWorkflowEvent(..., "Company", id, "GO_LIVE", ...)` | no `ops.PlatformAuditEvent` entity exists |

---

## 8. Files

**Backend (all new):**
- `Base.Application/Schemas/SettingSchemas/GoLiveChecklistSchemas.cs`
- `Base.Application/Business/SettingBusiness/GoLive/GoLiveChecklistBuilder.cs`
- `…/GoLive/Queries/GetGoLiveChecklistQuery/GetGoLiveChecklist.cs`
- `…/GoLive/Commands/SkipGoLiveItemCommand/SkipGoLiveItem.cs`
- `…/GoLive/Commands/CompleteGoLiveCommand/CompleteGoLive.cs`
- `Base.API/EndPoints/Setting/Queries/GoLiveQueries.cs`
- `Base.API/EndPoints/Setting/Mutations/GoLiveMutations.cs` (acting user from the `UserId` claim)

**Frontend (new unless noted):**
- `domain/entities/setting-service/GoLiveChecklistDto.ts` (+ barrel edit)
- `infrastructure/gql-queries/setting-queries/GoLiveChecklistQuery.ts`
- `infrastructure/gql-mutations/setting-mutations/GoLiveMutation.ts`
- `presentation/components/page-components/setting/orgsettings/golive/golive-checklist-page.tsx` (+ `index.ts`, + barrel edit)
- `presentation/pages/setting/orgsettings/golive.tsx` (+ barrel edit)
- `app/[lang]/(core)/setting/orgsettings/golive/page.tsx`

UI honours the standing rules: design tokens only (no hex/px), `@iconify` Phosphor icons, solid
`bg-X-600 + text-white` chips and icon containers, shaped skeletons, and explicit
loading / error / empty / **already-live** states. The Go Live button is hidden and replaced by a
"Live since …" chip once the tenant is `ACTIVE`.

---

## 9. Loop closed

**WON lead → provisioned tenant → live tenant.** P-05's wizard produces a `WON` lead, P-03/P-04
provision the tenant to `Status = PROVISIONING`, and P-06 is the customer-driven final hop to
`Status = ACTIVE` with `OnboardedOn` stamped. The onboarding chain is now end-to-end.

**Out of scope and not built (as instructed):** impersonation/support view, the T-05 dashboard
widget, suspend/offboard/reactivate, activation-metrics dashboards, self-service (Option A)
onboarding.
