# TENANT-COMMS-UI-FIX — Email / SMS / WhatsApp Configuration Screens: UI & Form-Field Correctness

**Status:** NOT BUILT.
**Surface:** FE-only for Phase 1 (3 screens, ~14 component files) · BE for Phase 2 (1 new column on `notify.SmsSettings`, 1 DTO/handler change, **migration required**) · Phase 3 gated on an unanswered business question.
**Screens:** REGISTRY **#28** `EMAILPROVIDERCONFIG` · **#157** `SMSSETUP` · **#34** `WHATSAPPSETUP` — all three COMPLETED, this is a fix pass, so use `/continue-screen`, never `/plan-screens`.
**Depends on:** nothing. Phase 1 can start immediately.
**Companion doc:** `PSS-2.0-COMMUNICATION-PROVIDERS-CONFIGURATION-PLAN.md` (structural/architecture findings E1-E3, S1-S4, W1-W4). **This prompt is the UI and form-field layer only — it does not re-open the storage-philosophy or metering questions in that document.**
**Trigger:** *"tenant level we have three menus whatsapp,email,sms. we need to test that screen proper for global perspective"* → *"ok but ui and form fields need to check buddy - everything valid or not"*
**Audit date:** 2026-08-05. Every finding below was read from the component source, not inferred.

---

## ⚠️ Rules

1. **Migrations are user-owned.** Do not run `dotnet ef migrations add` / `database update` / `remove`. Do not hand-author a migration or snapshot file. Write the entity change, prove it compiles, then hand over the migration spec in §⑩.
2. **Do not run `dotnet build`.** The user builds the backend.
3. Frontend typecheck is `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` with **no pipe**. Only exit code 0 counts as clean. A run that reports only a pre-existing TS2688 config error checked **zero files** and is not a pass.
4. `PSS_2.0_Backend/` and `PSS_2.0_Frontend/` are gitignored → the Grep/Glob tools return **zero** matches inside them. Use `find -iname` to locate, or scope `grep -rn --include=*.cs` to **one** project subdirectory (a repo-wide backend grep times out at 120s). Absolute-path `Read` works fine.
5. DB is UTC-only. Every Postgres date column is `timestamp with time zone`; Npgsql throws on `Kind = Unspecified`.
6. HotChocolate strips `Get` from every resolver name and appends `Input` to input types. `tsc` cannot see gql field names — a wrong name compiles clean and fails only at runtime. Verify each field name against the schema type.
7. **Never assume** a GraphQL field, DTO property, or column name. Read the backend source first.
8. Reuse before you create. Search the component registries; if a design-system component exists (`Select`, `Slider`, `SecretInput`), use it.
9. **Do not "fix" a mock into a real integration.** Items marked `MOCK` in §③ are backend integrations that do not exist. Label them honestly in the UI; do not build the integration.
10. **Do the phases in order.** Phase 2 needs Phase 1's refactor to land first, or you will edit the same money-formatting code twice.

---

## ⓪ Verified on disk — 2026-08-05

| What | Where | State |
|---|---|---|
| Email screen route | `src/app/[lang]/(core)/setting/communicationconfig/emailproviderconfig/page.tsx` | exists |
| SMS screen route | `src/app/[lang]/(core)/setting/communicationconfig/smssetup/page.tsx` | exists |
| WhatsApp screen route | `src/app/[lang]/(core)/setting/communicationconfig/whatsappsetup/page.tsx` | exists |
| Email components | `src/presentation/components/page-components/setting/communicationconfig/emailproviderconfig/` | 9 files |
| SMS components | `src/presentation/components/page-components/setting/communicationconfig/smssetup/` | 13 files |
| WhatsApp component | `src/presentation/components/page-components/**crm/whatsapp**/whatsappconfiguration/index.tsx` | 1023 lines. **Sits under `crm/`, not beside its two siblings** (finding W-4 in the companion plan) |
| `SmsSetting` entity | `Base.Domain/Models/NotifyModels/SmsSetting.cs` | has `MonthlyBudgetCap decimal?`, `BudgetAlertThresholdPct int`. **No `CurrencyId`. No country column. No timezone column.** |
| `WhatsAppSetting` entity | `Base.Domain/Models/NotifyModels/WhatsAppSetting.cs` | has `TokenExpiresAt DateTime?`. **No cap, no currency, no country.** |
| Correct money pattern already in repo | `emailproviderconfig/reputation-cards.tsx:111-128,215-223` | resolves provider currency → company base currency → real FX conversion via `useCompanySettings` + rate lookup. **This is the reference implementation. Copy it; do not invent a new one.** |
| Correct secret pattern already in repo | `smssetup/secret-input.tsx` (83 lines) | write-buffer + `maskedHint` last-4 + eye toggle. Empty value ⇒ "do not change saved secret". **This is the reference implementation.** |
| WhatsApp secret pattern | `crm/whatsapp/whatsappconfiguration/index.tsx:197-198,214-215,714,739` | already correct — `accessTokenMasked` / `appSecretMasked` read back, write buffers cleared on load |

