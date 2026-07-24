# PSS 2.0 — Settings Screen Reconciliation: #75 Company Settings vs #85 Organization Settings

> **Type:** Analysis / decision doc (`/continue-screen #75 + #85`, first drafted 2026-07-22, **rewritten 2026-07-22** after the storage model was re-verified).
> **Status:** Partially executed. The **5 numbering ParamCodes** (§5) are already removed from the #85 seed. This rewrite replaces the original "typed columns win collisions" premise — which was **factually wrong** — with a **ParamCode ownership partition**. Seed changes are user-owned/user-applied.
>
> **ID note:** the two real screens are **#75 Company Settings** and **#85 Organization Settings**. #85 is one page serving 3 menus — **Setting Group / Organization Setting / User Setting** (all route to one `OrgSettingsPage`). Registry IDs **165/166 do not exist** (registry gaps); the "165/166" in the original request are those sub-menus of #85, not separate screens.

---

## 0. What changed in this rewrite (why the old doc was wrong)

The original doc assumed **#75 stores config in typed singleton tables** (`sett.CompanyConfigurations`, `sett.CompanyBrandings`, typed FK columns like `BaseCurrencyId`, `TwoFactorAuthModeId`, `PasswordMinLengthId`), and therefore "#75 always wins a collision because it has the typed home."

**Those tables and columns no longer exist.** They were dropped and folded into the generic KV store:

- `20260519151055_Remove_CompanyBranding`
- `20260526140142_Remove_CompanyConfiguration`

(The file `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/CompanyConfiguration.cs` that still exists is the EF fluent config **for the `Company` entity** — `IEntityTypeConfiguration<Company>` — not the dropped table.)

**Verified today — where #75 actually reads/writes:**

| #75 section | Real backing store |
|---|---|
| §1 Org Profile, §2 Contact | `app.Companies` (typed columns) — **unique to #75, no #85 twin** |
| §3 Branding, §4 Financial, §5 Regional, §6 Communication, §7 System/Security, §8 Receipt | `sett.OrganizationSettings` **KV, keyed by `(CompanyId, ParamCode)`** — the *same rows #85 edits* |
| §9 Number Sequences | `sett.NumberSequenceEntityTypes` + `sett.NumberSequenceConfigs` — **unique to #75, own engine** |

`GetCompanySettings` reads `app.Companies` + resolves each KV ParamCode via `IOrgSettingsService`; `UpdateCompanySettings` writes `app.Companies` + upserts the same `sett.OrganizationSettings` rows by ParamCode.

**So the real problem is not typed-vs-KV.** It is that **#75 and #85 are two editors pointing at one KV store** — a last-writer-wins data hazard on 6 of #75's 8 config sections. The fix is not "delete from #85 because #75 has a typed twin" (there are no twins). The fix is a **clean ownership partition**: every ParamCode is *edited by exactly one screen*.

---

## 1. The partition rule

Both screens share `sett.OrganizationSettings`. We do **not** duplicate the store; we split **which screen owns the editor UI** for each ParamCode, by nature of the setting:

