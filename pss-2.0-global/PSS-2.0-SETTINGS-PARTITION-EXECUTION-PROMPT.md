# Settings partition — execution pass (#75 / #85 / UserSettings)

**Blueprint:** `PSS-2.0-SETTINGS-SCREEN-RECONCILIATION.md` — read it **first and in full** (139 lines).
This prompt executes its §7 follow-up list. The decisions are already made there; do not re-litigate them.

**Scope:** BE + FE editor sections. No entity or column change. Seed edits written, not applied.

---

## Rules

| Rule | Detail |
|---|---|
| **No `dotnet build`** | User builds. Compile by inspection. |
| **No migration** | Not `dotnet ef migrations add`, not by hand. This pass implies **no schema change** — if you reach for one, you've misread §7's closing line. |
| **Seed SQL: write, never run** | `sql-scripts-dyanmic/`. User applies. |
| **Verify property names** | Read the entity/resolver first. Audit cols are `CreatedDate`/`ModifiedDate`. |
| **UTC only** | `timestamp with time zone` everywhere; `DateTime.UtcNow`, never `DateTime.Today` in an EF predicate. |
| **HotChocolate** | `Get` stripped from resolvers, `Input` appended to input types. Wrong name compiles clean, fails at runtime. |
| **Backend is gitignored** | Grep/Glob return zero `.cs` hits. Use `find -iname`, or scope `grep -rn --include=*.cs` to **one** project dir (repo-wide times out). Absolute-path `Read` works. |
| **Registry** | `grep` `REGISTRY.md`, never `Read` it (~700KB). |

---

## The one idea

`sett.OrganizationSettings` is a single KV store keyed `(CompanyId, ParamCode)`. #75 and #85 are
**two editors pointing at it** — last-writer-wins on 6 of #75's 8 sections. The fix is an
**ownership partition**: every ParamCode gets exactly one editor. Nothing is duplicated, nothing is
moved between tables. Other screens may still *read* a resolved value; they just don't expose an
editor for it.

Owner split (full ParamCode lists in blueprint §2/§3/§4):
- **#75** = identity · appearance · mechanics (org profile, contact, branding, login, org/regional identity, base currency, number-sequence engine)
- **#85** = behavioural policy (fundraising, communication, contacts, field, reports, security, notifications, compliance)
- **UserSettings** (3rd menu of #85) = per-user preference (theme, personal notification prefs)

---

## Steps — do 0 first, it gates the rest

### 0. Verify the §5B prerequisites (#9, #2, #19)

Blueprint §5B queues 8 ParamCodes for deletion from the KV store, each conditional on the absorbing
screen actually capturing the semantic. **Confirm in code, don't assume:**

| Codes | Must exist before deletion is safe |
|---|---|
| TAX_EXEMPT_ORG, TAX_SECTION, SHOW_TAX_INFO_ON_RECEIPT, RECEIPT_VALIDITY_DAYS, REQUIRE_RECEIPT_SIGNATURE, AUTHORIZED_SIGNATORY | **#9 Receipt & Tax** — `fund.CountryTaxConfig` / `fund.ReceiptTemplate` cover all six, **especially AUTHORIZED_SIGNATORY and RECEIPT_VALIDITY_DAYS** |
| DEFAULT_PURPOSE | **#2 Donation Purpose** exposes an `IsDefault` flag |
| DEFAULT_CONTACT_TYPE | **#19 Contact Type** exposes an `IsDefault` flag |

Report each as **confirmed / missing** in §Findings. A missing one means that code **stays** in the
KV store for now — say so plainly rather than deleting it and leaving the semantic homeless. Do not
build the absorbing field yourself; that's a separate screen pass.

### 1. #75 Company Settings — shed four editor sections

Remove from spec §⑥ + FE + BE: **§6 Communication**, **§7 Security**, **§8 Receipt**, and the
**currency-policy part of §4 Financial**.

Keep: §1 Org Profile, §2 Contact (both `app.Companies` typed columns), Branding, Login,
Organization/Regional **identity** codes, `DEFAULT_CURRENCY` (base-currency selection is identity),
and §9 Number Sequences.

Note the split that's easy to get backwards: `DEFAULT_CURRENCY` stays on **#75**;
`ALLOW_MULTI_CURRENCY` goes to **#85**. Value vs toggle.

### 2. #85 Organization Settings — shed the identity groups, split UserSettings

Remove from its editor: **Branding**, **Login**, **Organization**, and the Regional **identity**
codes (`DEFAULT_COUNTRY`, `DATA_RESIDENCY`) — all now #75's. Regional **compliance** codes
(GDPR_COMPLIANCE, CONSENT_REQUIRED, RIGHT_TO_ERASURE, COOKIE_CONSENT_BANNER) **stay** on #85.

Move to the **UserSettings** menu (`sett.UserSettings`, keyed by UserId): the whole
**ThemeCustomizer** group, plus the per-user subset of Notifications. The org-wide notification
defaults stay on #85 — same group name, two scopes; don't collapse them.

Remember #85 is **one page serving three menus** (Setting Group / Organization Setting / User
Setting) all routing to `OrgSettingsPage`. Registry IDs 165/166 do not exist.