---

## ① The one idea

Three screens that do the same job were built to three different standards. Each screen already contains the correct fix for another screen's defect.

| Concern | Email #28 | SMS #157 | WhatsApp #34 |
|---|---|---|---|
| Secret handling | ❌ **plaintext round-trip** | ✅ masked write-only | ✅ masked write-only |
| Save-time validation | ❌ **none at all** | ✅ thorough per-vendor | 🟡 partial |
| Currency | ✅ **provider + company + FX** | ❌ hard-coded USD | ❌ absent |
| Spend control | ❌ absent | ✅ budget + auto-pause | ❌ absent |

**The job is convergence, not invention.** Lift the green cell into the red cells in the same row. Only two items in this whole prompt need a new backend field, and they are both isolated in Phase 2.

---

## ② Findings — Email Provider Config (#28)

File paths are relative to `src/presentation/components/page-components/setting/communicationconfig/emailproviderconfig/`.

| ID | File:line | Defect | Severity | Phase |
|---|---|---|---|---|
| **E-1** | `email-provider-config-page.tsx:190-212` | The load path parses `providerConfiguration` JSON and assigns `cfg.apiKey` and `cfg.password` **straight into form state in plaintext**. Combined with the eye-toggle at `:548` and `:892`, the real API key and SMTP password are rendered in the browser. SMS and WhatsApp both use masked-hint + write-buffer. Email is the only screen that leaks. | 🔴 Security | 1 |
| **E-2** | `email-provider-config-page.tsx:353` `handleSave()` | **Zero client validation.** No provider check, no `defaultFromEmail` check, no `sendingDomainName` check, no per-provider credential check. An empty form submits. Contrast `smssetup/connection-config-section.tsx:210-258`, which validates every vendor's required fields. | 🔴 Broken | 1 |
| **E-3** | `email-provider-config-page.tsx:744-790` | Hourly / Daily / Monthly limits carry `min={0}` and nothing else. Hourly 5000 + Daily 100 + Monthly 10 saves without complaint. No ordering invariant. | 🟠 | 1 |
| **E-4** | `email-provider-config-page.tsx:836` | SMTP Port is an unconstrained text input — no 1–65535 range, no common-port hint (25 / 465 / 587 / 2525), no cross-check against the `encryption` field (465 ⇒ SSL, 587 ⇒ STARTTLS). | 🟠 | 1 |
| **E-5** | `provider-card-selector.tsx:17,128` | Several provider cards render disabled with a "Coming soon" hint. **Intentional and correct** — listed so it is not re-reported as a bug. | 🟡 No action | — |
| **E-6** | `reputation-cards.tsx:115` | `providerCurrencyCode ?? companyCurrencyCode ?? "USD"` — the final fallback is a hard-coded USD. Low impact because both prior values are normally set, but the fallback should render a neutral state rather than assert a currency. | 🟡 | 1 |

---

## ③ Findings — SMS Setup (#157)

File paths relative to `.../communicationconfig/smssetup/`.

### 3a. Broken / incorrect

