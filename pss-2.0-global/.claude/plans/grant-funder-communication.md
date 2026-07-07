# Plan — Grant Funder Communication (compose-from-template email + audit history)

## Goal / decisions (locked with user)

Grant lifecycle email. Today the Grant module **only** auto-sends fixed report templates
(`GRANTREPORT_*` in `GrantEmail-sqlscripts.sql`) via `IEmailTemplateService.SendEmailByTemplateKeyForCompanyAsync`.
There is **no compose editor** and passing custom body text is discarded (EmailTemplateService overwrites
`emailDto.EmailContent` from the DB template). We are adding funder communication.

**Model split by audience (locked):**
- **Funder-facing** (fund request, agreement, payment thank-you) → **compose-from-template-draft**: a modal
  pre-fills To (funder email) + Subject + HTML body from a template with grant data merged in; staff **edit
  freely per funder**, then Send. Bespoke per funder, consistent starting point.
- **Internal** (approve/reject, agreement-executed, payment-logged) → **silent auto-send template**
  (mirror existing `SubmitToFunderGrantReport` pattern to BUSINESSADMIN + assigned staff).
- **Communications history** (locked = YES): every send (funder + internal) is recorded in a new
  `GrantCommunication` table and shown in a **Communications tab** on grant detail. Full audit trail.
- **No live "view" link** in funder emails (funders are external, no login) — details are inline.
- **No PDF attachments** (no blob/file storage yet — same constraint as grant attachments). Deferred.

Provider reality: sends go through the tenant's own SendGrid (`notify.CompanyEmailProviders`) — must use the
`...ForCompany...` variant. `{{Token}}` placeholder syntax. Templates are admin-editable via the existing
Email Template screen once seeded.

Backend root: `PSS_2.0_Backend/PeopleServe/Services/Base/`. `case`+`grant`+`app`+`notify` share one
`ApplicationDbContext` (one physical context implementing all `I*DbContext`). Backend is git-ignored — agents
must use `rg --no-ignore` for content search.

---

## 1. Entity — `GrantCommunication` (grant schema)

`Base.Domain/Models/GrantModels/GrantCommunication.cs` (inherits `Entity` → gives IsActive/IsDeleted/
CreatedBy/CreatedDate/ModifiedBy/ModifiedDate — audit fields are **createdDate/modifiedDate**, never *At):
- `GrantCommunicationId` (PK int)
- `GrantId` (int, FK Grant) — **parent, Cascade**
- `CompanyId` (int?)
- `CommunicationType` (string, max 40) — `FUNDREQUEST` | `AGREEMENT` | `PAYMENTRECEIPT` | `APPROVAL` | `REJECTION` | `GENERAL`
- `Direction` (string, max 20) — `OUTBOUND_FUNDER` | `INTERNAL`
- `ToEmail` (string, max 320), `CcEmail` (string?, max 500)
- `Subject` (string, max 500)
- `BodyHtml` (string, column type `text`)
- `TemplateCode` (string?, max 60) — the draft source; null for blank compose
- `RelatedReceiptId` (int?, FK GrantFundReceipt) — **Restrict**, set for payment thank-you
- `SentByStaffId` (int?, FK Staff) — **Restrict**
- `SentDate` (DateTime, UTC)
- `Status` (string, max 20) — `SENT` | `FAILED`
- `ErrorMessage` (string?, max 2000)
- nav: `Grant`, `RelatedReceipt`, `SentByStaff`

Add `public virtual ICollection<GrantCommunication>? Communications { get; set; }` to `Grant.cs`.

**EF config** `Base.Infrastructure/Data/Configurations/GrantConfigurations/GrantCommunicationConfiguration.cs`:
- Grant FK **Cascade** (aggregate child). RelatedReceipt + SentByStaff **Restrict** (avoid multiple cascade paths).
- `BodyHtml` → `.HasColumnType("text")`. Index on `GrantId`. Schema `grant`.
- Register in `GrantDbContext.OnModelCreating` (ApplyConfiguration) as siblings do.

**DbSet**: add `DbSet<GrantCommunication> GrantCommunications { get; }` to `IGrantDbContext` and `GrantDbContext`.