### 3. Seed

`setting-groups.sql` already has the §5B codes appended to its idempotent cleanup `DELETE`, with the
INSERT rows deliberately left in place so it's reversible. Adjust that `DELETE` to match whatever
step 0 actually confirmed, and leave it for the user to apply.

---

## Invariants

1. No ParamCode is editable on two screens when this is done. That is the whole point.
2. No entity, column, or migration change. If one seems necessary, stop and write it into §Findings.
3. A code removed from an editor is **not** removed from the KV store unless §5B cleared it in step 0.
4. Reading a resolved value elsewhere is fine and unaffected — this partitions *editors*, not *reads*.

---

## Not in scope

Building the absorbing fields on #9 / #2 / #19; any change to #79 Currency Management (it owns the
currency catalog + FX rates — a different concern, no overlap); the number-sequence engine itself.

---

## Findings

*Executed 2026-08-03. All three steps complete. `npx tsc --noEmit --incremental false` → exit 0.
Backend compiled by inspection (no `dotnet build`), no migration, no entity or column change, seed
edits written but not applied.*

### Step 0 — §5B prerequisite verdicts

Verified by reading the destination entity/handler in each case, not by grepping for the ParamCode.

| ParamCode | Destination | Verdict | Evidence |
|---|---|---|---|
| `TAX_EXEMPT_ORG` | #9 | **MISSING** | no boolean on `CountryTaxConfig` or `ReceiptTemplate` |
| `TAX_SECTION` | #9 | **MISSING** | only adjacent `TaxCodeType` / `TaxCodeKey`; still read live at `DonationReceiptService.cs:105` |
| `SHOW_TAX_INFO_ON_RECEIPT` | #9 | **MISSING** | no field; read live at `DonationReceiptService.cs:104` |
| `RECEIPT_VALIDITY_DAYS` | #9 | **MISSING** | no column; still referenced by a const in `OrgSettingsValueValidator.cs:168` |
| `REQUIRE_RECEIPT_SIGNATURE` | #9 | **MISSING** | no field on `ReceiptTemplate` |
| `AUTHORIZED_SIGNATORY` | #9 | **MISSING** | no field; read live at `DonationReceiptService.cs:111` |
| `DEFAULT_PURPOSE` | #2 | **MISSING** | `DonationPurpose` has no `IsDefault` |
| `DEFAULT_CONTACT_TYPE` | #19 | **MISSING** | `ContactType` has `IsSystem`, no `IsDefault` |

**0 of 8 confirmed.** Per invariant 3 all eight **stay** in the KV store, so step 3's cleanup `DELETE`
is a no-op: the block in `setting-groups.sql` is now commented out with the per-code verdicts inline,
re-enableable one line at a time once the destination fields exist. Three of the eight are read at
runtime today — deleting them would have broken receipt rendering, not merely orphaned a row.

### Deviations