| ID | File:line | Defect | Severity | Phase |
|---|---|---|---|---|
| **S-1** | `usage-billing-section.tsx:42-48` | `fmtMoney` hard-codes `new Intl.NumberFormat("en-US", { currency: "USD" })`. Drives **Spent This Month**, **Remaining**, **Avg Cost / Segment**, and every row of **Cost by Country**. An Indian tenant sees `$` against rupee spend. | 🔴 | 2 |
| **S-2** | `usage-billing-section.tsx:331-333` | A literal `$` character is positioned inside the Monthly Budget Cap input. `SmsSetting` has **no `CurrencyId`**, so there is nothing to source a real symbol from — this one requires the Phase 2 column. | 🔴 | 2 |
| **S-3** | `usage-billing-section.tsx:115-123` | Period is `new Date(y, m, 1).toISOString().slice(0,10)` — local midnight serialised to UTC. For IST (+05:30), 1 Aug local becomes **31 Jul** UTC. **The usage period queried is wrong by one day for every tenant ahead of UTC**, so the first day of each month is attributed to the previous month. | 🔴 | 1 |
| **S-4** | `usage-billing-section.tsx:224-227` | Save validates **only** `thresholdPct` (50–100). `monthlyBudgetCap` goes through `parseFloat` with no min, no max, and no decimal-precision guard — negatives and 9-decimal values persist. | 🔴 | 1 |
| **S-5** | `sender-configuration-section.tsx:69-83` | The entire validation is *"Alphanumeric requires a fallback number"*. No **E.164** format check on `fallbackSenderNumber`, and no per-country legality check — despite the info box at `:90-94` explicitly claiming *"alphanumeric IDs require per-country registration"*. The screen asserts a rule it does not enforce. Placeholder is a US number `+14155550100` (`:154`). | 🔴 | 1 |
| **S-6** | `connection-config-section.tsx:338-342` | Test-SMS recipient is checked for non-empty only. The same applies to `twilioDefaultFromNumber` and `vonageDefaultFromNumber` — required, but format never validated. | 🟠 | 1 |
| **S-7** | `dnd-compliance-section.tsx:26-32` | `DND_PROVIDERS` is a hard-coded India/US/UK list, and **`"Auto (per region)"` is a dead option** — no country or region field exists anywhere on `SmsSetting` for it to auto-detect from. It is the **default value** (`:53`), so the shipped default is the one option that cannot work. | 🔴 | 3 |

### 3b. Placeholder / not wired — label honestly, do not build the integration

| ID | File:line | Defect | Phase |
|---|---|---|---|
| **S-8** | `dnd-compliance-section.tsx:176-180` | "Blocked Contacts" renders a hard-coded `2,847` beside the text `(placeholder count)`. A fabricated number in a compliance panel. | 1 |
| **S-9** | `dnd-compliance-section.tsx:189` | "View Blocked List" fires `toast.info("Blocked-list view not yet available")` and nothing else. | 1 |
| **S-10** | `dnd-compliance-section.tsx:87` | Sync toast reads `"DND registry synced (mocked)"` — `MOCK`, no registry call exists. | 1 |
| **S-11** | `connection-config-section.tsx:162,177,802` + `sms-setup-page.tsx:166,432` | Connect and Test SMS are both `(mocked)`. The page already carries an honest inline notice — *"Service is currently mocked — no actual SMS is sent."* **That notice is the correct pattern; apply it to S-8/S-9/S-10 too.** | 1 |

### 3c. Design-system / standards

| ID | File:line | Defect | Phase |
|---|---|---|---|
| **S-12** | `dnd-compliance-section.tsx:146-160` | Raw `<select>` element instead of the design-system `Select`. Visually inconsistent with every other dropdown in the product. | 1 |
| **S-13** | `usage-billing-section.tsx:408-419` | Raw `<input type="range">` instead of the design-system `Slider`. | 1 |
| **S-14** | `usage-billing-section.tsx:291,298` | KPI icon containers use `bg-green-50 text-green-600` / `bg-red-50 text-red-600`. **Violates the standing rule: widget / KPI icon containers and status badges are solid `bg-X-600` + `text-white`.** Visualisation fills may keep mid-saturation; icon containers may not. | 1 |
| **S-15** | `dnd-compliance-section.tsx:40-45` | `formatDateTime` calls `toLocaleString()` on a UTC-stored `lastDndSyncAt` with **no timezone label**. The user cannot tell which zone they are reading. | 1 |

### 3d. Already correct — do not change

- Per-vendor required-field validation, `connection-config-section.tsx:210-258` (Twilio / Bird / Vonage / Local / Custom, including the Custom JSON-template placeholder check).
- Secret handling via `secret-input.tsx` — write buffer, masked last-4, empty means unchanged.
- Opt-out keyword rules, `opt-in-out-section.tsx:137-170` — dedupe, ≤50 chars, ≤320-char confirmation message, at least one keyword required.
- The DND turn-off `AlertDialog` at `:225-245`, which names TRAI / TCPA / PECR by name. **Keep the wording.**
- `Pause Promotional Only` correctly `disabled={!autoPause}`.