## 2. Ad-hoc (composed) send — additive change to email service

`Base.Application/Data/Services/IEmailTemplateService.cs`:
- Add to `EmailDto`: `public string? Subject { get; set; }` and `public string? CcEmail { get; set; }` (additive; existing callers unaffected).
- Add method: `Task<bool> SendComposedEmailForCompanyAsync(EmailDto emailDto, int companyId);`

`Base.Infrastructure/Services/EmailTemplateService.cs`:
- Implement `SendComposedEmailForCompanyAsync`: **do NOT** look up a template and **do NOT** touch
  `emailDto.EmailContent`. Resolve the tenant PRIMARY→FALLBACK provider exactly like the existing
  `SendEmailByTemplateKeyForCompanyAsync` company block (`notify.CompanyEmailProviders`, JSON
  `SendGridConfiguration`, `DefaultFromEmail/Name`), build `EmailMessage { To=ToEmail, Cc=CcEmail (split on
  ',' if present), Subject=emailDto.Subject, HtmlBody=emailDto.EmailContent, attachments only if
  AttachmentPath set }`, call `emailProvider.SendEmailAsync(message)`. Return bool. **Leave the two existing
  methods byte-for-byte unchanged** — only ADD. Reuse provider-resolution by extracting a private helper OR
  duplicating the small block (duplication is acceptable here to avoid regressing the working template path).

## 3. Helper — `GrantCommunicationHelper` (grant business)

`Base.Application/Business/GrantBusiness/GrantCommunications/GrantCommunicationHelper.cs`:
- `ResolveCrmModuleIdAsync(db, ct)` → `Modules.Where(ModuleCode=="CRM").Select(ModuleId)`.
- `ResolveActorStaffIdAsync(db, httpContext, ct)` → Staff by `UserId == GetCurrentUserId()` & `!IsDeleted`.
- `Merge(string? template, IDictionary<string,string> values)` → replace `{{Token}}` (regex `\{\{\s*(\w+)\s*\}\}`,
  OrdinalIgnoreCase dict, unknown → empty). Self-contained; no coupling to Base.Support PlaceholderEngine.
- `BuildGrantPlaceholdersAsync(db, grantId, ct)` → dict of grant/funder/org tokens (see §6 token list).
- `LogCommunicationAsync(db, row)` → adds a `GrantCommunication` (used by both compose send and internal auto-send).
- `SendInternalNotifyAsync(db, emailSvc, httpContext, logger, grantId, templateCode, communicationType, ct)` →
  best-effort: resolve CRM module + company + BUSINESSADMIN/assigned-staff emails (mirror
  `SubmitToFunderGrantReport.cs:106-128`), auto-send `templateCode` per recipient, then log ONE
  `GrantCommunication` row (Direction=INTERNAL, Status=SENT/FAILED). Wrapped in try/catch — never throws.

## 4. Queries + command — `GrantBusiness/GrantCommunications/`

- **`GetByTemplateQuery/GetGrantEmailDraft.cs`** — `GetGrantEmailDraftQuery(int grantId, string templateCode,
  int? relatedReceiptId)`. Load `notify.EmailTemplates` row by `(EmailTemplateCode==templateCode &&
  ModuleId==CRM && IsActive)` (company row else global CompanyId=3, `IsActive` — match EmailTemplateService
  lookup ordering). Build placeholders via helper (+ receipt tokens when relatedReceiptId set — join
  GrantFundReceipt + financial summary for TotalReceived/Outstanding). Merge subject+body. Return
  `GrantEmailDraftDto { toEmail (funder), subject, bodyHtml, templateCode, communicationType }`. Auth
  `[CustomAuthorize(DecoratorGrantModules.Grant, Permissions.Read)]`.
- **`CreateCommand/SendGrantCommunication.cs`** — `SendGrantCommunicationCommand(GrantCommunicationRequestDto)`.
  Validator: GrantId required + FK, ToEmail required + email format, Subject required, BodyHtml required.
  Handler: resolve company + actorStaffId; call `SendComposedEmailForCompanyAsync`; insert `GrantCommunication`
  (Direction=OUTBOUND_FUNDER, Status = sent?SENT:FAILED, ErrorMessage on failure, SentDate=UtcNow,
  SentByStaffId=actor); `SaveChanges`. **Do not throw on send failure** — return
  `SendGrantCommunicationResult(grantCommunicationId, sent)` so FE can toast success/failure. Auth Create.