1. **Partition granularity is ParamCode, not SettingGroup.** §7 reads as "drop the Branding / Login /
   Organization groups from #85", but #75 writes only 4 of BRANDING's 12 codes and 0 of LOGIN's 3.
   Dropping whole groups would have left 11 codes with no editor anywhere. The partition is therefore
   an explicit allow-list in `SettingsOwnership.cs` — 17 company-owned ParamCodes, one user-scoped
   group, four user-overridable codes. `CanUserOverride` could not serve as the selector: it is `true`
   on every BRANDING and LOGIN row.
2. **`OPERATING_COUNTRIES` and `DEFAULT_CURRENCY` added to #75's owned list.** Not named in §7's
   removal list, but #75's `ParamCatalog` writes both — without adding them they would have stayed
   dual-editable, which is exactly what invariant 1 forbids.
3. **`DATA_RESIDENCY` stays on #85.** §7 assigns it to #75, but #75's `ParamCatalog` never writes it.
   Moving it would orphan it. Kept on #85 until #75 grows a field for it.
4. **`NOTIFICATION_RETENTION` excluded from the user-overridable set.** It is a data-retention policy,
   not a personal preference; the other four notification codes moved as specified.
5. **Neither #75 nor the seed defines `ALLOWED_CURRENCIES`, but `OrgSettingsDefaultSeeder.cs:208`
   does.** The blueprint states 0 rows exist. Left alone — a seeder change is a data change, not an
   editor change.

### Read-sites checked

No read-site breaks. The partition changes which screen *edits* a code, never where it is stored or
resolved from, so every `IOrgSettingsService` consumer is unaffected — including
`GetTenantLoginConfigQuery`, which reads the LOGIN codes and has no editor of its own on either
screen. `THEMECUSTOMIZER` already had a working per-user writer (the app-layout ThemeCustomize drawer
via `useUpsertUserSetting`); the new UserSettings menu is a second surface over the same rows, not a
replacement, and both write `sett.UserSettings` keyed by `(UserId, ParamCode)`.

### Fixed in passing

**`ResetOrganizationSettingsToDefaults` was a partition leak.** "Reset to defaults" reset *every* row,
including the ones #75 now owns — the last-writer-wins hazard by another route. A reset is an edit, so
it now obeys the same `SettingsOwnership` exclusion as the editor.

### Found, not fixed (out of scope)

**`ResetOrganizationSettingsToDefaultsHandler` has no `CompanyId` filter at all.** It filters on
`IsDeleted` and (now) ownership, but never on tenant — so one tenant pressing "Reset to defaults"
resets every tenant's rows. Pre-existing, unrelated to the partition, and a behaviour change beyond
this pass's remit. Logged as ISSUE-01 in `.claude/screen-tracker/prompts/orgsettings.md` § Known
Issues. Fix is one predicate: `s.CompanyId == httpContextAccessor.GetCurrentUserStaffCompanyId()`,
matching every other #85 handler.

### Files touched

**BE new** — `SettingBusiness/OrganizationSettings/SettingsOwnership.cs`,
`SettingBusiness/UserSettings/Queries/GetUserSettingsView.cs`,
`SettingBusiness/UserSettings/Commands/BulkUpdateUserSettings.cs`.
**BE edited** — `GetOrganizationSettingsView.cs`, `ResetOrganizationSettingsToDefaults.cs`,
`Schemas/SettingSchemas/UserSettingSchemas.cs`, `EndPoints/Setting/Queries/UserSettingQueries.cs`,
`EndPoints/Setting/Mutations/UserSettingMutations.cs`, plus #75's step-1 edits.
**FE** — `UserSettingsViewQuery.ts` + `BulkUpdateUserSettingsMutation.ts` (new), `OrgSettingsDto.ts`,
`orgsettings-page.tsx` (`scope` prop), `pages/setting/orgsettings/orgsettings.tsx`
(`UserSettingsPageConfig`), `app/[lang]/(core)/setting/orgsettings/usersetting/page.tsx`, plus #75's
step-1 edits.
**Seed (written, NOT applied)** — `setting-groups.sql`, cleanup-2 block disabled with verdicts.
**Specs** — `.claude/screen-tracker/prompts/orgsettings.md` (§⑥, §⑩, § Known Issues, Session 3),
`companysettings.md` (step 1).