---

## ④ Findings — WhatsApp Setup (#34)

File: `src/presentation/components/page-components/crm/whatsapp/whatsappconfiguration/index.tsx` (1023 lines).

| ID | Line | Defect | Severity | Phase |
|---|---|---|---|---|
| **W-1** | `197-198, 214-215, 714, 739` | Secret handling is **correct** — masked read-back, cleared write buffers, replace-only semantics. **This is the pattern E-1 must adopt.** No action. | ✅ | — |
| **W-2** | `752-753, 815` | `tokenExpiresAt` is a bare datetime input the admin types by hand. Nothing computes days-remaining, nothing warns on approach, nothing flags an already-expired token. WhatsApp stops sending silently. (Finding W-1 in the companion plan.) | 🟠 | 1 |
| **W-3** | whole file | **No sending limit, no budget cap, no currency, no country.** WhatsApp is the only channel with zero cost control — SMS has a budget, Email has rate limits. | 🟠 | 3 |
| **W-4** | file location | Lives under `crm/whatsapp/` while its two siblings live under `setting/communicationconfig/`. The **route** is correct; the **component folder** is not. | 🟡 | 1 |

---

## ⑤ Build steps

### Phase 1 — FE only. No migration. No backend change. Start here.

1. **Create `src/presentation/components/page-components/setting/communicationconfig/_shared/`** holding:
   - `money.ts` — a single currency formatter that takes an explicit `currencyCode` + optional `symbol`. **Port the resolution logic from `reputation-cards.tsx:111-128`** (provider currency → company base currency → neutral). Export a `useCommsCurrency()` hook so all three screens resolve identically. **No `"USD"` literal anywhere in the file.**
   - `period.ts` — `getCurrentMonthUtcRange()` built with `Date.UTC(...)`, never local-midnight-then-`toISOString`. Fixes **S-3**.
   - `phone.ts` — `isE164(value)` (`/^\+[1-9]\d{7,14}$/`) plus a `normaliseE164` helper. Fixes **S-5**, **S-6**.
   - `MockNotice.tsx` — the inline "this is not wired yet" banner, styled once. Lift the existing wording from `sms-setup-page.tsx:432`.
2. **E-1 — stop the plaintext secret round-trip.** BE returns the secret today; the FE must stop rendering it. Change `email-provider-config-page.tsx:190-212` to **never** hydrate `apiConfig.apiKey` or `smtpConfig.password` from the parsed config. Instead derive a masked hint (last 4) and adopt `smssetup/secret-input.tsx` for both fields. Send the field only when the write buffer is non-empty; omit the key entirely when it is empty so the BE keeps the saved value.
   > ⚠️ **Verify first**: read the email save handler and DTO in `Base.Application` and confirm the BE already treats an absent/empty credential as "unchanged". If it **overwrites with empty**, stop and record it in §⑬ as a BE follow-up — do **not** ship a FE change that wipes live credentials.
3. **E-2 — add save validation** to `handleSave()`. Mirror the shape of `connection-config-section.tsx:210-258`: an `errors` object, per-field messages, `toast.error("Please fix validation errors")`, red borders. Minimum set — provider selected; `defaultFromEmail` present and valid; `sendingDomainName` present; API key required when the buffer is empty **and** no masked hint exists; SMTP host/port/username required for SMTP.
4. **E-3 — limit ordering.** Enforce `hourly ≤ daily ≤ monthly` when more than one is set, with a message naming the two fields that conflict. Blank stays blank (means unlimited); do not coerce to 0.
5. **E-4 — SMTP port.** `type="number"`, `min={1}`, `max={65535}`, integer only, plus a helper line listing 25 / 465 / 587 / 2525. Warn (do not block) when port and `encryption` disagree.
6. **E-6** — drop the `"USD"` tail; render a neutral amount with no symbol when neither currency resolves.
7. **S-3** — replace the period `useMemo` with `getCurrentMonthUtcRange()`.
8. **S-4** — validate `monthlyBudgetCap`: `>= 0`, `<= 99,999,999`, at most 2 decimals, and reject `NaN` from `parseFloat`. Show the message beside the field, not only as a toast.
9. **S-5 / S-6** — apply `isE164` to `fallbackSenderNumber`, the test-SMS recipient, `twilioDefaultFromNumber` and `vonageDefaultFromNumber`. Replace the US placeholder `+14155550100` with a format hint (`+<country code><number>`), not another country's example.
10. **S-8 / S-9 / S-10** — remove the fabricated `2,847`. Render an em-dash plus `<MockNotice />` explaining that DND blocked-count and registry sync are not connected yet. Keep the buttons visible and **disabled** with a tooltip, rather than clickable-then-toast. **Do not build the DND integration.**
11. **S-12** — swap the raw `<select>` for the design-system `Select`, preserving the `disabled={!honorDnd}` behaviour.
12. **S-13** — swap the raw `<input type="range">` for the design-system `Slider`, preserving the 50–100 bound.
13. **S-14** — KPI icon containers to solid `bg-X-600` + `text-white`.
14. **S-15** — append the resolved timezone abbreviation to `formatDateTime`, or render the UTC value with an explicit `UTC` suffix. Pick one and use it on all three screens.
15. **W-2** — derive days-to-expiry from `tokenExpiresAt`. Show a neutral chip beyond 14 days, a warning chip inside 14, a destructive chip when past. Read-only display; the input stays editable.
16. **W-4** — move the WhatsApp component folder to `setting/communicationconfig/whatsappsetup/` and update every import. Route file stays where it is. **Mechanical move — do not refactor the component in the same commit.**
17. `npx tsc --noEmit --incremental false` → **exit 0**.