- **`GetAllQuery/GetGrantCommunications.cs`** — `GetGrantCommunicationsQuery(int grantId)` → list newest-first
  (`OrderByDescending(SentDate)`), `GrantCommunicationResponseDto` incl `SentByStaffName`. Auth Read.

## 5. Internal auto-send wiring (best-effort, into existing commands)

Add — after the existing `SaveChanges`, in a try/catch that never fails the workflow — a call to
`GrantCommunicationHelper.SendInternalNotifyAsync(...)`. Inject `IEmailTemplateService emailTemplateService`
+ `ILogger<T>` into each handler (constructor-inject, mirror `SubmitToFunderGrantReport`):
- `Grants/UpdateCommand/ApproveGrant.cs`   → template `GRANT_APPROVED_INTERNAL`, type `APPROVAL`.
- `Grants/UpdateCommand/RejectGrant.cs`    → template `GRANT_REJECTED_INTERNAL`, type `REJECTION`.
- `Grants/UpdateCommand/ActivateGrant.cs`  → template `GRANT_AGREEMENT_INTERNAL`, type `AGREEMENT`.
- `GrantFundReceipts/CreateCommand/CreateGrantFundReceipt.cs` → template `GRANT_PAYMENT_LOGGED_INTERNAL`,
  type `PAYMENTRECEIPT`. Call it AFTER `strategy.ExecuteAsync(...)` completes (outside the txn), best-effort.
No mutation signatures change; these are pure side effects.

## 6. Seed — extend `sql-scripts-dyanmic/GrantEmail-sqlscripts.sql`

Append (idempotent `WHERE NOT EXISTS`, CompanyId=3 global, ModuleId=CRM subquery, EmailCategory reuse
`GRANTREPORTEMAIL`, `{{Token}}` HTML mirroring the existing report-template styling). Templates:

**Funder draft sources (compose):**
- `GRANTAPPLICATION_TO_FUNDER` — subject `Grant Application: {{GrantTitle}}`. Tokens: `{{FunderContactPersonName}}`,
  `{{GrantTitle}}`, `{{GrantCode}}`, `{{RequestedAmount}}`, `{{CurrencyCode}}`, `{{ExecutiveSummary}}`,
  `{{OrganizationName}}`, `{{SubmittedDate}}`.
- `GRANT_AGREEMENT_FUNDER` — tokens: `{{FunderContactPersonName}}`, `{{GrantTitle}}`, `{{AwardedAmount}}`,
  `{{CurrencyCode}}`, `{{AgreementSignedDate}}`, `{{StartDate}}`, `{{EndDate}}`, `{{OrganizationName}}`.
- `GRANT_PAYMENT_THANKYOU` — tokens: `{{FunderContactPersonName}}`, `{{GrantTitle}}`, `{{ReceiptCode}}`,
  `{{Amount}}`, `{{CurrencyCode}}`, `{{PaymentMethod}}`, `{{ReceivedDate}}`, `{{TotalReceived}}`,
  `{{OutstandingAmount}}`, `{{OrganizationName}}`.

**Internal auto templates:** `GRANT_APPROVED_INTERNAL`, `GRANT_REJECTED_INTERNAL`, `GRANT_AGREEMENT_INTERNAL`,
`GRANT_PAYMENT_LOGGED_INTERNAL` — tokens `{{RecipientName}}`, `{{GrantTitle}}`, plus amount/decision tokens
(`{{AwardedAmount}}`, `{{RejectionReason}}`, `{{AgreementSignedDate}}`, `{{ReceiptCode}}`, `{{Amount}}`).

## 7. GraphQL + schemas + mappings

- `Base.Application/Schemas/GrantSchemas/` (new `GrantCommunicationSchemas.cs`): `GrantEmailDraftDto`,
  `GrantCommunicationRequestDto` (grantId, toEmail, ccEmail?, subject, bodyHtml, communicationType,
  templateCode?, relatedReceiptId?), `GrantCommunicationResponseDto` (+ sentByStaffName, statusCode).
