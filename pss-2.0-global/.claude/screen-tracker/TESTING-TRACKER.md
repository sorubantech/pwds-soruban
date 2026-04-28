# PSS 2.0 — Screen Testing Tracker

> Manual E2E business-flow testing for all **46 COMPLETED** screens.
> Test role: **BUSINESSADMIN** (no role-permission re-prompting).
> Each task scope = one screen, end-to-end through its happy path + the documented edge cases.

---

## Status legend

| Status | Meaning |
|--------|---------|
| ⬜ `NOT_TESTED` | Hasn't been touched yet. |
| 🔄 `IN_TESTING` | Tester started; partial pass. |
| ✅ `PASSED` | Full happy path + edge cases verified, no blocker bugs. |
| ⚠ `ISSUES_FOUND` | Functional bugs raised — log against `prompts/{screen}.md` ISSUE list. |
| ❌ `FAILED` | Major regression / blocker; screen unusable. |

---

## How to test (apply to every screen)

For every task, walk this order:

1. **Layout & UI uniformity** — Variant B (`ScreenHeader` at page root + `showHeader={false}` on the data-table container; for card-grids: ScreenHeader + CardGrid). KPI widgets render with skeletons → real data. No inline hex/px. Phosphor (`ph:*`) icons only — no `fa-*`. Responsive at 375 / 768 / 1280 / 1920.
2. **Filters & search** — chip filters, URL persistence, advanced-filter panel apply/clear, search debounce, sort headers, page-size + pagination. Reload preserves state.
3. **CRUD round-trip** — Add → confirm row appears → View → Edit → confirm change persists → Delete (or Toggle) → confirm gone or hidden. Validation errors on bad input. Required-field messages.
4. **Workflow transitions** — every documented status command (Approve/Reject/Pause/Resume/Cancel/Close/etc.) fires from the right context (row action, modal, or kebab) with the correct guards/confirm dialog. Confirm DB state + UI badge update.
5. **Related-entity navigation** — links into FK targets resolve (e.g. donor link → Contact, beneficiary link → Beneficiary). Back navigation preserves grid filters.
6. **Empty / loading / error states** — empty grid renders empty-state card, loading shows shaped skeletons (not spinners), failed mutation shows toast.
7. **Bulk ops** (where applicable) — multi-select + bulk action runs against all selected rows.
8. **Service placeholders** — confirm the toast/disabled state is graceful (don't expect them to work).
9. **Regression check** — verify a sibling/dependent screen still renders OK (e.g. after testing #18 Contact, open #20 Family).

Log functional bugs against the prompt file's ISSUE list (e.g. `prompts/contact.md` → ISSUE-N). Log generic platform bugs in REGISTRY notes.

---

## Tasks (46)

> Grouped by module to match REGISTRY.md. Tick the status column as you go.

### Fundraising (7)

| # | Task | Status | Description |
|---|------|--------|-------------|
| 1 | Testing - Donation (Global) screen business flow | ⬜ | Variant B FLOW with summary widgets + distribution grid + receipt modal. Verify: list/filter, full FORM round-trip, view-page summary widgets, distribution grid, receipt modal generation, donor link to Contact #18, currency rendering across multi-currency rows. |
| 2 | Testing - Donation Purpose screen business flow | ⬜ | MASTER_GRID with TargetRaisedProgress renderer + nullable group/category. Verify: list/filter, Add/Edit/Delete via modal, RaisedAmount aggregation column, link-count to donations, validation when Group/Category nullable, OrgUnit FK dropdown. |
| 3 | Testing - Donation Category screen business flow | ⬜ | MASTER_GRID with FK to DonationGroup. Verify: list/filter, Add/Edit/Delete, Group dropdown cascade, link-count to purposes, color badge rendering, soft-delete behaviour. |
| 4 | Testing - Donation Group screen business flow | ⬜ | MASTER_GRID parent of categories. Verify: list/filter, Add/Edit/Delete, CategoriesCount post-projection, color rendering, link-count to categories, soft-delete + reactivate. |
| 6 | Testing - Cheque Donation screen business flow | ⬜ | FLOW + 6-section RHF form + 4-column kanban view + 3 status-transition modals. Verify: Add (auto-resolve ChequeStatus=REC + DonationMode=CHQ), Update (REC/DEP only gate), Delete (REC-only), Deposit modal REC→DEP, Clearance modal DEP→CLR/BOU with bounce reason fields, kanban drag-flow integrity, ChequeNo manual entry, 4 KPI widgets. |
| 7 | Testing - In-Kind Donation screen business flow | ⬜ | FLOW + 520px right-drawer DETAIL + 6-section drawer body. Verify: list/filter, FORM Add/Edit, Toggle status, drawer 6-section read-mode, valuation amount handling, ItemDetails JSON storage, photo cap (2), summary KPI multi-currency tooltip. |
| 8 | Testing - Recurring Donation screen business flow | ⬜ | FLOW + 460px Sheet drawer + Failed Payments Alert Banner + distribution sticky-sum. Verify: 9 commands (CRUD + Pause/Resume/Cancel/Retry stub/UpdatePayment stub/EditAmount), failed-alert collapse persistence, 6 URL-synced filter chips, distribution field-array sum widget, RecurringDonationScheduleCode auto-gen, multi-currency MRR scope. |

### Communication (10)

| # | Task | Status | Description |
|---|------|--------|-------------|
| 24 | Testing - Email Template screen business flow | ⬜ | FLOW + card-grid `iframe` variant + LivePreviewPane + StatusSegmentedToggle. Verify: card-grid render + click → split-pane editor, status toggle (Active/Draft/Inactive) writes both FK + IsActive, EmailCategory dropdown, Content/Design/Settings tabs, iframe preview sandbox, AutoSendTrigger linkage. |
| 26 | Testing - Placeholder Definition screen business flow | ⬜ | MASTER_GRID + Variant B with info-panel aside. Verify: list/filter, Add/Edit (system-row guards in handler — Update/Delete/Toggle blocked for system rows), token-chip + entity-badge + type-badge renderers, UsedInCount post-projection, PrefixSuffixInput RJSF widget, 4 MasterData typeCodes (50 system + 1 sample). |
| 27 | Testing - Saved Filter screen business flow | ⬜ | Variant A FLOW (no ScreenHeader) + 2-pane split + Live Preview right pane. Verify: 3 sections (Identification/Conditions/Visibility), entity-card-selector, Live Preview placeholder (DynamicQueryBuilder is SERVICE_PLACEHOLDER), MatchingCount stub, Duplicate cmd, FilterCategory FK, Visibility (Public/Private/Shared). |
| 28 | Testing - Company Email Provider screen business flow | ⬜ | Non-standard FLOW single-record config (no grid). Verify: 6-card stacked layout (Provider Selector / API Settings / Sending Domain+DNS / Sending Identities / Limits & Throttling / IP & Reputation) + conditional 7th SMTP card; Test Connection + Save sticky bar; Provider radio-cards from MasterData; SendingIdentity child grid CRUD; DNS records table renders sample rows. |
| 29 | Testing - SMS Template screen business flow | ⬜ | FLOW + card-grid `details` variant + split-pane editor + phone-preview. Verify: card-grid list, view-page split-pane, SMS counter hook (chars + segments), placeholder-insert menu, multi-language seed (EN/HI/AR), Toggle status, Duplicate→edit, LastUsedAt updated when SMSCampaign #30 references it. |
| 30 | Testing - SMS Campaign screen business flow | ⬜ | FLOW Variant B + 3-step wizard (Setup→Audience→Review) + report-style DETAIL. Verify: 5 recipient sources (SavedSegment/Filter/Tag/Import/AllOptedIn), Campaign Type radio-cards, Schedule cards, audience preview + cost estimate stubs, 8 workflow mutations (Send/Schedule/Pause/Resume/Cancel/Duplicate/Create/Update), 7-state workflow guards, Country distribution. |
| 31 | Testing - WhatsApp Template screen business flow | ⬜ | FLOW + card-grid `details` variant. Verify: list, FORM with header/body/footer/buttons, variable-mapping table, status pills (Pending/Approved/Rejected), phone-preview render, Meta Submit + Sync stubs, ActivateDeactivate cmd, button contiguity rule. |
| 35 | Testing - Notification Center screen business flow | ⬜ | Custom FLOW inbox feed (no FORM/DETAIL). Verify: ScreenHeader + 4 status chips + Category/Priority dropdowns; date-grouped cards (Today/Yesterday/This Week/Older); body-click marks-read + nav to actionUrl; star toggle; kebab menu (Mark unread/Star/Mute/Delete); empty-state; load-more; unread badge in ScreenHeader; pulse animation on Urgent+unread. |
| 36 | Testing - Notification Templates screen business flow | ⬜ | FLOW + card-grid `details` variant. Verify: split-pane FORM (58/42), 2-col DETAIL (1fr/360px), 3-panel preview (live card + token click-to-copy + delivery checklist), status pills, native color picker for iconColor, IconPicker, PriorityChipGroup, NotificationTemplateRole child collection. |
| 122 | Testing - Contact Source screen business flow | ⬜ | MASTER_GRID Variant B with usage-insights panel + quick-tips panel. Verify: Add/Edit/Delete (system-row guards), IconPickerWidget RJSF, ReorderContactSources (drag UI awaits onReorder prop — verify cmd works via REST), MergeContactSources modal, ContactsCount link. |

### Contacts (5)

| # | Task | Status | Description |
|---|------|--------|-------------|
| 18 | Testing - Contact screen business flow | ⬜ | FLOW + 8-section accordion FORM + 6-tab DETAIL. Verify: list with chip + advanced-filter pass-through (TAdvanceFilter via store→useMemo→setAdvanceFilter), accordion FORM (Personal/Phones×N/Emails×N/Social/Addresses×N/OrgUnits/DonationPurposes/CustomFields), child-collection arrays in CREATE+UPDATE, Donations tab self-fetch, Communication tab self-fetch, Timeline merge, ApiMultiSelect (CONTACTTYPE/TAG). |
| 20 | Testing - Family screen business flow | ⬜ | FLOW + card-grid `family` variant + full-page FORM/DETAIL. Verify: card-grid list with FamilyCard, single-head invariant guard, MembersPicker batch SetFamilyMembers, member-link to Contact, FamilyCode auto-gen (FAM-NNNN), Delete nullifies FamilyId+IsFamilyHead, headless families render, totalFamilyGiving aggregate. |
| 21 | Testing - Duplicate Detection screen business flow | ⬜ | Custom FLOW (Zustand-triggered modals, no `?mode=new`). Verify: 4 KPI widgets, filter-bar, pending-pair-card with 4 actions (Merge→/Merge←/NotDuplicate/Ignore), MergeModal Dialog (direction cells + 5-row field table + transfer summary + warning + confirm), resolved-pair-card, 4 confidence categories (NameDob/NameMobile/NameEmail/Manual), refetch-on-resolve. |
| 22 | Testing - Tags & Segmentation screen business flow | ⬜ | MASTER_GRID with 2 tabs (Tags / Segments) + segment-builder modal. Verify: tag CRUD with ColorSwatchPicker, tag cloud render, ContactTag junction visible, segment CRUD via builder modal, RunSegment count (deterministic dummy until DynamicQueryBuilder), tag-cloud click-filter (deferred). |
| 19 | Testing - Contact Type screen business flow | ⚠ | (Status: NEEDS_FIX) MASTER_GRID Variant B with side-panel. Verify: list/filter, Add/Edit/Delete, link-count to contacts. **Open ISSUEs**: drag-to-reorder (no onReorder), row-click DOM-index (no onRowClick), {lang} prefix in link-count, delete validator moved to handler. |

### Organization (6)

| # | Task | Status | Description |
|---|------|--------|-------------|
| 39 | Testing - Campaign screen business flow | ⬜ | FLOW + 4-tab FORM (Basic/Story/Goals/Settings) + 8-section dashboard DETAIL. Verify: Variant B list with chip filters, CampaignCode auto-gen (CAMP-YYYY-NNNN), 7 child collections diff-persist (DonationPurpose junction / ImpactMetric / Milestone / SuggestedAmount / TeamMember junction / TrackingMetric / RecurringFrequency), 7 workflow cmds (Publish/Pause/Resume/Complete/Cancel/Archive/Duplicate), 5-state lifecycle, ApexCharts render in dashboard. |
| 40 | Testing - Event screen business flow | ⬜ | FLOW + 5-tab FORM + dashboard-style DETAIL + calendar toggle. Verify: EventCode auto-gen, 6 child entities (TicketType/Speaker/RegistrationFormField/SuggestedAmount/CommunicationTrigger/GalleryPhoto), EventMode 3-card radio (INPERSON/VIRTUAL/HYBRID) toggles Venue/Virtual sections, 4 workflow cmds (Publish/Cancel/Complete/Duplicate), calendar alt render, RelatedCampaign FK. |
| 41 | Testing - Branch screen business flow | ⬜ | MASTER_GRID Variant B with widgets + side-panel + map placeholder. Verify: list/filter, Add/Edit/Delete, country-flag renderer, performance-bar, Staff.BranchId FK back-link, ISSUE-2 activity-stream + ISSUE-3 map both placeholders. |
| 43 | Testing - Staff Category screen business flow | ⬜ | MASTER_GRID Variant B + side-panel + ColorHexPicker. Verify: 8 system categories seeded (Management/Program/Field/Admin/Finance/Fundraising/Comm/IT), Add/Edit/Reorder cmd, color-hex-picker widget, link-count via `link-count` renderer (system-row guards). |
| 44 | Testing - Organizational Unit screen business flow | ⬜ | Custom FLOW (non-standard index — tree-or-list split-pane + 4-tab detail). Verify: 4 KPI widgets, tree view with hierarchy indent, list-view toggle, 6-section FORM, UnitCode auto-gen (HQ-/REG-/BR-/SU-), HierarchyLevel auto-compute, Move cmd cycle-prevention, HQ-singleton guard, delete-guard counts in tooltip, OrgUnitDonationPurposes + OrgUnitPaymentModes junctions. |
| 46 | Testing - Event Ticketing screen business flow | ⬜ | Composite FLOW single-page console (6 stacked cards). Verify: Event selector, summary-bar, ticket-types-card with inline ticket-form, registration-settings-card + custom-question-modal (reorder), public-preview-card, registrants-card with check-in-toggle, 6 workflow cmds (Pause/Resume Ticket / CheckIn/Cancel/Approve Registration / Upsert Setting), waitlist promotion on Cancel, capacity = SUM(EventTickets.QuantityAvailable). |
| 48 | Testing - Auction Management screen business flow | ⬜ | Non-standard FLOW console at `?eventId=X` + 4 modals + 30s bid-feed poll. Verify: event-selector, inline collapsible add-form (10-field RHF+zod), 4 KPI widgets, AuctionItem grid (BESPOKE not FlowDataTable), 6 modals (Edit/BidHistory+PlaceBid/LowerReserve/Award/CollectPayment), CloseBidding transactional winner resolution, EventAuction state machine (NotStarted→Open→Closed), AuctionItem state machine, IsCurrentHighest atomic flip on PlaceBid. |

### Case Management (3)

| # | Task | Status | Description |
|---|------|--------|-------------|
| 49 | Testing - Beneficiary screen business flow | ⬜ | FLOW + 7-section accordion FORM + 5 Quick-Stats + 6-tab DETAIL. Verify: 4 KPI widgets, 7 chip filters, 6-field advanced filter panel, FORM with cascading Country→State→City→Locality + inline household-members child-grid + 8 hard-coded eligibility cards, DETAIL tabs (Overview/Programs & Services/Cases/Sponsorship/Documents/Timeline), Enroll quick-action (Waitlist only), bulk Export/Assign Staff/Send Communication. |
| 50 | Testing - Case screen business flow | ⬜ | FLOW + tabbed rich DETAIL (5 tabs) + 4 modals. Verify: 4 KPI widgets, FORM with conditional referral sub-form (IsExternalReferral=true → ReferralTo required), CaseCode auto-gen (CASE-NNNN), DETAIL tabs (Notes/Action Plan/Referrals/Documents/History), 4 modals (UpdateStatus/Reassign/CloseCase/QuickAdd), 5-state lifecycle + Overdue derived (FollowUpDate < today), CloseCase requires CaseOutcomeId + ClosureSummary. |
| 51 | Testing - Program screen business flow | ⬜ | Non-canonical MASTER_GRID + new `program` card variant + 80%-right side-drawer FORM. Verify: 2-col responsive cards (emoji + status-badge + 4 stat lines + budget line + capacity bar + Manage/Dashboard footer), 7-section RHF+zod drawer FORM, 3 child grids (EligibilityCriterion/Service/OutcomeMetric), ProgramStaff M:N junction + ProgramLeadStaffId, 5 SERVICE_PLACEHOLDERs (enrolled/waitlist/spent/onTrack pending #49/#50/#62 + emoji picker). |

### Volunteer (3)

| # | Task | Status | Description |
|---|------|--------|-------------|
| 53 | Testing - Volunteer screen business flow | ⬜ | FLOW + 6-section accordion FORM + full-page 5-tab DETAIL. Verify: 4 KPI widgets, 5 chip filters, contact-typeahead-picker (link-or-new), multi-tag-chip-selector for skills/interests, tag-input-pill for languages/certs, day-chip-row for blackout, DETAIL tabs (Overview/Schedule/Hours/Donations/Recognition), 4 workflow cmds (Approve/Deactivate/SetOnLeave/Reactivate). |
| 54 | Testing - Volunteer Schedule screen business flow | ⬜ | Non-standard FLOW (modal + drawer, In-Kind precedent) — calendar+list dual view. Verify: 4 KPI widgets, calendar grid (70px+repeat(7,1fr) × 11 time rows), shift blocks colored by SHIFTTYPE (EVENT/OFFICE/FIELD/REMOTE/TRAINING), shift-form-modal (12 fields, auto-assign toggle), shift-detail-drawer 480px (3-segment status bar, Assigned table + Available table), 7 workflow cmds (Assign/Confirm/Remove/Remind + bulk RemindPending/NotifyAvailable/AutoSchedule placeholders). |
| 55 | Testing - Hour Tracking screen business flow | ⬜ | FLOW + 520px right-drawer DETAIL + collapsible aggregate panel. Verify: 4 KPI widgets, 4 status chips, 3-state workflow (Pending→Approved or Rejected with RejectionReason ≥5 chars), 8-col grid with conditional per-row actions per status, bulk-actions-bar at ≥1 selection, BulkApprove/BulkReject/LogAndApprove cmds, Volunteer Hours Summary panel below grid (PeriodHours/YTD/Shifts/AvgPerShift/ApprovalRate%). |

### Membership (3)

| # | Task | Status | Description |
|---|------|--------|-------------|
| 58 | Testing - Membership Tier screen business flow | ⬜ | Non-canonical MASTER_GRID + new `membership-tier` card variant + 520px right slide-panel FORM. Verify: horizontal-scroll tier cards (Bronze/Silver/Gold/Platinum/Lifetime), 4-section code-driven RHF+zod form, MembershipTierBenefit child diff-persist, BenefitsComparison matrix below grid, 3 MasterData typeCodes (PRICINGMODEL/MINDONATION/DOWNGRADEPOLICY), 39 benefit rows seed, memberCount placeholder pending #59. |
| 59 | Testing - Member Enrollment screen business flow | ⬜ | Non-canonical FLOW + 3-step wizard FORM (Contact&Tier/Payment/Confirmation) + single-col 4-tab DETAIL. Verify: FlowWizardStrip + TierCardSelector + PaymentMethodCardList + InlineContactCard, 4 KPI widgets (Total Members/Revenue YTD/Renewals Due 30d/New This Month), 6-state workflow (Pending→Active, Active→Suspended/Cancelled, Auto-Expired by daily job), 5 transition cmds (Approve/Reject/Suspend/Resume/Cancel), 4 tabs (Overview/Payment History/Benefits/Activity). |
| 60 | Testing - Membership Renewal screen business flow | ⬜ | MASTER_GRID with bespoke renewal modal + collapsible settings panel. Verify: 4 KPIs, 5 filter tabs, 5 cell renderers, renewal modal flow (manual + auto-renewal toggle), MembershipRenewalConfig singleton settings, 4 SERVICE_PLACEHOLDERs (sendRenewalReminder/sendBulkReminders/processAllAutoRenewals/retryFailedAutoRenewal). |

### Grants (2)

| # | Task | Status | Description |
|---|------|--------|-------------|
| 62 | Testing - Grant screen business flow | ⬜ | FLOW + dual-view (Kanban Pipeline default + Table toggle) + 5-tab DETAIL + 7-section FORM. Verify: 4 KPI widgets, kanban board (drag between stages), 6 entities (Grant + 5 children: BudgetLine/Milestone/ImplementingBranch/Attachment/StageHistory), 9 cmds (CRUD + 5 workflow: Submit/Approve/Reject/Activate/RecordTranche), grant-stage-badge + grant-progress-bar renderers, attachment-checklist with file upload SERVICE_PLACEHOLDER. |
| 63 | Testing - Grant Report screen business flow | ⬜ | FLOW + view-page 3 modes + publication-style DETAIL + 7-section FORM with rich-text × 3. Verify: 4 KPI widgets, filter chips bar, 4 entities (parent + 3 children: Deliverable/FinancialLine/Attachment), 8 cmds (CRUD + 4 workflow: Submit/Accept/RequestRevision/Reopen), drag-drop attachments stub, prefill query (loads parent Grant context), Grant #62 Tab 2 wires to live `GetGrantReports?grantId=X`. |

### Field Collection (3)

| # | Task | Status | Description |
|---|------|--------|-------------|
| 65 | Testing - Field Collection screen business flow | ⬜ | FLOW field-collection workflow. Verify: list/filter, FORM round-trip, status transitions, link to Receipt Book #66, link to Ambassador #67. (Verify against prompt + mockup before testing — registry note brief.) |
| 66 | Testing - Receipt Book screen business flow | ⬜ | MASTER_GRID with tracking panel + bulk-create + assign modal. Verify: 4 KPI cards, tracking panel (per-receipt USED/VOIDED/UNUSED/GAP), bulk-create modal with preview, assign modal, 3 cell renderers, BookStatusCode/Used/Voided/Remaining/UsagePct computed, GapCount=0 V1 placeholder, Print Cover Sheet SERVICE_PLACEHOLDER. |
| 67 | Testing - Ambassador screen business flow | ⬜ | FLOW with collection-list FE feature. Verify: AmbassadorCollection entity extended, list/filter, FORM Add/Edit, link to Staff/Branch/StaffCategory/ReceiptBook FKs, status transitions. (DB migration/seed deferred — apply locally before testing.) |

### Fundraising — P2-Core (4)

| # | Task | Status | Description |
|---|------|--------|-------------|
| 11 | Testing - Matching Gift screen business flow | ⬜ | Composite FLOW — 3 entities under ONE menu (4 tabs). Verify: Tab 1 MatchingCompany list + LAYOUT 1 FORM + LAYOUT 2 DETAIL; Tab 2 MatchingGift tracker grid + LAYOUT 3 TRACKER DETAIL with inline status-action-bar (replaces legacy modal); Tabs 3+4 MatchingGiftSettings (single-row Upsert + Donor Guidance form); 4 KPI widgets via GetMatchingGiftSummary; 6-state workflow + chips; ResubmitMatchingGift cmd. |
| 12 | Testing - Pledge screen business flow | ⬜ | FLOW + 720px side-drawer DETAIL + Overdue Alert Banner + 2-entity model (Pledge + PledgePayment). Verify: 4 KPI widgets, 5 chip filters (All/Active/Fulfilled/Overdue/Cancelled), 7-field advanced filters, PledgePayment auto-generation on Create + regen on Update (preserves PAID history), computed status (OnTrack→Behind→Overdue→Fulfilled→Cancelled), Record Payment deep-link to GlobalDonation form, Cancel cmd, fulfillment-progress + payment-status-chip renderers. |
| 13 | Testing - Refund screen business flow | ⬜ | FLOW + 600px detail drawer + 3 workflow modals. Verify: 3 KPI widgets, 5 chip filters, FORM with Donation Picker (excludeRefunded subquery), RefundCode auto-gen REF-NNNN, 5-state workflow PEN→APR→PRO→REF/REJ, 4 transition cmds (Approve/Reject/Process/Complete), Approval modal (summary box + warning + red Confirm), Rejection modal (reason ≥10 chars), Complete modal (RefundedDate + GatewayTxnId), refund-amount-cell status-tinted, completion-date suffix on REF rows. |
| 14 | Testing - Payment Reconciliation screen business flow | ⬜ | Custom FLOW workbench (NO new entity — projection over PaymentTransaction + PaymentSettlement + GlobalOnlineDonation). Verify: 4 KPI widgets, toolbar (DateRange/Run/Export), 3 stacked section cards (Reconciliation Details 10-col plain table / Unmatched Transactions collapsible w/ auto-match suggestions / Settlement Summary 8-col), 560px detail drawer 6-section, MatchPaymentTransaction modal (ApiSelect + same-currency gate), RespondToDispute modal, RunAutoReconciliation cmd (100-chunk batches + 1-yr guard). |

---

## Summary

| Module | Screens | Tested | Pass | Issues | Failed |
|--------|---------|--------|------|--------|--------|
| Fundraising (Donations/Reconcile) | 11 | 0 | 0 | 0 | 0 |
| Communication | 10 | 0 | 0 | 0 | 0 |
| Contacts | 5 | 0 | 0 | 0 | 0 |
| Organization | 7 | 0 | 0 | 0 | 0 |
| Case Management | 3 | 0 | 0 | 0 | 0 |
| Volunteer | 3 | 0 | 0 | 0 | 0 |
| Membership | 3 | 0 | 0 | 0 | 0 |
| Grants | 2 | 0 | 0 | 0 | 0 |
| Field Collection | 3 | 0 | 0 | 0 | 0 |
| **Total** | **47** | **0** | **0** | **0** | **0** |

> Note: 47 rows above = 46 COMPLETED + 1 NEEDS_FIX (#19 Contact Type included as ⚠).

---

## Tester guidance

- Run `pnpm dev` against a fresh DB after applying every screen's `sql-scripts-dyanmic/{Screen}-sqlscripts.sql` seed (keep `dyanmic` typo — repo convention).
- Apply pending EF migrations first (several screens deferred migration generation per token-budget directive — see `prompts/{screen}.md` ISSUE list for the exact `dotnet ef migrations add ...` command).
- Test on Chromium + at least one of Firefox/Safari at the responsive breakpoints listed above.
- For each failure, take a screenshot, file under `docs/test-evidence/{screen-slug}/{YYYY-MM-DD-HHmm}.png` (create folder if missing), and link from the prompt-file ISSUE entry.
- After a full module's screens pass, smoke-test the parent navigation and dashboard summary widgets to catch cross-screen aggregation regressions.
