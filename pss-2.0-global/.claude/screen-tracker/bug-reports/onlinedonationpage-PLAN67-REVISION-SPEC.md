# ODP #10 — /plan-screens Revision Spec (Session 67, 2026-07-17)

> **Screen #10 Online Donation Page** (EXTERNAL_PAGE / DONATION_PAGE). Status stays **NEEDS_FIX**.
> This is the execution-ready plan for `/build-screen #10`. Six items were submitted for planning;
> **two (ODP-B5, ODP-B8) were found already built + committed** and need only documentation
> reconciliation. Four are live build work (ODP-B7, ISSUE-47b, ISSUE-43, DonateFormSection).
>
> **Standing constraints (verbatim):** EAV-only *except* the single user-owned schema exception
> explicitly approved for ODP-B7 below. Migrations strictly user-owned (I write the spec; the user
> authors/runs/commits — never `dotnet ef migrations add/update/remove`). BUSINESSADMIN only.
> Every `DateTime` written to Postgres is `Kind=Utc`. NEVER `Read` REGISTRY.md (grep only).

---

## 0. Reconciliation — ODP-B5 & ODP-B8 are DONE (no build)

Investigation of the live backend (not the stale handoff docs) found both features fully implemented,
migrated, and committed. **`/build-screen` must NOT rebuild these.** Record as CLOSED.

### ODP-B5 (captured→recorded auto-promotion) — CLOSED, commits `59786747` + `c730e2e7`
- `Business/DonationBusiness/OnlineDonations/Commands/PromoteOnlineDonationStaging.cs` (595 ln) + `PromoteRecurringCycle.cs` (243 ln) EXIST.
- `GlobalDonations/Services/IGlobalDonationCompositeWriter.cs` + `GlobalDonationCompositeWriter.cs` (410 ln) EXIST; interface doc mandates "never touch `IHttpContextAccessor`"; `WriteAsync(payload, companyId, ct)` matches spec.
- `ConfirmOnlineDonation.PromoteCapturedDonationAsync` sends `PromoteOnlineDonationStagingCommand` and returns a real `ReceiptNumber` at all 4 gateway-success sites (Braintree 517 / Razorpay 638 / PayU 757) + 3 recurring-cycle sites (925/1187/1361). The lone `ReceiptNumber=null` (line 301) is the pre-existing idempotent-replay branch, not a stub.
- `CreateGlobalDonationWithChildren.cs` refactored 752→374 ln; delegates to the writer.
- Webhooks wired: `PaymentWebhookController.cs:196` (SUBSCRIPTION_CHARGED_SUCCESSFULLY) + `RazorpayWebhookController.cs:379` (subscription.charged) both send `PromoteRecurringCycleCommand`.
- Partial unique index `UX_GlobalOnlineDonations_Company_GatewayTxn` present in `GlobalOnlineDonationConfiguration.cs:74-83`, in migration `20260716074219_Add_OnlineDonationPageSetting.cs:61-67`, and in the model snapshot. Working tree clean.
- **Action:** the stale docs `onlinedonationpage-ODP-B5-HANDOFF.md` and `-ODP-B5-NEXT-SESSION.md` are SUPERSEDED — do not action their "you own the migration/commit" instructions (already committed). Mark B5 CLOSED in the prompt.

### ODP-B8 (compliant tax receipt) — CLOSED, commits `a09b83fd` + `895f4e97`
- `ConfirmOnlineDonation.IssueReceiptEmailAsync` (107-160) calls `receiptService.GenerateReceiptPdfAsync(globalDonationId, ct)`, emails via `SendComposedEmailForCompanyAsync` with `AttachmentContentType="application/pdf"`.
- `Services/DonationReceipt/DonationReceiptService.cs` builds an A4 print-CSS receipt (`BuildReceiptHtml`) → `IPdfService.GeneratePdfBytesAsync` (`Infrastructure/Services/PdfService.cs`, **PuppeteerSharp** headless Chromium).
- Anonymous rate-limited download: `ReceiptDownloadController.cs` — `GET /api/ReceiptDownload/{sessionToken}` resolves by `PaymentSessionId`.
- `ReceiptNumber` via `NumberSequenceGenerator.GenerateAsync(dbContext, companyId, "GLOBALDONATION", …)` in `GlobalDonationCompositeWriter.cs:267` — auto-promoted (B5) and staff-created donations share the sequence.
- Jurisdiction-safe: org-settings gates `TAX_EXEMPTION_NUMBER`/`TAX_SECTION`/`SHOW_TAX_INFO_ON_RECEIPT`/`INCLUDE_ORG_LOGO_ON_RECEIPT`/`AUTHORIZED_SIGNATORY`; 80G block renders only when `TAX_EXEMPTION_NUMBER` is set (no blanket assertion).
- **Latent (NOT in scope, note only):** the receipt PDF is a hardcoded C# HTML builder, not an admin-editable template registry. A future "receipt template designer" would be new work — do not build now. (ISSUE-47b below only makes the receipt *email body* template-driven, not the PDF.)