- `GrantMappings.cs` — `GrantCommunication` → ResponseDto (SentByStaffName via SentByStaff.DisplayName).
- `Base.API/EndPoints/Grant/Queries/GrantQueries.cs` — `GetGrantEmailDraft(grantId, templateCode,
  relatedReceiptId)`, `GetGrantCommunications(grantId)`.
- `Base.API/EndPoints/Grant/Mutations/GrantMutations.cs` — `SendGrantCommunication(communication)` → BaseApiResponse<...>.

## 8. Migration

Generate `Add_GrantCommunication` (new table only). **Generate, do NOT apply** (user applies with
`dotnet ef database update`). Build must be clean (0 errors), no DLL lock issues.

## 9. Frontend

- DTOs `domain/entities/grant-service/`: `GrantCommunicationDto.ts`, `GrantEmailDraftDto.ts`,
  `GrantCommunicationRequestDto.ts` (+ index export).
- GraphQL: `gql-queries/grant-queries/GrantCommunicationQuery.ts` (getGrantEmailDraft, getGrantCommunications),
  `gql-mutations/grant-mutations/GrantCommunicationMutation.ts` (sendGrantCommunication) + index edits.
- **Compose modal** `crm/grant/grantlist/grant/grant-email-compose-modal.tsx`:
  - Props: `grantId`, `defaultTemplateCode?`, `relatedReceiptId?`, `onSent?`, `afterSendAction?` (async cb for
    the stage transition on Send-to-Funder).
  - Template picker (Fund Request / Agreement / Payment Thank-you / Blank). On pick (and on open with
    defaultTemplateCode) → `getGrantEmailDraft` → fill To/Subject/Body.
  - Fields: To (editable, pre-filled from draft/`grant.funderContactEmail`), Cc (optional), Subject
    (FormInput), Body — **reuse the existing rich-text editor** at
    `@/presentation/components/custom-components/editors/email-template-editor` (same one the Email Template
    screen uses). Send → `sendGrantCommunication`; on `result.sent` toast success, call `afterSendAction?.()`
    + `onSent?.()`. Amount/detail display follows token conventions; no raw hex/px (design tokens).
- **Wire actions** in `crm/grant/grantlist/grant/grant-detail.tsx` (+ `workflow-modals.tsx`):
  - **Send to Funder** action → opens compose modal with `GRANTAPPLICATION_TO_FUNDER`; `afterSendAction` calls
    existing `sendGrantToFunder(grantId, notes)` to transition APPLICATION→UNDERREVIEW after the email sends.
    (Replaces the plain SendToFunderModal.)
  - **Email Funder** (generic, More menu) → compose modal, Blank default, no stage change.
  - **Email Agreement to Funder** (visible on Approved/Active) → compose modal `GRANT_AGREEMENT_FUNDER`.
  - **Funds Received tab** row action **Email Receipt to Funder** → compose modal `GRANT_PAYMENT_THANKYOU`
    with `relatedReceiptId`.
  - **Communications tab** (new) → `getGrantCommunications` table: Type chip + Direction, To, Subject,
    Sent By, Sent At, Status chip (solid bg + white per UI memory). Row → read-only dialog rendering
    `bodyHtml` (sanitize/`dangerouslySetInnerHTML` in a sandboxed container). Empty state when none.
- tsc must stay clean (ignore the pre-existing donation-service `PaymentMethodCode` TS2308).

## 10. Verification

- BE: full `dotnet build` 0 errors; migration generates; `SendComposedEmailForCompanyAsync` does not alter
  existing template-send behavior; internal auto-sends are best-effort (never fail workflow); UTC on SentDate.
- FE: `npx tsc --noEmit` clean; compose modal loads draft, edits, sends; Communications tab lists history;
  solid-bg chips; reuse of existing editor.
- E2E: Send-to-Funder → edit draft → send → email logged + stage moved; Approve → internal notify logged;
  receipt → internal notify logged + optional funder thank-you; Communications tab shows all.

## Deferred
PDF attachments (needs blob/file storage); scheduled/bulk funder emails; funder portal + live view links;
per-template PlaceholderDefinition catalog rows (compose merge is self-contained).