### Phase 2 — needs one migration. Do not start until Phase 1 is typecheck-clean.

18. Add to `Base.Domain/Models/NotifyModels/SmsSetting.cs`:
    ```csharp
    /// <summary>Currency of MonthlyBudgetCap and all reported SMS spend. FK → app.Currencies.</summary>
    public int? CurrencyId { get; set; }
    public Currency? Currency { get; set; }
    ```
    Add the EF configuration (FK, `OnDelete(Restrict)`, no cascade). **Do not run the migration** — write the spec into §⑩.
19. Surface `currencyId`, `currencyCode`, `currencySymbol` on `SmsSettingDto` and on the save request for the budget section. Resolution rule: **`SmsSetting.CurrencyId` → company base currency → null**. Same precedence as `reputation-cards.tsx`.
20. **S-1 / S-2** — delete `fmtMoney`; route every amount in `usage-billing-section.tsx` (Spent, Remaining, Avg Cost/Segment, Cost by Country) through `useCommsCurrency()`. Replace the literal `$` with the resolved symbol; render no symbol at all when the currency is unresolved.
21. Add a currency selector beside Monthly Budget Cap, defaulting to the company base currency. Warn when the selected currency differs from the company base — that is a real scenario (a US Twilio account billing a UK charity), not an error.
22. `npx tsc --noEmit --incremental false` → **exit 0**. Hand the user the migration spec.

### Phase 3 — BLOCKED. Do not start. See §⑨ Q1.

23. **S-7** — a country/region source for DND. Cannot be designed until the country-scope question is answered.
24. **W-3** — WhatsApp sending cap / budget. Deliberately deferred: the companion plan's §⑥ Q2 (per-plan SMS and WhatsApp allowances) must be answered first, or a cap here would duplicate the L1 plan quota.

---

## ⑥ Invariants

1. **Never render a stored secret.** Masked hint plus a write buffer, always. An empty buffer means "leave the saved value alone" — it never means "clear it".
2. **No currency literal in any component.** Not `"USD"`, not `$`. Every amount resolves through `useCommsCurrency()`. This is the single rule that makes the screens sellable outside the US.
3. **No local-time date arithmetic.** Period boundaries and month starts use `Date.UTC`. The DB is UTC-only and the FE must match.
4. **A screen never asserts a rule it does not enforce.** If the info box says alphanumeric sender IDs need per-country registration, either enforce it or reword the box.
5. **A fabricated number is worse than an empty state.** Placeholder counts get removed, not restyled.
6. **A mock stays labelled.** A mocked action is visibly disabled or visibly annotated. It never looks like it worked.
7. Phase 1 touches **no** `.cs` file. Phase 2 touches exactly one entity, one configuration, one DTO, one handler.
8. Validation lives on **both** sides. The FE checks are a usability layer; they do not replace BE validators, and this prompt does not remove any.

---

## ⑦ Out of scope

