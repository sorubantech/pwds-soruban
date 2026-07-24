# Contact Screen (#18) — 1:1 Communication Plan + Production Readiness Review

> Date: 2026-07-23 · Screen: #18 Contact · Type: FLOW · Scope: ALIGN · Status: COMPLETED (19 open issues)
> This document is **planning + assessment only**. No code was changed producing it.

---

# PART A — One-on-One Communication Service Plan

## A1. Problem statement

Today the Contact screen can *display* communication but cannot *perform* it:

| Surface | Today | Gap |
|---|---|---|
| `contact-sidebar.tsx:215,224,233` | `tel:` / `mailto:` / `https://wa.me/` deep links | Hands off to the OS. No consent check, no template, no audit row, no delivery status. |
| `detail/tabs/communication-tab.tsx` | Read-only `EmailSendQueue` list, email only, 100-row cap | No SMS, no WhatsApp, no compose, no pagination. |
| `list/bulk-actions-bar.tsx:30` | `toast.info("Bulk Send Email — not yet available")` | Placeholder. |

Meanwhile the **service layer already exists and is proven in other screens** — this is an integration job, not greenfield:

| Channel | Existing service | Proven in |
|---|---|---|
| Email | `IEmailTemplateService.SendComposedEmailForCompanyAsync(EmailDto, companyId)` | Grant funder comms (#62), Email Campaign (#25) |
| SMS | `ISmsSenderService.SendSingleAsync(companyId, toPhone, body, ct)` → `SmsSendServiceResult` | SMS Campaign (#30), SMS Setup (#157) |
| WhatsApp | `IWhatsAppSenderService.SendTextAsync(companyId, toPhone, body, ct)` → `WhatsAppSendResult` | WhatsApp Conversations (#33) — **already `ContactId`-linked** |
| Templates | `TemplatePlaceholderRenderer`, Email/SMS/WhatsApp Template screens (#24/#29/#31) | COMPLETED |

The reference implementation to clone is `SendGrantCommunication.cs` — send-then-log, never throw on provider failure, return `(id, sent)` and let the FE toast.

## A2. Design decision — one log table, three channels

Add **`contact.ContactCommunications`**, modelled on `GrantCommunication` but channel-agnostic. Rationale:

- The three channels have *different* natural stores today (`EmailSendQueue` for email, nothing for SMS, `WhatsAppMessage` for WhatsApp). A per-contact timeline that has to UNION three shapes at read time is slow and brittle.
- One append-only log row per outbound 1:1 attempt gives the Communication tab a single sorted source, and keeps the channel-native stores as the delivery-detail drill-down.
- It is also the **consent audit record** — proof of why a send was allowed or blocked, which is the compliance requirement (GDPR Art. 7(1), PDPA, CAN-SPAM record-keeping).

### Entity spec (migration is user-owned — spec only)

```csharp
[Table("ContactCommunications", Schema = "contact")]
public class ContactCommunication : Entity
{
    public int ContactCommunicationId { get; set; }
    public int ContactId { get; set; }
    public int? CompanyId { get; set; }

    public string Channel { get; set; }        // EMAIL | SMS | WHATSAPP
    public string Direction { get; set; }      // OUTBOUND | INBOUND
    public string? Purpose { get; set; }       // free code: FOLLOWUP | THANKYOU | RECEIPT | ...

    public string ToAddress { get; set; }      // email or E.164 phone
    public string? CcEmail { get; set; }
    public string? Subject { get; set; }       // EMAIL only
    public string Body { get; set; }
    public string? TemplateCode { get; set; }

    public int? ContactEmailAddressId { get; set; }
    public int? ContactPhoneNumberId { get; set; }
    public int? EmailSendQueueId { get; set; } // drill-down to open/click/bounce
    public int? WhatsAppMessageId { get; set; }
    public int? RelatedEntityId { get; set; }  // optional: donation/case/event
    public string? RelatedEntityType { get; set; }

    public int? SentByStaffId { get; set; }
    public DateTime SentDate { get; set; }     // DateTime.UtcNow — Kind=Utc mandatory
    public string Status { get; set; }         // SENT | FAILED | BLOCKED
    public string? BlockedReason { get; set; } // DO_NOT_EMAIL | DO_NOT_SMS | NO_ADDRESS | OPTED_OUT
    public string? ProviderMessageId { get; set; }
    public string? ErrorMessage { get; set; }

    public virtual Contact? Contact { get; set; }
    public virtual Staff? SentByStaff { get; set; }
}
```

**Indexes**: `(CompanyId, ContactId, SentDate DESC)` — the tab's only read path; `(CompanyId, SentByStaffId, SentDate)` for the staff-activity report later.

> Note the scope conflict: screen #18 is registered **ALIGN**, and per project rule ALIGN forbids entity-level changes/migrations. Adding this table means #18's comms work must be re-planned as a **FULL**-scope increment via `/plan-screens #18`, not delivered through `/continue-screen`. Flagged, not assumed.

## A3. Backend commands (3 + 1 query)

All follow the `SendGrantCommunication` shape: validate → resolve consent → send → log → return `(id, sent)`.

```
SendContactEmailCommand(ContactCommunicationRequestDto)   → (id, sent)
SendContactSmsCommand(ContactCommunicationRequestDto)     → (id, sent)
SendContactWhatsAppCommand(ContactCommunicationRequestDto) → (id, sent)
GetContactCommunicationsQuery(GridFeatureRequest)          → paged log
```

Consolidating into one `SendContactCommunicationCommand(Channel, …)` is tempting but rejected: validators would need conditional rule sets (Subject required for EMAIL only, E.164 for SMS/WhatsApp only, 1600-char cap for SMS only), which reads worse than three small validators.

### Shared pre-send guard (the important part)

```
1. Resolve contact (tenant-filtered by the global query filter — no extra predicate needed).
2. Consent gate:
     EMAIL    → block if contact.DoNotEmail
     SMS      → block if contact.DoNotSms   (fall back to DoNotCall if DoNotSms absent)
     WHATSAPP → block if conversation.OptOutAt != null || contact.DoNotSms
   On block: write a ContactCommunication row with Status=BLOCKED + BlockedReason,
   return sent=false. Never call the provider. The blocked row IS the compliance evidence.
3. Address resolution: prefer the contact's IsPrimary email/phone; if the caller passed an
   explicit ContactEmailAddressId/ContactPhoneNumberId, verify it belongs to this contact
   (else NotFoundException — prevents address-injection via a foreign child id).
4. Phone normalisation to E.164 using the contact's country dial code (reuse the #33 helper);
   BLOCKED/NO_ADDRESS if it can't be normalised.
5. Rate guard: max N sends per (ContactId, Channel) per rolling hour, N from
   OrganizationSettings (default 10). Exceeded → Status=BLOCKED, BlockedReason=RATE_LIMIT.
6. Send via the channel service inside try/catch. Never rethrow — Status=FAILED + ErrorMessage.
7. Log row, then return.
```

### Validator caps (mirror the provider limits)

| Field | Cap | Source |
|---|---|---|
| `ToAddress` (email) | 320 + `.EmailAddress()` | RFC / GrantCommunication |
| `Subject` | 500 | GrantCommunication |
| `Body` — EMAIL | 100,000 | practical HTML ceiling |
| `Body` — SMS | 1600 | `SendSmsValidator` (10 segments) |
| `Body` — WhatsApp | 4096 | Meta API limit |
| `TemplateCode` | 60 | GrantCommunication |
| `Purpose` | 40 | new |

### Channel-specific wiring

- **Email** — build `EmailDto{ToEmail, CcEmail, Subject, EmailContent}` → `SendComposedEmailForCompanyAsync`. If the service returns the queue id, store it in `EmailSendQueueId` so the tab can join open/click/bounce. If it doesn't, follow-up: set `EmailSendQueue.ContactId` at enqueue time (the column already exists, line 11) and correlate on `ProviderMessageId`.
- **SMS** — `SendSingleAsync`, map `SmsSendServiceResult.ProviderMessageId/Status/ErrorMessage/Cost`. **Also fix the existing gap**: `SendSmsCommand` today persists *nothing* and carries no `ContactId`, so all SMS is invisible to reporting. The contact path must not repeat that.
- **WhatsApp** — do **not** duplicate #33. Call the existing `SendOutboundWhatsAppMessage` command (get-or-create conversation by `ContactId`+phone, respects the 24h `ReplyWindowExpiresAt`), then write the `ContactCommunication` mirror row with `WhatsAppMessageId`. Outside the 24h window, only approved templates may be sent — surface that in the UI as "session expired, choose a template".

## A4. Frontend

**1. Compose drawer** — `detail/communication/compose-drawer.tsx`, one component, channel tabs (Email / SMS / WhatsApp):
- Channel tab **disabled with a reason tooltip** when consent blocks it or no address exists — the block must be visible *before* the user types, not after they hit send.
- Recipient = select over the contact's own emails/phones, primary preselected. Never free-text (kills typo-sends and address injection).
- Template picker → `TemplatePlaceholderRenderer` preview, staff-editable after insert (same pattern as grant funder comms).
- Live character counter with segment count for SMS (`ceil(len/160)` GSM-7, 70 for unicode) — cost is per segment, users must see it.
- Send button disabled until RHF `formState.isValid` (per project rule — not gated on capability).
- Optimistic-free: await the mutation, toast success/failure from `sent`, then refetch the tab.

**2. Communication tab rewrite** — union view over `ContactCommunications`, server-paged (25/page), channel filter chips, expandable row → delivery detail (opens/clicks for email, provider status for SMS, thread link for WhatsApp). Fixes the current 100-row cap and the email-only limitation. Badge tones must use solid `bg-X-600` + `text-white` per project rule — the current tab violates it (`bg-emerald-100 text-emerald-700` etc.).

**3. Sidebar quick actions** — replace `mailto:`/`tel:`/`wa.me` hrefs with buttons that open the compose drawer on the matching channel. Keep `tel:` for Call (there is no telephony service to route through) but log a `ContactCommunication{Channel=CALL, Direction=OUTBOUND, Status=SENT}` row on click so call attempts appear in the timeline. Show the consent flag as a hard-disabled state, not just an icon.

**4. Bulk** — out of scope for 1:1. `bulk-actions-bar` should route to the Email Campaign screen (#25) with the selected ids preloaded rather than growing its own send path.

## A5. Delivery slices

| Slice | Content | Est. |
|---|---|---|
| **S1** | Entity + migration spec + `SendContactEmailCommand` + `GetContactCommunicationsQuery` + compose drawer (Email tab only) + tab rewrite | 2–3 d |
| **S2** | SMS command (+ persist/log fix for the shared SMS path) + SMS tab + segment counter | 1–2 d |
| **S3** | WhatsApp command delegating to #33 + thread link + 24h-window UX | 1–2 d |
| **S4** | Sidebar rewiring, call logging, rate-limit setting, bulk redirect to #25 | 1 d |

Dependencies: #34 WhatsApp Setup is **PARTIAL** — S3 cannot be verified end-to-end until it completes. Email requires a configured `CompanyEmailProvider`; SMS requires #157 provider credentials per tenant.

**Test sends are outward-facing.** No real email/SMS/WhatsApp will be sent from a dev session without explicit per-run authorization; verification should use a provider sandbox/test number.

---

# PART B — Contact Screen Production Readiness Review

Evidence base: prompt file §⑬ (24 issues, 19 OPEN), `CreateContact.cs` (409 ln), `UpdateContact.cs` (543 ln), `GetContact.cs`, `GetContactById.cs`, `ExportContact.cs`, `contact-validation-schemas.ts` (591 ln), the detail/form/list component tree, `ApplicationDbContext.ApplyTenantFilters`.

## B1. MVP Readiness

**Complete: ~82%.** The core is genuinely done and is the strongest part of the screen.

Working: multi-base-type contact model (Individual / Organization / Household) with per-type required fields; 8 child collections (emails, phones, addresses, social links, relationships, purposes, tags, custom fields) creating and updating transactionally under `CreateExecutionStrategy()`; DisplayName auto-generation; `IsDeceased`→`DeceasedDate` and `DoNotEmail`→opt-in/opt-out date coupling; grid with quick chips, advanced filter, server paging/sort; three URL modes (new / edit / read-only detail); detail tabs; sidebar summary; RBAC decorators on every command and query; tenant isolation via a global EF query filter.

Pending, split by whether it blocks MVP:

| Item | Issue | Blocks MVP? |
|---|---|---|
| `LocalityId` not synced in the Update diff → **silent data loss on edit** | ISSUE-19 | **YES** |
| `tagIds` advanced filter is inert (no `Contact.ContactTags` navigation) — UI present, does nothing | ISSUE-21 | **YES** (visible broken control) |
| Export is a 6-field stub + grid validation commented out | ISSUE-9, new | **YES** if export is user-facing; else defer |
| Bulk actions are 4 toasts | §⑫ | **YES** (visible broken control) |
| No client-side email/phone format validation | new | **YES** — cheap, high value |
| Engagement score fully stubbed | ISSUE-3 | No — hide the widget |
| Timeline cross-entity aggregation missing | ISSUE-4 | No — hide the tab |
| 1:1 comms (Part A) | new | No — Phase 2 |
| Merge navigation to #21 | ISSUE-6 | No |
| Card-grid list variant | ISSUE-10 | No |
| ~15 dead legacy wizard files | ISSUE-18 | No — cleanup |
| `SearchableSelect` primitive missing (plain `<select>` in Sections 5/6) | ISSUE-17 | No, unless a lookup exceeds ~50 options |

**MVP verdict: yes, after the five YES rows.** That is roughly 3–4 days of work, not a re-architecture.

## B2. Production Readiness

| Dimension | Assessment |
|---|---|
| Functional completeness | Strong for CRUD. Weak at the edges: export stub, bulk stubs, two stubbed features still visible in the UI. |
| Stability | Good. Execution strategy + transaction on create/update; child collections initialised; no known crashes in the log. |
| Error handling | BE consistent (`NotFoundException` / `InternalServerException` wrapping `DbUpdateException`). FE relies on generic mutation toasts — field-level server-error mapping is absent, so a BE validation failure shows a banner, not a highlighted field. |
| Validation | **Asymmetric.** BE is thorough (FK existence, required-by-type, string lengths). FE Zod has required rules but **zero** `.email()` and **zero** `.max()` — a 5,000-char first name or `not-an-email` reaches the server and bounces back as a generic error. Only HTML `type="email"` / `maxLength` attributes exist, which are not enforcement. |
| Performance | Grid is server-paged — fine. Detail loads 8 child collections in one query — acceptable at contact scale. Communication tab pulls 100 rows unpaginated. No N+1 observed. |
| Security | Tenant isolation **is** enforced globally in `ApplicationDbContext.ApplyTenantFilters` (JWT `CurrentTenantId`; null = SuperAdmin). RBAC decorators present on all commands/queries. Gap: `GetContactById` lacks `[RequiresTenant]`/`[TenantScope]` that its siblings carry — currently harmless because of the global filter, but it is the one place the defense is single-layered, and a future `IgnoreQueryFilters()` or a raw-SQL path would silently expose PII. Second gap: `ExportContact` has `ValidateGridFeatures(...)` commented out (line 27) — unvalidated sort/filter input on a bulk-PII endpoint. |
| UX | Solid layout, consistent with the mockup. Dead controls (bulk toasts, inert tag filter, stubbed score) are the main credibility cost. |
| Accessibility | Not audited. Table lacks scope/caption semantics; badge colour is the sole status signal in the communication tab (fails WCAG 1.4.1); no verified focus-trap on drawers. |
| Reliability | No retry/idempotency on create — a double-click or network retry can produce duplicate contacts. No dedupe check on email/phone at create time. |

**Approve for production? Conditionally — no, not as-is.** Two things block it: ISSUE-19 (silent data loss on edit is the kind of bug that erodes trust in the whole system and is unrecoverable without audit history) and the visible dead controls. Neither is deep. With those fixed plus client-side format validation, yes.

## B3. Enterprise Feature Review (only what earns its keep)

| Feature | State | Recommend |
|---|---|---|
| Input validation | BE strong, FE weak | **Add** Zod `.email()`, `.max()` mirroring BE caps, phone regex. ~2h, highest value-per-hour on the screen. |
| Required-field handling | Present, per base type | Keep |
| Success/error messages | Generic toasts | **Add** server-error→field mapping on the form |
| Loading indicators | Shaped skeletons present | Keep |
| Empty states | Present and well-written | Keep |
| Offline handling | None | **Skip** — internal CRM, not field-mobile. Over-engineering. |
| Rate limiting / spam | None | **Add** only for the Part A send path. Not needed for CRUD. |
| Contact reason/category | Covered by ContactType + purposes | Keep |
| Attachments | None | **Defer** — blocked on blob storage anyway (see grant-attachment precedent) |
| Character limits | HTML only | **Add** to Zod (see validation) |
| Email/phone validation | Missing client-side | **Add** |
| Duplicate detection | None | **Add (medium)** — a "possible duplicate" warning on matching email/phone at create. In a CRM, duplicate contacts are the #1 long-term data-quality failure and are expensive to unwind later. |
| Audit logging | `Entity` base gives created/modified stamps | **Add field-level history for consent flags only** (`DoNotEmail`/`DoNotSms`) — that is a legal record. Full field history is over-engineering for MVP. |
| Analytics/event tracking | None | Skip for MVP |
| Localization | `[lang]` routing + localizer in BE | Keep; audit hard-coded strings later |
| WCAG | Unaudited | **Add** the cheap wins: table semantics, non-colour status cue, labelled icon buttons, focus states |
| Responsive | xs→xl claimed, unverified on the detail tabs | **Verify** on a real device before release |
| Feedback mechanisms | Toasts | Sufficient |

## B4. Real-World Usage

- **Support workflows** — a support agent opening a contact cannot see *why* the last email bounced or whether anyone called. Part A closes this; it is the single biggest real-world gap.
- **Admin processing** — merge/dedupe is deferred to #21 and not linked from #18 (ISSUE-6). In practice duplicates get created during the first import and never resolved. Ship at least the duplicate warning.
- **Edge cases** — deceased contacts still receive campaign email unless `DoNotEmail` is manually set (no automatic suppression on `IsDeceased`); household head reassignment when the head is deleted is unverified; a contact with no email and no phone is creatable and then unreachable.
- **High traffic** — grid is paged; the risk is the export path (unvalidated, unbounded row count). Add a max-row guard as with REPORT screens.
- **Error recovery** — no draft persistence on the long create form; a session timeout mid-form loses everything. Worth a local-storage draft only if the form is genuinely long in practice.
- **Abuse prevention** — export of full contact PII is permission-gated but unlogged. **Log every export** (who, filter, row count). This is a common auditor request and cheap now.
- **Compliance** — consent flags exist and are displayed but are not *enforced* anywhere: the sidebar `mailto:`/`wa.me` links work regardless of `DoNotEmail`. That is a real GDPR/PDPA exposure today, before any of Part A ships.
- **Maintainability / scalability** — file structure is clean and consistently organised; the 543-line `UpdateContact` diff handler is the one hotspot (ISSUE-19 lives there and the next such bug will too). Worth extracting per-collection diff helpers when it is next touched.

## B5. UI/UX

Good: clear hierarchy (header → sidebar summary → tabbed body), mockup-faithful layout, consistent token usage in most components, sensible section grouping in the form, well-written empty states.

Fix:
1. **Remove or hide dead controls** — a toast saying "not yet available" is worse than no button. Stubbed engagement score and empty timeline likewise.
2. **Communication tab badges** violate the project's own solid-`bg-X-600`/`text-white` rule and rely on colour alone. Fix both together.
3. **Consent state must be actionable, not decorative** — grey out Email/WhatsApp actions when opted out, with a tooltip.
4. **Plain `<select>` for large lookups** (ISSUE-17) becomes unusable past ~50 options; countries alone exceed that. Build the `SearchableSelect` primitive.
5. **Mobile** — the detail page's sidebar + tabs need verification at xs; the 5-column communication table needs a card fallback.
6. **Form length** — consider a sticky save bar so the primary action is always reachable on long forms.

## B6. Technical Review

| Area | Verdict |
|---|---|
| Maintainability | Good. CQRS one-file-per-operation, predictable naming, Zustand store split into 6 focused sub-stores. `UpdateContact.cs` at 543 lines is the exception. |
| Component structure | Good — form sections, detail tabs, list config cleanly separated. ~15 dead legacy wizard files (ISSUE-18) should be deleted; they will mislead the next developer. |
| API integration | Standard `useGenericQuery` + advanced-filter payload. One unvalidated assumption: `EmailSendQueue.contactId` is filterable server-side (ISSUE-24) — the column exists, but the query-builder allow-list is unverified. If it isn't allowed, the tab silently shows *all* tenants' rows the filter fails open. **Verify this before release** — it is a silent-leak shape, not just a bug. |
| Validation strategy | Split-brain (see B2). Unify by generating Zod caps from the BE limits or at minimum mirroring them by hand once. |
| State management | Reasonable. Watch for over-fetch: `fetchPolicy: "cache-and-network"` on every tab means a tab switch re-hits the network. |
| Performance | Acceptable. Add pagination to the communication tab and a max-row guard to export. |
| Security | See B2 — restore `ValidateGridFeatures` in `ExportContact`, add the missing tenant attributes to `GetContactById` for defense-in-depth, log exports. |
| Error handling | BE consistent; FE needs field-level server-error mapping. |
| Logging | Effectively none at the business level. Add for: export, consent-flag changes, and (Part A) every send attempt. |
| Testing readiness | No tests. The highest-return targets are `UpdateContact`'s collection-diff logic (where ISSUE-19 lives) and the create validators. A dozen handler tests would have caught the LocalityId bug. |

## B7. Risk Assessment

### Critical — fix before production
1. **ISSUE-19 — `LocalityId` dropped in the Update diff.** Silent, unrecoverable data loss on ordinary edits.
2. **Consent flags not enforced.** `mailto:`/`wa.me` links fire regardless of `DoNotEmail` — live compliance exposure.
3. **`ExportContact` grid-feature validation commented out** (line 27) on a bulk-PII endpoint, with no row cap and no audit log.
4. **ISSUE-24 unverified** — if `contactId` isn't in the server-side filter allow-list, the communication tab fails *open*. Must be confirmed by a real API call, not by inspection.
5. **Visible dead controls** — 4 toast-only bulk actions, inert tag filter (ISSUE-21). Ship-blocking for credibility, cheap to hide.

### Medium — before launch if time permits
6. Client-side email/phone/length validation (~2h, disproportionate value).
7. `GetContactById` missing `[RequiresTenant]`/`[TenantScope]` — defense-in-depth.
8. Communication tab: pagination + badge-token fix + non-colour status cue.
9. Duplicate-contact warning at create.
10. Consent-flag change history (legal record).
11. Field-level server-error mapping on the form.
12. Export audit log + max-row guard.

### Low — post-MVP
13. Engagement score (ISSUE-3), cross-entity timeline (ISSUE-4) — hide until built.
14. Part A 1:1 communication (Phase 2 feature, not a defect).
15. `SearchableSelect` primitive (ISSUE-17), merge navigation (ISSUE-6), card-grid variant (ISSUE-10).
16. Dead-code deletion (ISSUE-18), `CREATE` mutation legacy-arg cleanup (ISSUE-23), chip filter by code not name (ISSUE-22), DTO typing (ISSUE-20, ISSUE-16), household DTO-only fields (ISSUE-2), OrgUnit semantics (ISSUE-1).
17. Handler unit tests, WCAG audit, draft persistence.

## B8. Final Recommendation

- **Overall completion: 82%**
- **MVP readiness: 7.5 / 10** — core is done; the blockers are shallow.
- **Production readiness: 6 / 10** — one data-loss bug, one compliance gap, one unvalidated bulk-PII endpoint.
- **Enterprise readiness: 6 / 10** — RBAC and tenancy are right; validation symmetry, audit logging, duplicate control and comms are missing.
- **UI/UX: 7 / 10** — well structured and mockup-faithful; dead controls and token/contrast violations pull it down.

**✅ Can this screen be released as part of the MVP?**
Yes — after the five Critical items. They are ~3–4 days, not a redesign.

**✅ Can it be safely deployed to production?**
Not today. ISSUE-19 alone disqualifies it: users lose data during normal editing and never find out. Add the unenforced consent flags and the unvalidated export endpoint and the answer is a clear no. After Critical 1–5, yes.

**✅ Will missing items significantly impact users or business operations?**
Three will. (a) ISSUE-19 corrupts address data silently — the damage compounds daily and is unrecoverable. (b) Unenforced consent is a regulatory and reputational exposure, not an inconvenience. (c) No 1:1 communication means every outreach happens outside the system, so the CRM's activity history is permanently incomplete — which is the main reason organisations buy a CRM. (a) and (b) block release; (c) is a Phase 2 commitment that should be on the roadmap before launch, not after.

**✅ What must be fixed before release?**
ISSUE-19 · consent enforcement on sidebar actions · restore `ValidateGridFeatures` in `ExportContact` + row cap + export audit log · verify ISSUE-24 with a live call · hide/remove the 4 bulk stubs, the inert tag filter, the engagement score, and the empty timeline.

**✅ What can wait until after the MVP?**
Part A 1:1 communication · engagement score and timeline (built properly, not stubbed) · duplicate detection · `SearchableSelect` · merge navigation · card-grid variant · dead-code cleanup · full WCAG audit · handler test suite · analytics.

---

## Recommended sequencing

1. **Now (3–4 d)** — Critical 1–5. Ship MVP.
2. **Next sprint (2–3 d)** — Medium 6–12. This is where the screen becomes genuinely enterprise-grade.
3. **Phase 2 (5–8 d)** — Part A slices S1→S4, re-planned as FULL scope via `/plan-screens #18`.
4. **Backlog** — Low 13–17.