| Owner | Mental model | Nature |
|---|---|---|
| **#75 Company Settings** | *"Who is the org, how does it look, how are its numbers wired?"* | Identity · appearance · structural/mechanical config |
| **#85 Organization Settings** | *"How does the org want to behave?"* | Behavioural policy toggles |
| **UserSettings** (3rd menu of #85) | *"How do I, this user, want my UI?"* | Per-user preference (`sett.UserSettings`, keyed by UserId) |
| **REMOVE from KV** | Lives in a dedicated expandable screen + its own table | Shadow of an entity managed elsewhere |

A ParamCode appears in **one and only one** screen's editor after this. The KV row is written by that screen; other screens may *read* the resolved value but never expose an editor for it.

---

## 2. Ownership map — #75 Company Settings (editor owner)

Identity, appearance, and mechanical wiring:

- **§1 Org Profile** — `app.Companies` typed cols (CompanyName, Code, ShortName, OrganizationTypeId, RegistrationNumber, TaxId, FCRA, DateOfIncorporation, Website, Description). *Unique — never in #85.*
- **§2 Contact** — `app.Companies` (Address, City, State, CountryId, PostalCode, PrimaryPhone, PrimaryEmail, Fax). *Unique — never in #85.*
- **§3 Branding** (SettingGroup **Branding**) — LOGO_URL, FAVICON_URL, PRIMARY_COLOR, SECONDARY_COLOR (+ forward-compat login/social cosmetic keys).
- **§Login / appearance** (SettingGroup **Login**) — login-page cosmetics.
- **§Organization identity** (SettingGroup **Organization**) — `FINANCIAL_YEAR_START`, `DEFAULT_LANGUAGE`, `TIME_ZONE`, `DATE_FORMAT`, `MULTI_BRANCH_MODE`, `AUDIT_TRAIL_RETENTION`. These are structural identity/formatting facts the whole runtime formats against.
- **§Regional identity part** (SettingGroup **Regional**) — `DEFAULT_COUNTRY`, `DATA_RESIDENCY`.
- **Base currency** — `DEFAULT_CURRENCY` (the org's single base/reporting currency = identity singleton). *NB: this is the org's base-currency selection, distinct from #79 Currency Management, which owns the currency **catalog + FX rates**. No overlap.*
- **§9 Number Sequences** — `sett.NumberSequence*` engine (prefix/pattern/reset/live counter per entity). *Unique — never in #85.*

---

## 3. Ownership map — #85 Organization Settings (editor owner)

Pure behavioural policy the runtime reads by ParamCode string:

- **Fundraising** (SettingGroup **Fundraising**) — MIN_DONATION_AMOUNT, MAX_DONATION_AMOUNT, AUTO_GENERATE_RECEIPT, RECEIPT_DELIVERY_DEFAULT, REQUIRE_PURPOSE, ALLOW_ANONYMOUS_DONATIONS, DUPLICATE_CHECK_WINDOW, DUPLICATE_CHECK_FIELDS, ONLINE_DONATION_CONFIRMATION, PLEDGE_REMINDER_DAYS, RECURRING_RETRY_ATTEMPTS, RECURRING_RETRY_INTERVAL, **ALLOW_MULTI_CURRENCY** *(multi-currency **enable** is a policy toggle → #85; the base-currency **value** → #75)*. *(minus `DEFAULT_CURRENCY` → #75, `DEFAULT_PURPOSE` → removed.)*
- **Communication** (SettingGroup **Communication**) — EMAIL_DAILY_LIMIT, SMS_DAILY_LIMIT, WHATSAPP_DAILY_LIMIT, QUIET_HOURS_START, QUIET_HOURS_END, UNSUBSCRIBE_LINK_REQUIRED, AUTO_ARCHIVE_CAMPAIGNS, BOUNCE_HANDLING, DEFAULT_REPLY_TO. *(These are flat policy knobs — #75 sheds its §6 Communication section.)*
- **Contacts** (SettingGroup **Contacts**) — AUTO_MERGE_DUPLICATES, REQUIRE_EMAIL_OR_PHONE, INACTIVE_AFTER_DAYS, ALLOW_CONTACT_DELETE, GDPR_DATA_RETENTION. *(minus `DEFAULT_CONTACT_TYPE` → removed, and the already-removed `CONTACT_CODE_FORMAT` → #75 §9.)*
- **Field** (SettingGroup **Field**) — OFFLINE_MODE, GPS_TRACKING, MAX_SYNC_INTERVAL, PHOTO_REQUIRED, DAILY_COLLECTION_LIMIT.
- **Reports** (SettingGroup **Reports**) — DEFAULT_EXPORT_FORMAT, MAX_REPORT_ROWS, SCHEDULE_REPORT_EMAIL, REPORT_CACHE_DURATION.
- **Security** (SettingGroup **Security**) — IP_WHITELISTING, DATA_ENCRYPTION_AT_REST, MASK_PII_IN_LOGS, **TWO_FACTOR_AUTH, PASSWORD_MIN_LENGTH, PASSWORD_EXPIRY_DAYS, SESSION_TIMEOUT, MAX_LOGIN_ATTEMPTS**. *(All security is flat policy → #85; #75 sheds its §7 Security section. There are no typed FK columns for these anymore.)*
- **Notifications** (SettingGroup **Notifications**) — org-wide defaults: IN_APP_NOTIFICATIONS, EMAIL_NOTIFICATIONS, DAILY_DIGEST, DIGEST_SEND_TIME, NOTIFICATION_RETENTION. *(Per-user overrides → UserSettings, §4.)*
- **Regional / Compliance part** (SettingGroup **Regional**) — GDPR_COMPLIANCE, CONSENT_REQUIRED, RIGHT_TO_ERASURE, COOKIE_CONSENT_BANNER. *(The identity part — DEFAULT_COUNTRY, DATA_RESIDENCY — → #75.)*

---

## 4. Ownership map — UserSettings (3rd menu of #85, `sett.UserSettings`)

Per-user preference, never org-wide:

- **Theme** (SettingGroup **ThemeCustomizer**, grp 1) — the whole group is a per-user UI preference; move it off org-level editing into UserSettings.
- **Personal notification prefs** — the per-user subset of the Notifications group (a user opting their own digest/in-app channels on/off), distinct from the org-wide defaults #85 owns in §3.

---

## 5. REMOVE from the KV store entirely (dedicated screens own these)

These ParamCodes are **shadows of entities managed in their own expandable screens+tables**. They should not be edited (or seeded) in the generic settings store at all.

### 5A. Already executed (2026-07-22) — 5 numbering codes → #75 §9 engine ✅
Removed from `setting-groups.sql` (10 INSERT rows across CompanyId NULL + 3, plus an idempotent cleanup `DELETE`) and from `orgsettings.md` (RECEIPTS 10→6, CONTACTS 7→6). Seed-only, `CanUserOverride`=false — no `UserSettings` cascade.

| ParamCode | Real owner |
|---|---|
| RECEIPT_NUMBER_PREFIX / RECEIPT_NUMBER_FORMAT / NEXT_RECEIPT_NUMBER / FINANCIAL_YEAR_RESET | `NumberSequence*` — `GLOBALDONATION` entity |
| CONTACT_CODE_FORMAT | `NumberSequence*` — `CONTACT` entity |

### 5B. Approved this pass — pending seed apply (extend the cleanup `DELETE`)

| ParamCode(s) | Real owner (dedicated screen) | ⚠ Prerequisite before apply |
|---|---|---|
| TAX_EXEMPT_ORG, TAX_SECTION, SHOW_TAX_INFO_ON_RECEIPT, RECEIPT_VALIDITY_DAYS, REQUIRE_RECEIPT_SIGNATURE, AUTHORIZED_SIGNATORY | **#9 Receipt & Tax Management** (`fund.CountryTaxConfig` / `fund.ReceiptTemplate`). Also retires **#75 §8 Receipt**. | Confirm #9's config tables actually capture all 6 semantics (esp. AUTHORIZED_SIGNATORY, RECEIPT_VALIDITY_DAYS) before removing — else these lose their interim home. |
| DEFAULT_PURPOSE | **#2 Donation Purpose** — model as an `IsDefault` flag on the purpose entity | Confirm #2 exposes an `IsDefault` (else donation-create loses its pre-select until it does). |
| DEFAULT_CONTACT_TYPE | **#19 Contact Type** — model as an `IsDefault` flag on the contact-type entity | Confirm #19 exposes an `IsDefault`. |

> **`ALLOWED_CURRENCIES` is NOT in this list** — it was in the earlier draft but **does not exist** in the seed (0 rows). Dropped from scope.
>
> **Refinement vs the earlier "remove all currency" call:** `DEFAULT_CURRENCY` and `ALLOW_MULTI_CURRENCY` are **not** removed. Base-currency selection is org identity (→ #75); multi-currency enable is a policy toggle (→ #85). Neither duplicates #79 Currency Management, which owns the currency **catalog + FX rates** (a different concern). This is the "decide based on application structure" refinement.

---

## 6. Net effect

- **#75** sheds its §4-Financial-currency-policy, **§6 Communication**, **§7 Security**, and **§8 Receipt** editor sections; keeps identity (§1/§2), branding, organization/regional identity, base currency, and the §9 number-sequence engine.
- **#85** becomes the single editor for all behavioural policy (fundraising, communication, contacts, field, reports, security, notifications, compliance).
- **UserSettings** gains theme + personal notification prefs.
- The KV store loses the 5 (done) + up to 8 (5B) entity-shadow codes.
- **Result:** no ParamCode is editable in two places → the last-writer-wins hazard is closed.

---

## 7. Execution status & path

**✅ Done (2026-07-22):** 5 numbering codes (§5A) — seed + `orgsettings.md` + #75 §⑫ note.

**✅ Done in this pass (docs + seed-prep):**
- This doc rewritten to the ownership-partition model.
- `companysettings.md` §⑫ note corrected (typed tables gone; #75 shares KV; only Number Sequences is truly #75-exclusive).
- `setting-groups.sql` — the §5B codes appended to the idempotent cleanup `DELETE` (INSERT rows kept in place → trivially reversible if a prerequisite in §5B fails). **User-applied.**

**⏳ Follow-up — separate `/continue-screen` passes (each changes a screen's spec §⑥, out of scope for a fix pass):**
1. **#75** — drop the §6 Communication, §7 Security, §8 Receipt, and Financial-currency-policy editor sections from spec + FE/BE.
2. **#85** — drop the Branding / Login / Organization / Regional-identity groups from its editor; move ThemeCustomizer + personal notification prefs to the UserSettings menu.
3. **#9 / #2 / #19** — confirm/attach the absorbing fields (§5B prerequisites) before the §5B `DELETE` is actually run.

**Constraint reminders:** migrations & seeds are user-owned (I write, user applies). No entity/column change is implied by this doc — it is a UI-ownership + KV-seed partition only.