- The three throttle layers (L1 plan quota / L2 provider rate cap / L3 spend budget) and the metering gap — companion plan §②, and PROMPT-12.
- SMS multi-provider / failover / priority (companion S-1) and the schema-per-vendor tax (S-3). This prompt does not change the storage model of any channel.
- Moving SMS or WhatsApp secrets out of plaintext **columns** (companion S-2, W-2). That is a BE encryption change with its own migration. This prompt only stops the FE from **displaying** them.
- Building the DND registry integration, the blocked-list screen, or real SMS sending. All three stay mocked.
- Platform-side communication providers — that is PROMPT-08 / PROMPT-09.
- Any change to `notify` schema tables other than the single `SmsSettings.CurrencyId` column.
- Re-styling the screens beyond the specific items in §③c.

---

## ⑧ Acceptance

Phase 1:
1. `grep -rn 'USD\|Intl.NumberFormat("en-US"' src/presentation/components/page-components/setting/communicationconfig` returns **only** hits inside `_shared/money.ts` — and none of those is a fallback literal.
2. Email screen: open a saved SendGrid config with DevTools on the network tab. The API key value is **not** present in component state and the eye toggle reveals nothing.
3. Email screen: clear the provider and press Save → inline errors, no mutation fired.
4. Email screen: Hourly 5000 / Daily 100 → error naming both fields.
5. Email screen: SMTP port `70000` → rejected.
6. SMS screen with the browser timezone set to `Asia/Kolkata` on 1 August: the usage period reads **1 Aug – 31 Aug**, not 31 Jul.
7. SMS screen: budget cap `-5` → rejected. `1.239` → rejected.
8. SMS screen: fallback sender `04412345678` → rejected as not E.164. `+919841234567` → accepted.
9. SMS screen: no `2,847` anywhere in the DOM. Blocked-list and Sync buttons are disabled with an explanatory notice.
10. SMS screen: DND provider is the design-system `Select`; threshold is the design-system `Slider`.
11. SMS screen: KPI icon containers are solid `bg-X-600` with white glyphs.
12. WhatsApp screen: set `tokenExpiresAt` to 5 days out → warning chip. To yesterday → destructive chip.
13. WhatsApp component resolves from `setting/communicationconfig/whatsappsetup/`; the route still renders.
14. `npx tsc --noEmit --incremental false` → **exit 0**.

Phase 2:
15. A tenant with base currency INR and no `SmsSetting.CurrencyId` sees `₹` on Spent, Remaining, Avg Cost/Segment, Cost by Country, and the budget-cap prefix.
16. Setting `SmsSetting.CurrencyId` to USD on that tenant switches all six to `$` and shows the mismatch warning.
17. A tenant with neither resolves shows amounts with **no** symbol — never `$`.
18. `npx tsc --noEmit --incremental false` → **exit 0**.

---

## ⑨ Open questions

**Q1 — BLOCKING Phase 3. Which countries is the product actually sold into?**
This single answer decides the whole shape of S-7 and W-3:

| Answer | Consequence |
|---|---|
| India only | DLT registration + TRAI DND + INR. Delete the US/UK options from `DND_PROVIDERS`, hard-wire TRAI, drop `"Auto"`. Smallest build. |
| Multi-region | A country field is needed on `SmsSetting` (or on the tenant) to drive DND registry choice, sender-ID legality, and quiet hours. Roughly **3×** the work of the India-only path. |
| Country lives on the tenant | No new column on `SmsSetting`; read the existing tenant country. **Confirm which table and column holds it before assuming this.** Cheapest if true. |

**Q2** — When a tenant's SMS provider bills in a different currency from the company base (US Twilio account, UK charity), should reported spend display in the **provider** currency, the **company** currency, or both with an FX conversion as `reputation-cards.tsx` does for email? Recommendation: **both**, matching the email screen, for consistency.

**Q3** — E-1's fix assumes the email save handler treats an absent credential as "unchanged". If it does not, do you want the BE change in this prompt, or as a separate one? Recommendation: **in this prompt**, because shipping the FE half alone risks wiping live credentials.

**Q4** — S-15: display timestamps in the **tenant's** timezone (needs a tenant timezone field — confirm one exists) or in **UTC with an explicit suffix**? Recommendation: **UTC with a suffix** for now; it is honest and needs no new field.

**Q5** — W-4's folder move touches every import of the WhatsApp component. Confirm no other screen imports it before the move, and confirm you want it in the same session rather than as its own commit.

---