---

## 1. ODP-B7 — GDPR consent capture (BUILD; user-owned schema exception approved)

Nothing exists today: `DonorFieldConfig` = `required/visible/locked` only; no consent field; no per-donor
sink on `OnlineDonationStaging`/`GlobalDonation`. The user explicitly approved a **user-owned column
exception** to get an auditable per-donor trail (chose "User-owned consent columns").

### 1a. Schema — USER-OWNED migration (I write spec; user authors/runs/commits)
Add nullable columns to **`fund.OnlineDonationStaging`** (all nullable — historic rows have no consent):

| Column | Type | Notes |
|--------|------|-------|
| `ConsentGivenAt` | `timestamp with time zone` (nullable) | Set to `DateTime.UtcNow` (Kind=Utc) at staging-create when consent checkbox ticked. Null = not captured. |
| `ConsentTextSnapshot` | `text` (nullable) | Exact consent statement string shown to the donor at submit (immutable audit copy). |
| `ConsentTextVersion` | `varchar` (nullable) | Optional version tag echoed from the page config (e.g. the EAV row's `ModifiedDate` stamp or a manual version string). |
| `MarketingOptIn` | `boolean` (nullable) | Separate optional marketing-consent checkbox state; null = not shown. |

- No other table changes. No dropped/altered columns. The migration `Up` = 4 `AddColumn`; `Down` = 4 `DropColumn`. I deliver the migration SPEC block in the handoff; user runs it.
- **DO NOT** put consent on `GlobalDonation` — the staging row is the capture point (pre-promotion) and the durable audit record. Promotion (B5) already exists and does not need to copy the consent snapshot to the ledger.

### 1b. EAV — page-level consent config (no schema; follows OnlineDonationPageSettings pattern)
New `SectionCode = "CONSENT"` on `fund.OnlineDonationPageSettings`:

| ParamCode | ParamDataType | Meaning |
|-----------|---------------|---------|
| `CONSENT_ENABLED` | `bool` | Master switch — render the consent checkbox on the public form. |
| `CONSENT_TEXT` | `text` | Statement shown next to the checkbox (supports a privacy-policy link; render as sanitized inline text/anchor). |
| `CONSENT_REQUIRED` | `bool` | If true, submit is BLOCKED (client + server) until ticked. |
| `MARKETING_OPTIN_ENABLED` | `bool` | Render a second, always-optional marketing-consent checkbox. |
| `MARKETING_OPTIN_TEXT` | `text` | Label for the marketing checkbox. |

- Wire into `PresentationOnlineDonationPageSettings.Assemble(rows)` + `BuildDefaultRows` + `AssembleLandingContentDto` in `DefaultOnlineDonationPageSettings.cs` (typed DTO fields, JSON WriteOpts=CamelCase / ReadOpts=case-insensitive).
- Add all five ParamCodes to `ManagedParamCodes` so the diff-only landing-content sweep never soft-deletes them.
- No media → **no user-owned seed needed** for the config text (admin types it); defaults from `BuildDefaultRows` (CONSENT_ENABLED=false, CONSENT_REQUIRED=false, MARKETING_OPTIN_ENABLED=false, empty texts) so existing pages are unaffected.

### 1c. Public form (FE — `components/donation-form.tsx`)
- When `publicData.consentEnabled`: render a mandatory-styled checkbox + `CONSENT_TEXT` (with privacy link) inside the "Your information" fieldset, above the submit button. When `consentRequired`, the submit button is disabled / RHF-invalid until ticked (mirror the server rule; never rely on client alone).
- When `marketingOptInEnabled`: render a second optional checkbox with `MARKETING_OPTIN_TEXT`.
- Thread both booleans into the confirm/initiate payload.

### 1d. Public mutation (BE — the staging-create path)
- Identify the public mutation that CREATES the `OnlineDonationStaging` row (the initiate-donation public mutation; build agent confirms the exact file — sibling of `ConfirmOnlineDonation.cs` under `OnlineDonationPages/PublicMutations`).
- Accept `consentGiven`, `consentText` (echo), `marketingOptIn` in the input.
- **Server enforce:** load the page's `CONSENT_REQUIRED`; if true and `consentGiven != true`, reject with a validation error (do not create the staging row).
- On create: `ConsentGivenAt = DateTime.UtcNow` (Kind=Utc) when `consentGiven`; `ConsentTextSnapshot = <resolved CONSENT_TEXT at submit>`; `ConsentTextVersion` = page config version stamp; `MarketingOptIn = input.marketingOptIn`.
- **Marketing opt-in propagation:** during B5 promotion / contact resolution, if `MarketingOptIn == true` and the resolved `Contact` supports a marketing-consent field, set it. **Build agent MUST verify Contact has such a field before wiring** — if absent, leave a `// B7: Contact marketing-consent field not present — opt-in captured on staging only` marker and do not invent a column (that would be a second schema change, out of the approved exception).

### 1e. Admin setup (FE — A.1 editor)
- New "Consent & Privacy" card in the admin setup editor writing the CONSENT EAV section via the existing landing-content diff-only save (or a dedicated save command if landing-content save is media-only — reuse the existing path). Fields: enable toggle, statement textarea (with privacy-link helper), required toggle, marketing enable toggle, marketing label.

---

## 2. ISSUE-47b — per-page communication templates (BUILD; EAV + one seed exception)

Fold `onlinedonationpage-ISSUE44-45-47-SPEC.md §47` verbatim, PLUS the new module-seed gotcha below.

- **EAV:** `SectionCode="COMM_TEMPLATES"`, ParamCodes `COMM_RECEIPT` + `COMM_THANKYOU` (`ParamDataType=string`, value = `EmailTemplateCode` upper). Add both to `ManagedParamCodes`.
- **Query** `GetOnlineDonationPageCommTemplates` → `CommTemplatesDto { receiptTemplateCode, thankYouTemplateCode }`.
- **Command** `SaveOnlineDonationPageCommTemplates` — diff-only upsert, `[CustomAuthorize(OnlineDonationPage, Modify)]`.
- **FE picker:** `getEmailTemplates` paginated `GridFeatureRequest` query, filtered by the **Donation `ModuleId`**.
- **⚠ NEW GOTCHA (blocks the picker):** there is **no seeded Donation module**. `auth.Modules` seed (`SeedDatas/AuthService/modules.json`) contains exactly ONE row (`ADMIN`). `EmailTemplate.ModuleId` FKs `auth.Modules`, but no donation module exists to filter by. **Deliverable:** a user-owned seed adding an `auth.Modules` row (fixed Guid, `ModuleCode="DONATION"`) + the receipt/thank-you `notify.EmailTemplates` rows under that `ModuleId` (global `CompanyId=3` defaults, tenant-overridable). I write the seed; user applies. Do NOT reuse Grant's CRM ModuleId. (`DecoratorDonationModules` constants are the `[CustomAuthorize]` taxonomy — a DIFFERENT system, not `auth.Modules`; do not conflate.)
- **ConfirmOnlineDonation upgrade:** resolve the page's `COMM_RECEIPT` → load template (tenant row preferred over global via `OrderBy(t => t.CompanyId==companyId ? 0 : 1)`) → render placeholders (`{{Token}}` + legacy `#KEY#`) → attach the **existing** receipt PDF (from B8, unchanged) → send. If the code is absent/blank or the template load/render fails, fall back to the current hardcoded receipt-email HTML. **Never block confirm.** Same pattern for `COMM_THANKYOU` on the thank-you email.
- **FE tab:** "Communication Templates" editor tab with two template pickers (receipt, thank-you) sourced from `getEmailTemplates` on the Donation module.

---

## 3. ISSUE-43 — optional Aurora enrichment sections (BUILD; EAV + media seeds)

Each enrichment = new EAV Section/Param + `Assemble`/`BuildDefaultRows`/`AssembleLandingContentDto` field
+ Card-9 editor row + (media items) a user-owned seed. All EAV — **no schema change.** Render only when the
backing field is present (graceful omit otherwise). Remove the corresponding `ISSUE-43:` marker comment as
each ships. Markers located at: `template-aurora.tsx:162, 193`; `aurora/ImpactStats.tsx:32, 43`;
`aurora/RichFooter.tsx:220`.

| # | Enrichment | Marker | New EAV param(s) | Seed? |
|---|-----------|--------|------------------|-------|
| A | Mission secondary image | aurora:162 | `MISSION_IMAGE_URL` (url) | media seed |
| B | Mission quote card | aurora:162 | `MISSION_QUOTE_TEXT` (text) + `MISSION_QUOTE_ATTRIB` (string) | no |
| C | Donate-card subtext line | aurora:193 | `DONATE_CARD_SUBTEXT` (text) | no |
| D | Impact donor-avatar cluster + heading | ImpactStats:32 | `IMPACT_TRUST_HEADING` (string) + `IMPACT_TRUST_COUNT` (string) + `IMPACT_AVATARS_JSON` (json: url list) | media seed |
| E | Per-stat icon | ImpactStats:43 | extend the impact-stats item JSON shape with an optional `icon` (Phosphor name) per item — no new top-level param; augment the existing impact-stats param's item schema | no |
| F | Footer tagline paragraph | RichFooter:220 | `FOOTER_TAGLINE` (text) — currently reuses `description` | no |
| G | Second footer link list + website link | (footer) | verify against the recursive FOOTER_TREE (ISSUE-44, built) — "You Can Also Help" list + website leaf may already be expressible as tree nodes; **build agent checks the tree model first** and only adds params if the tree cannot represent them | no |

- Media params (A, D avatars) need a user-owned seed for sample assets ONLY if the tenant wants defaults; otherwise the field stays empty and the section omits. I write the seed; user applies.
- All new params → `ManagedParamCodes` + assembler + Card-9 editor rows. DTO fields added to `OnlineDonationPageDto` (FE) + the landing-content DTO (BE), wire-stable.

---

## 4. DonateFormSection — numbered-step / selected-tile variant (BUILD; additive, pure FE)

**Regression risk is real:** the donate form is a SINGLE flat code path (`components/donation-form.tsx`,
one `<form>` at 899-1305) consumed identically by all **9** templates via `DonateFormSection` (a thin
chrome wrapper in `templates/shared.tsx:124-155`). No `variant`/`numberedSteps`/`accent` prop exists.
An unconditional change regresses all 9.

**Additive design (no regression):**
- Add opt-in prop `layout?: "flat" | "steps"` (default `"flat"`) + `accent?: string` to `DonateFormSection` (`shared.tsx`) and thread both to `DonationForm` (`donation-form.tsx`, `Props` at 41-55).
- Default (`"flat"`, no accent) = today's exact behavior. The 8 non-Aurora call sites pass nothing → unchanged.
- Only `template-aurora.tsx:199` opts in: pass `layout="steps"` + `accent={publicData.primaryColorHex}`.
- When `layout="steps"`: wrap the existing field groups in numbered step headings — **1. Choose Amount** (amount chips + Other), **2. Donor Information** (contact/donor fieldset), **3. Payment Method** — and apply selected-tile-card styling (accent border + soft accent-tint fill) to amount chips (already accent-driven via local `accent` var at 1016-1022 — switch to the prop) and to any selectable payment tiles.
- **Reality check for the build agent:** there are currently **no selectable payment-method tiles** — Braintree Drop-in renders its own UI and Razorpay is a single button (donation-form.tsx:737-897, a phase swap). **Do NOT invent payment tiles.** Apply the numbered-step chrome to what exists; "3. Payment Method" heads the existing payment phase. If a future config exposes selectable methods, the selected-tile styling is ready.
- Pure FE, no schema, no DTO change.

---

## 5. Build sequencing & guardrails for /build-screen

1. **Skip B5 & B8** — verify-only (grep the files named in §0; do not rebuild).
2. **B7 first** (schema exception → user-owned migration must land before consent persistence compiles). Order: EAV config + assembler → staging columns migration SPEC (user runs) → public mutation persist + enforce → FE checkboxes → admin card.
3. **ISSUE-47b** — module seed (user applies) must precede the picker working; the ConfirmOnlineDonation template-resolution upgrade is additive over B8's existing receipt path.
4. **ISSUE-43** — independent EAV enrichments; media seeds user-applied.
5. **DonateFormSection** — pure FE, independent; land alongside the Aurora enrichments.
6. All BE builds must `dotnet build` clean to prove compile. **Never** run EF migration commands — hand the user each migration/seed SPEC. Screen stays **NEEDS_FIX** until the user applies migrations/seeds and re-verifies.