## ⑩ Migration spec — Phase 2 only

**Status:** entity + EF configuration + DTO + handler are written and the FE typechecks clean. The migration itself is yours to generate, review, apply and commit.

**Model change (already in source):**

| File | Change |
|---|---|
| `Base.Domain/Models/NotifyModels/SmsSetting.cs` | `+ using Base.Domain.Models.SharedModels;`<br>`+ public int? CurrencyId { get; set; }` (Usage & Billing block)<br>`+ public Currency? Currency { get; set; }` (Navigation block) |
| `Base.Infrastructure/Data/Configurations/NotifyConfigurations/SmsSettingConfiguration.cs` | `+ builder.HasOne(e => e.Currency).WithMany().HasForeignKey(e => e.CurrencyId).OnDelete(DeleteBehavior.Restrict);` |
| `Base.Application/Schemas/NotifySchemas/SmsSettingSchemas.cs` | `+ CurrencyId` on `SmsSettingResponseDto` and on `SmsBudgetConfigRequestDto`; `+ CurrencyId > 0` rule in `SmsBudgetConfigRequestDtoValidator` |
| `…/SmsSettings/SaveBudgetConfigurationCommand/SaveSmsBudgetConfiguration.cs` | `+ entity.CurrencyId = dto.CurrencyId;` |

No inverse collection was added on `Currency` — the FK is a lookup reference and is never navigated in reverse, which keeps `Currency.cs` (and every other entity's snapshot surface) untouched.

**Generate the migration:**

```bash
cd PSS_2.0_Backend
dotnet ef migrations add Add_SmsSettingCurrency -p Base.Infrastructure -s Base.API
# review Up()/Down(). Expect exactly:
#   • one nullable integer column "CurrencyId" on notify."SmsSettings"
#   • one index IX_SmsSettings_CurrencyId
#   • one FK → com."Currencies"("CurrencyId") ON DELETE RESTRICT
# Anything else in the diff is unrelated drift — do not let it ride along.
dotnet ef database update -p Base.Infrastructure -s Base.API
```

> `Currencies` lives in schema **`com`**, not `app` (`[Table("Currencies", Schema = "com")]` in `SharedModels/Currency.cs`).

**Backfill: none.** Existing rows get `CurrencyId = NULL`, which the screen resolves to the tenant's base currency from the CompanySettings session — the same amounts render as before the change. There is no company-level currency column to copy from either: `ApplicationModels/Company.cs` has no currency field; the base currency is a settings value, not a `Companies` column. A SQL backfill would have to read the settings store, and it would buy nothing over the NULL fallback.

---

## ⑬ Deviations

**Session 2026-08-05 — Phase 1 + Phase 2.**

1. **E-1 is mis-stated in the prompt.** The BE already masks `apiKey` / `password` to `"••••••••"` on read and already restores the prior value on an empty-or-placeholder write (`PreserveSensitiveFields`, `SaveCompanyEmailProvider.cs:127-128`). It is a *placeholder* round-trip, not a plaintext one. The FE fix shape was unchanged and is now proven safe. **§⑨ Q3 therefore needed no BE change.**
2. **E-4 is mis-stated.** SMTP Port was already a constrained `<select>` over `["25","465","587","2525"]`. Only the port↔encryption consistency check was genuinely missing; that is what was built.
3. **E-3 was under-specified.** No Monthly Email Limit input existed, so `hourly ≤ daily ≤ monthly` was unenforceable. A Monthly input was added to make the rule meaningful.
4. **`defaultFromEmail` has no rendered input** on the email screen (it exists in state and in the save payload only), so its validation rule currently has no UI anchor. Left as-is — adding the field is beyond the §③ list.
5. **§⑨ Q4 implemented as "always an explicit zone suffix"**, where the zone is the tenant's configured IANA timezone when one exists (e.g. "Kolkata") and UTC only when none is. `formatDateTime` silently falls back to **browser-local** when `defaultTimezone` is null, so an unconditional "UTC" label would have printed a false claim; the UTC branch uses `formatInTimeZone(d, "UTC", …)` so the label is always true.
6. **WhatsApp "Estimated Invoice" was removed, not reformatted.** It hard-coded a `$` symbol and an invented `0.15`/conversation rate. W-3 (WhatsApp currency + cost control) is Phase 3, so no rate source exists; an honest empty state satisfies invariants #2 and #5 without building W-3.
7. **Phase-3 unblocker found.** `countryOfOperationId` / `countryOfOperationName` already exist on `CompanySessionSettings` — that answers §⑨ Q1 in favour of the "cheapest if true" branch. Phase 3 itself remains out of scope for this session.
8. **Prompt rule 4 overstates the gitignore.** Only `PSS_2.0_Backend/` is gitignored; `PSS_2.0_Frontend/` is tracked normally and the Grep tool works inside it.
9. **Phase 2 currency read-back is `currencyId` only.** `GetSmsSettingHandler.MapToResponse` maps through Mapster from an entity loaded without `Include(Currency)`, so no `currencyCode` / `currencySymbol` was added to the response DTO — that would have required either a query change or a second handler edit, breaking invariant #7's one-entity/one-config/one-DTO/one-handler budget. The FE resolves code and symbol from `CURRENCIES_QUERY`, which it already loads for the selector.
10. **A budget cap with no currency selected is legal.** It resolves to the tenant base currency, which is exactly what pre-change rows did. The added BE rule only rejects a supplied `CurrencyId <= 0`; no rule was added that would invalidate existing saved data.

---

## ⑭ Build log

*(Last 5 sessions only — git keeps the rest.)*

### 2026-08-05 — Phase 1 + Phase 2 (scope chosen by user; Phase 3 deferred)

**Phase 1 — frontend only, no `.cs` touched.**
- New shared layer `setting/communicationconfig/_shared/`: `money.ts` (`useCommsCurrency`, direct-pair FX, no currency literal), `period.ts` (`getCurrentMonthUtcRange`, `formatUtcDateRange`, `Date.UTC` only), `phone.ts` (E.164), `time.ts` (`useTimestampFormatter`, always an explicit zone label), `MockNotice.tsx`.
- New `Slider` atom in `common-components/atoms/Slider/`, exported from the common barrel.
- **#28 Email** — E-1 (empty secret write-buffers + `SecretInput`), E-2 (`validate()` gate + provider-selection error anchor), E-3 (Monthly Email Limit input + `hourly ≤ daily ≤ monthly`), E-4 (SMTP port↔encryption cross-check), E-6 (provider-currency fallback chain, `"USD"` gone).
- **#157 SMS** — S-1/2/3/4/13/14 (money through `useCommsCurrency`, UTC periods, budget validation, `Slider`, solid KPI icon containers, right-aligned amounts), S-5 (alphanumeric fallback-number rule), S-6 (E.164 on all from-numbers + test send), S-8/9/10 (fabricated blocked-contact count replaced with an empty state, `MockNotice`, disabled blocked-list action), S-12 (`Select` for every remaining raw `<select>`), S-15 (zone-labelled timestamps).
- **#34 WhatsApp** — W-2 (token-expiry chip via `describeTokenExpiry`, zone-labelled timestamps, `formatUtcDateRange` on both period ranges, `$`-literal Estimated Invoice replaced with an honest empty state), W-4 (folder moved from `crm/whatsapp/whatsappconfiguration/` to `setting/communicationconfig/whatsappsetup/`; both importers updated, stale barrel export removed).
- `npx tsc --noEmit --incremental false` → **exit 0**.

**Phase 2 — `SmsSetting.CurrencyId`.**
- BE: entity + `Currency` nav, EF FK (`WithMany()`, `Restrict`), `CurrencyId` on response + budget-request DTOs with a `> 0` validator rule, `entity.CurrencyId = dto.CurrencyId;` in `SaveSmsBudgetConfigurationHandler`. Exactly one entity, one configuration, one DTO file, one handler. **No migration generated or applied** — spec handed over in §⑩.
- FE: `currencyId` added to `SmsSettingDto`, `SmsBudgetConfigRequestDto`, the SMS setting query and the mutation fragment; billing-currency `Select` (fed by `CURRENCIES_QUERY`) beside Monthly Budget Cap; `useCommsCurrency` now receives the provider currency, so Spent / Remaining carry a company-currency equivalent and a mismatch notice states the FX situation (including the "no curated rate" case).
- `npx tsc --noEmit --incremental false` → **exit 0**. `dotnet build` not run, per §⚠️ rule 2.

**Not done (deliberate):** Phase 3 — S-7 (DND country source) and W-3 (WhatsApp cap / budget / currency / country), both blocked on the companion plan's per-plan SMS and WhatsApp allowance decision.
