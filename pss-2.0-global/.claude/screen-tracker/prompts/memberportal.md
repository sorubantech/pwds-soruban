---
screen: MemberPortal
registry_id: 61
module: Setting (Public Pages) — admin setup / (Member) — member-authenticated portal
status: PARTIALLY_COMPLETED     # v2 build in progress — Stage A (seeds+data) BE + branding-settings FE done (S5 2026-06-15); Stages B/C-remainder/D/E pending. Build from the "v2 RE-ARCHITECTURE" block below
scope: FULL
screen_type: EXTERNAL_PAGE      # v1 classification — RECLASSIFIED in v2 → CONFIG (branding via tenant OrgSettings) + authenticated in-app member area (role-menu driven)
external_page_subtype: MEMBER_PORTAL   # v1 — ABANDONED in v2 (the portal is NOT an external/public page; it is an authenticated in-app area)
complexity: High
new_module: NO
planned_date: 2026-05-14
replan_date: 2026-06-15
completed_date: 2026-05-14
last_session_date: 2026-06-15
---

## ⓥ2 RE-ARCHITECTURE — AUTHORITATIVE (2026-06-15)

> **READ THIS FIRST.** Session 2 (ISSUE-19) found the v1 `MEMBER_PORTAL` static-external-page model is architecturally wrong. This block is the authoritative v2 spec. **Where any v1 section (§① … §⑬ Session-1) conflicts with this block, THIS BLOCK WINS.** v1 content is retained below for build-log / audit only.

### A. Why v1 was wrong
- **Nav as static booleans.** `mem.MemberPortalConfigs` encodes the member nav/sections/quick-actions as `NavDashboardEnabled` / `SectionBenefitsEnabled` / `QuickAction*Enabled` — a parallel hardcoded menu system that duplicates the app's existing role → menu → capability RBAC.
- **Faked auth.** Member access is a `localStorage` mock (`MemberAuthGuard`, `(member)/login`, `/member-login` — ISSUE-2/17/18), not a real identity.
- **Wrong mental model.** The portal is treated as an anonymous public funnel. It is an **authenticated in-app area** for real members.

### B. Settled data model (verified against the live schema this session)
- **`Contact.UserId`** (int?, nullable, FK → `auth.Users`, **1:1**) = the member's/volunteer's **own login**. ⟵ **UPDATED 2026-06-15 (Session 4):** this is the **RENAME** of the former `Contact.StaffUserId`. The "Assigned Staff / managed-by" concept was **DROPPED** — re-analysis found it was never used in a real WHERE-filter (the staff-scoping line was only a conditional/planned note, no live handler). There is now a **single** `User` nav on Contact (`Contact.User`), wired 1:1: `HasOne(o => o.User).WithOne(p => p.Contact).HasForeignKey<Contact>(o => o.UserId)`. No second nav, no cascade. **Migration already run by the user.**
  - Symmetric with staff: a **staff** person = `app.Staffs` ↔ `auth.Users` via `User.StaffId` (kept — load-bearing for login); a **member/volunteer** person = `corg.Contacts` ↔ `auth.Users` via `Contact.UserId`. **No `User.ContactId`** — resolve a member from a login via `Contacts.First(c => c.UserId == userId)`.
- **MEMBERSHIP role** — seeded, tenant-scoped via existing nullable `auth.Roles.CompanyId`. (Same pattern reused later for a VOLUNTEER role.)
- **`User.PrimaryRoleId`** → the MEMBERSHIP role for member logins (column already exists).
- **Type is derived, not columnar.** Member vs volunteer vs staff = (a) which domain record exists (`MemberEnrollment` / `Volunteer` / `Staff`) + (b) the RBAC role. A person who is both member & volunteer = **1 Contact, 1 User (`Contact.UserId`), 2 roles**. No per-type FK columns.
- Staff today are NOT Contacts (separate `app.Staffs` person record with its own `User.StaffId`); they keep their existing link. Folding staff into Contacts is out of scope.

### C. Locked decisions (this session)
1. **Branding store → tenant OrgSettings.** Store member-portal branding as `ParamCode` rows in `sett.OrganizationSettings` under a **new `MEMBERPORTAL` group** (logo / accentHex / accentLightHex / welcomeCopy / footerCopy / contactEmail / donationSlug / portalStatus). Consistent with the AUTH #119 / tenant-scoped OrgSettings direction (which already replaced `CompanyBrandings`). **DROP the `mem.MemberPortalConfigs` table entirely.**
2. **Member auth → unified branded login + role landing.** Members log in through the SAME tenant-branded login page as everyone else (AUTH #119 SSR-per-subdomain) → real NextAuth `CredentialsProvider` → the **role-based default landing page** feature (just built) routes the MEMBERSHIP role's `DefaultLandingUrl` to the portal dashboard. **REMOVE** `(member)/login`, `/member-login`, and the `MemberAuthGuard` localStorage mock.
3. **Provisioning → enrollment-triggered "Invite to Portal."** When a `MemberEnrollment` is created/activated for a Contact, provision portal access: create a pending-invitation `User`, set `Contact.UserId`, assign the MEMBERSHIP role, email a set-password link. **Automatic** (reuse the enrollment's existing `SendWelcomeEmail` toggle slot) **and** a **manual "Invite to Portal"** action on the enrollment/contact for re-sends. Reuses #72's invite pipeline (`IsPendingInvitation` / `InvitationSentAt`). The pre-enrollment "invite to register the plan" funnel is **OUT OF SCOPE** for #61 (future member-registration page).
4. **Nav/sections → real menus.** Member portal nav (Dashboard / Profile / Benefits / Payments / Events) become real `auth.Menus` rows under a member-portal parent, gated by MEMBERSHIP `RoleCapabilities` (`ISMENURENDER`), rendered via the existing **`GetParentChildMenu`** query in a member-branded layout (no admin sidebar). **DROP all `Nav*` / `Section*` / `QuickAction*` booleans** — per-tenant show/hide = that tenant's MEMBERSHIP role capabilities.
5. **Route naming → `member-portal/` + bespoke `/member-login` (UPDATED 2026-06-15, Session 5 — supersedes decision 2's "unified login" for members).** The member-facing route group lives at **`(member)/member-portal/*`** (dashboard / profile / benefits / payments / events), **renamed from the original `(member)/portal/*`** so the future **`volunteer-portal/`** gets a clean, disambiguated sibling path. MEMBERSHIP `DefaultLandingUrl` = **`member-portal/dashboard`**; all 5 leaf-menu `MenuUrl`s + the `LANDINGPAGE` MasterData option carry the `member-portal/*` prefix. A bespoke **`/member-login`** page (toggle: **Member Code** OR **Email** + password) is the member entry point — NOT a redirect to staff `/login`. `MemberAuthGuard` treats `/member-login` as public; portal pages stay gated. **BE dependency:** the `login` resolver must resolve the identifier by UserName / Email / member `ContactCode` (→ `Contact.UserId` → `User`), tenant-scoped.

### D. KEEP / DROP / ADD vs the v1 build

| | Item |
|---|---|
| **DROP** | `mem.MemberPortalConfigs` table + entity + EF config + schemas + its 6 CRUD/lifecycle handlers (`GetMemberPortalConfig`, `GetMemberPortalConfigForMember`, `ValidateMemberPortalForActivate`, `UpdateMemberPortalConfig`, `ActivateMemberPortal`, `DisableMemberPortal`, `ResetMemberPortalBranding`), DbSet, mappings, decorator. · `(member)/login` + `/member-login` route + `MemberAuthGuard` + localStorage session. · The 6 boolean admin section cards (Nav Visibility / Hero / Quick Actions / Sections toggles). · Preview-banner reliance on mock token. |
| **KEEP** | Member dashboard surface (hero membership card, payment summary) reading live from `MemberEnrollment` via `GetMyMemberEnrollment`. · Benefits / Recent Activity / Upcoming Events as SERVICE_PLACEHOLDER (ISSUE-3/5/6 unchanged). · The branding *fields themselves* (logo/colors/welcome/footer/contactEmail/donationSlug) — relocated to OrgSettings. |
| **ADD** | `Contact.UserId` column + FK config. · MEMBERSHIP role seed + member-portal menu tree seed + MEMBERSHIP RoleCapabilities (`ISMENURENDER`). · OrgSettings `MEMBERPORTAL` ParamCode group seed + read/write via existing OrgSettings service. · `InviteMemberToPortal` provisioning command (reuses #72 invite internals) + hook into `CreateMemberEnrollment` + standalone/resend mutation. · `Role.DefaultLandingUrl` persistence (role-landing feature — **USER is building this BE**; FE done). · Member layout reads menus from `GetParentChildMenu`; member dashboard guarded by real NextAuth session (MEMBERSHIP role). |

### E. v2 file-manifest delta (supersedes v1 §⑧)
**Backend**
- DROP all `MemberPortalConfig*` files (entity/config/schemas/queries/commands/endpoints/DbSet/mapping/decorator listed in v1 §⑧).
- ✅ **DONE (Session 4):** `Contact.cs` → `StaffUserId` renamed to `int? UserId`, single `User? User` nav kept; `ContactConfiguration.cs` → 1:1 `HasOne(o => o.User).WithOne(p => p.Contact).HasForeignKey<Contact>(o => o.UserId)`; `User.cs` → inverse changed from `ICollection<Contact> ContactStaffs` to single `Contact? Contact`; `ContactRequestDto.UserId` renamed; `ContactImport-fn-execute.sql` staging field renamed. **User ran the migration.**
- `GetMyMemberEnrollment.cs` → KEEP, but resolve ContactId from the **real** auth token via `Contacts.First(c => c.UserId == currentUserId).ContactId` (there is **no** `User.ContactId`; delete the v1 mock/query-arg fallback). Tenant + privilege-escalation discipline from v1 §④ still applies.
- Provisioning: `InviteMemberToPortal.cs` command (+ wire into `CreateMemberEnrollment`/activation) reusing #72 user-invite + invite-email pipeline.
- Seeds: MEMBERSHIP role; member-portal parent menu + 5 leaves; MEMBERSHIP RoleCapabilities; OrgSettings `MEMBERPORTAL` ParamCode rows. (User runs EF migration for `Contact.UserId` manually per house rule.)
- Role-landing BE (`Role.DefaultLandingUrl` persist + login returns it) — **USER owns** (see role-default-landing-page spec §④).

**Frontend**
- DELETE `(member)/login`, member-login, `MemberAuthGuard`, the 4 boolean section cards.
- Member layout (`(member)/layout.tsx` or relocated) → render nav from the role-filtered menu query (`GetParentChildMenu`), wrap in real NextAuth `SessionProvider`, guard on MEMBERSHIP role.
- Admin branding screen → reclassify as a **CONFIG / SETTINGS_PAGE** editing the OrgSettings `MEMBERPORTAL` group (reuse the OrgSettings editor pattern from #119 / `setting/orgsettings`); drop the boolean cards, keep branding inputs + portal-status.
- `MemberEnrollment` grid/form → add an **"Invite to Portal"** row/form action.
- KEEP member dashboard components (hero card, payment summary, placeholders).

### F. v2 acceptance (delta — supersedes v1 §⑪ where conflicting)
- Member logs in via the standard tenant-branded login and lands on the portal dashboard via the MEMBERSHIP role's `DefaultLandingUrl` (no `(member)/login`, no localStorage session).
- Portal nav is driven by MEMBERSHIP `RoleCapabilities` — toggling a capability adds/removes a nav item; there are NO `Nav*Enabled` booleans anywhere.
- `Contact.UserId` links a member to their login (1:1); the former `Contact.StaffUserId` / "Assigned Staff" concept is dropped (renamed into `UserId`).
- "Invite to Portal" provisions a `User` + MEMBERSHIP role + `Contact.UserId` + invite email; re-send works.
- Branding edits persist to OrgSettings `MEMBERPORTAL` group and render on the member surface.

### G. Issues this re-plan closes / supersedes
- **ISSUE-1** (MEMBER_PORTAL sub-type divergence) → SUPERSEDED — sub-type abandoned; portal is an authenticated in-app area, branding is CONFIG.
- **ISSUE-2 / 17 / 18** (member-auth mock, member-login URL, localStorage session) → SUPERSEDED by unified real auth (decision C.2).
- **ISSUE-16** (`Permissions.Activate/Disable` missing) → MOOT — singleton lifecycle dropped; portal status is one OrgSettings ParamCode, no Activate/Disable caps.
- **ISSUE-19** note used a stale shape (`Role.DefaultLandingMenuId` + per-user override). The feature as built uses **`Role.DefaultLandingUrl`** (string relative-route, NOT a Menu FK) with precedence `User.PrimaryRoleId` role → lowest `Role.OrderBy` role → `masterdashboard` (NO per-user override column). v2 follows the as-built shape.

### H. Build sequence
1. **(USER)** role-landing BE §④ — `Role.DefaultLandingUrl` persist + login returns it. (Role-landing FE already shipped.)
2. ✅ `Contact.UserId` DONE (Session 4). → **NEXT:** MEMBERSHIP role + member-portal menu tree + MEMBERSHIP RoleCapabilities + OrgSettings `MEMBERPORTAL` group seeds.
3. `InviteMemberToPortal` provisioning (+ enrollment hook).
4. Member layout role-menu render + real-auth guard; branding admin screen on OrgSettings; "Invite to Portal" action.
5. Verify §F for ≥2 tenants (cross-tenant isolation + a member who is also a volunteer).

---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (sub-type **identified as a new MEMBER_PORTAL variant** — admin setup that publishes a member-authenticated portal, NOT an anonymous public page)
- [x] Business context read (audience = existing dues-paying members logging in to see their own enrollment / benefits / payments / events; conversion goal = self-service renewal + engagement; lifecycle = `Disabled / Active` — singleton per tenant)
- [x] Setup vs Member-Portal route split identified (admin at `setting/publicpages/memberportal` + member-authenticated portal at `(member)/portal/dashboard` — NEW route group `(member)` distinct from existing `(public)`)
- [x] Slug strategy chosen: **N/A** — singleton per tenant; route resolves by tenant slug, not page slug
- [x] Lifecycle states confirmed: `Disabled` (default — portal returns 404 to members) / `Active` (portal renders for authenticated members of this tenant). Single tenant-level config, not per-page.
- [x] Payment gateway integration scope: **N/A for this prompt** — auto-renew status is READ from `MemberEnrollment.AutoRenew`; actual renewal payment flow links out to existing `crm/membership/membershiprenewal` (#60)
- [x] Member-credential auth scope: **SERVICE_PLACEHOLDER** — repo's NextAuth has staff CredentialsProvider only; member auth flow is mocked (dev login by member-code or contact-email) until a separate member CredentialsProvider is built
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed (admin setup files + member-portal route files separately)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt §① pre-analysis accepted — MEMBER_PORTAL sub-type, audience, conversion goal, lifecycle, divergence rationale all complete)
- [x] Solution Resolution complete (EXTERNAL_PAGE/MEMBER_PORTAL, single-config-record singleton, 2-state lifecycle, member-credentials SERVICE_PLACEHOLDER scope, new (member) route group — confirmed)
- [x] UX Design finalized (admin split-pane editor + 6 section cards + live preview iframe / member portal hero card + quick actions + benefits + payment summary + recent activity + upcoming events — per §⑥ M.1/M.2/M.3/M.4)
- [x] User Approval received (2026-05-14 — "Approve as-is" with path corrections: presentation/components/page-components/, no (core) group, member components at member/portal/)
- [x] Backend code generated (13 BE files — entity / EF config / schemas / 3 queries / 4 commands / GetMyMemberEnrollment / 2 endpoints)
- [x] Backend wiring complete (IMemDbContext + MemDbContext + DecoratorProperties + MemMappings + MemberEnrollmentQueries.cs append)
- [x] Frontend (admin setup) code generated (DTOs + GQL Q/M + setup-page + 6 section components + live-preview iframe + Zustand store + page-config)
- [x] Frontend (member portal) code generated (NEW `(member)` route group + layout + member-login + dashboard + 4 stub pages + 12 portal components incl. MemberAuthGuard)
- [x] Frontend wiring complete (4 barrels + page-config registry + admin route stub overwrite + entity-operations + auth.ts public-route allowlist)
- [x] DB Seed script generated (MemberPortal-sqlscripts.sql — default config row + MENUCAPS + RoleCapabilities; menu pre-exists in Pss2.0_Global_Menus_List.sql:457)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — admin setup loads at `/{lang}/setting/publicpages/memberportal`
- [ ] `pnpm dev` — member portal loads at `/{lang}/portal/dashboard` AFTER member login
- [ ] **MEMBER_PORTAL checks**:
  - [ ] Admin singleton config loads / saves (autosave 300ms debounce); preview pane updates live
  - [ ] 6 settings cards persist: Branding (logo + 2 colors + welcome copy) / Nav Visibility (toggle each of 5 nav items) / Hero Card (org logo + tier label format + Member ID format + "Download Card PDF" toggle) / Quick Actions (toggle each of 5 quick-action buttons) / Sections (toggle Benefits / Payment Summary / Recent Activity / Upcoming Events sections) / Status (Disabled ↔ Active toggle)
  - [ ] Mobile / Desktop preview toggle changes preview viewport width
  - [ ] Status toggle Disabled → Active makes portal accessible; Active → Disabled returns 404 to all members
  - [ ] Member portal route `(member)/portal/dashboard/page.tsx` is gated by member auth; unauthenticated → redirect to member-login (SERVICE_PLACEHOLDER credentials screen)
  - [ ] Member portal calls `GetMyMemberEnrollment` (resolves logged-in ContactId → returns single MemberEnrollmentResponseDto); shows: Tier Name + ColorHex on card, MemberCode as Member ID, MembershipFee + Currency on Payment Summary, EndDate as Valid Until, AutoRenew status, PaymentMode + last-4 if available
  - [ ] Quick Actions buttons link to: Renew → `crm/membership/membershiprenewal?action=renew&enrollmentId={id}` (intra-app jump for admins; SERVICE_PLACEHOLDER toast for members) / Update Profile → SERVICE_PLACEHOLDER / View Benefits → scroll-anchors to Benefits section / Make Donation → opens published OnlineDonationPage slug (if MakeDonationLinkSlug set in config) else SERVICE_PLACEHOLDER / Contact Us → mailto: tenant support email
  - [ ] Benefits table renders SERVICE_PLACEHOLDER rows when MembershipTierBenefits not wired (Quarterly Newsletter / Annual Impact Report / Member-Only Events / Voting Rights / Director Meeting — 5 hardcoded sample rows with "—" actions)
  - [ ] Recent Activity renders SERVICE_PLACEHOLDER empty state with "Your recent activity will appear here" copy
  - [ ] Upcoming Events renders SERVICE_PLACEHOLDER empty state with "Member events will appear here" copy
  - [ ] Preview banner "MEMBER PORTAL PREVIEW — This is how members see their dashboard" renders ONLY in admin preview pane, NEVER on the real member portal route
  - [ ] If no active MemberEnrollment found for logged-in contact → portal shows "You have no active membership" with "Join Now" CTA linking to MEMBERENROLLMENT
  - [ ] Multi-currency: MembershipFee renders with MemberEnrollment.Currency.Symbol (FK chain), never assumes USD
  - [ ] All dates rendered with member's locale formatter (not server timezone literal)
- [ ] Empty / loading / error states render on both setup and member-portal surfaces
- [ ] DB Seed — admin menu visible at SET_PUBLICPAGES > MEMBERPORTAL; default MemberPortalConfig row seeded (Disabled by default)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage for admin setup AND member-portal surface

Screen: MemberPortal
Module: Setting (admin setup) / Member (authenticated portal)
Schema: `mem` (reuses schema bootstrapped by #58/#59/#60)
Group: MemModels

Business: This is the canonical **member-facing self-service portal** for an NGO's dues-paying members — the post-login dashboard a Platinum / Gold / Silver / Bronze member sees when they visit their organization's member area. Unlike OnlineDonationPage / P2PCampaignPage / Crowdfunding (which are anonymous-public conversion funnels), Member Portal is **member-authenticated**: a visitor must log in with a member credential (member-code or registered email) before the dashboard renders. The admin setup screen lets a BUSINESSADMIN configure every brandable surface of the portal — header logo, accent colors, welcome copy, which nav items appear (Dashboard / My Profile / Benefits / Payments / Events), which quick-actions are exposed (Renew / Update Profile / View Benefits / Make Donation / Contact Us), which sections render on the Dashboard (Hero Membership Card / Benefits Table / Payment Summary / Recent Activity / Upcoming Events), and an Active/Disabled portal-wide kill-switch. The MVP scope for the member-facing surface is the **Dashboard tab only** (4 of the 5 nav items resolve to SERVICE_PLACEHOLDER pages in v1). The headline conversion goal on the member surface is **self-service renewal** (deflecting admin-mediated renewals) and **engagement signal capture** (members who log in are showing intent — that's a positive segmentation signal for fundraising). **What breaks if mis-set**: member sees stale tier / wrong "Valid Until" date (drives support tickets), Recent Activity exposes another member's donations (auth scoping defect — critical), preview banner ships to real members (embarrassment + trust loss), Disabled portal still renders for a logged-in member (cache invalidation defect), member-credential auth not gated on the route (anyone-with-a-staff-account-becomes-a-member — privilege escalation). Related screens: enrollment data sourced from MemberEnrollment (#59); tier metadata from MembershipTier (#58); renewal flow continues on MembershipRenewal (#60); the "Make Donation" quick-action deep-links to a published OnlineDonationPage (#10) if one exists. **What's unique about this page's UX vs an anonymous EXTERNAL_PAGE**: (a) it is auth-gated, not anonymous — every render carries a member-context; (b) it is singleton-per-tenant (no slug, no list-of-N pages — one Member Portal config per tenant); (c) the route group is `(member)`, not `(public)` — must NOT inherit admin-shell chrome AND must NOT inherit anonymous-public chrome (member chrome is its own thing — branded with the tenant's logo + accent + welcome-greeting); (d) the data shown is per-member-scoped — every query MUST filter by the logged-in member's ContactId, never trust client-supplied IDs.

> **Why this section is heavier**: the divergence from the canonical 3 EXTERNAL_PAGE sub-types (DONATION_PAGE / P2P_FUNDRAISER / CROWDFUND) is fundamental — auth model, route group, storage pattern (singleton vs list), and lifecycle all differ. A developer that misses this and builds it as an anonymous page will leak per-member data to anyone with the URL. Read §⑫ ISSUE-1 and §⑤ very carefully.

---

## ② Storage & Source Model

> **Consumer**: BA Agent → Backend Developer
>
> MEMBER_PORTAL sub-type uses a `single-config-record` storage pattern — diverges from the
> template's documented `single-page-record` / `parent-with-children` patterns. ONE row per tenant.

**Storage Pattern**: `single-config-record` (singleton-per-tenant)

> One MemberPortalConfig row per tenant — first GET upserts the default row if missing.
> The actual member-facing data (enrollment, tier, payments, etc.) is read from existing
> entities via the new `GetMyMemberEnrollment` query — Member Portal is a **READ funnel** over
> existing MemberEnrollment data, not a new transactional store.

### Tables

> Audit columns omitted (inherited from `Entity` base). CompanyId always present (tenant scope). Schema = `mem`.

**Primary table**: `mem."MemberPortalConfigs"` (singleton)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| MemberPortalConfigId | int | — | PK | — | Identity primary key |
| CompanyId | int | — | YES | corg.Companies | Tenant scope — **unique** (one row per tenant) |
| PortalStatus | string | 20 | YES | — | `Disabled` (default) \| `Active` |
| BrandingLogoUrl | string | 500 | NO | — | Header logo; falls back to Company.LogoUrl if null |
| BrandingAccentHex | string | 7 | NO | — | Primary accent color (default `#0e7490`) — drives nav-hover, CTAs |
| BrandingAccentLightHex | string | 7 | NO | — | Lighter accent for gradients (default `#06b6d4`) |
| WelcomeCopyTemplate | string | 200 | NO | — | Greeting template w/ `{FirstName}` token (default `Welcome, {FirstName}`) |
| NavDashboardEnabled | bool | — | YES | — | default true — Dashboard nav-item visibility |
| NavMyProfileEnabled | bool | — | YES | — | default true |
| NavBenefitsEnabled | bool | — | YES | — | default true |
| NavPaymentsEnabled | bool | — | YES | — | default true |
| NavEventsEnabled | bool | — | YES | — | default true |
| HeroCardEnabled | bool | — | YES | — | default true — Membership Card hero visibility |
| HeroDownloadCardPdfEnabled | bool | — | YES | — | default true — "Download Card PDF" button on hero |
| QuickActionRenewEnabled | bool | — | YES | — | default true |
| QuickActionUpdateProfileEnabled | bool | — | YES | — | default true |
| QuickActionViewBenefitsEnabled | bool | — | YES | — | default true |
| QuickActionMakeDonationEnabled | bool | — | YES | — | default true |
| QuickActionContactUsEnabled | bool | — | YES | — | default true |
| SectionBenefitsEnabled | bool | — | YES | — | default true — Benefits table block |
| SectionPaymentSummaryEnabled | bool | — | YES | — | default true |
| SectionRecentActivityEnabled | bool | — | YES | — | default true |
| SectionUpcomingEventsEnabled | bool | — | YES | — | default true |
| MakeDonationLinkSlug | string | 100 | NO | — | Slug of a published OnlineDonationPage to deep-link from "Make Donation" quick-action |
| ContactUsEmail | string | 200 | NO | — | Email for "Contact Us" quick-action mailto target; falls back to Company.SupportEmail |
| FooterTaxDeductibleCopy | string | 500 | NO | — | Optional footer fine print (legal / tax-deductible line) |

**Uniqueness**: `(CompanyId)` is unique — enforce via filtered unique index.

**Status transition rules** (enforced at BE, not FE):
- Disabled → Active: admin click "Activate Portal" (sets `PortalStatus = 'Active'`)
- Active → Disabled: admin click "Disable Portal" (sets `PortalStatus = 'Disabled'`) — confirm dialog
- No Draft / Published / Closed / Archived states in this sub-type (singleton-config simplification)

**Source entity (READ-only for member surface)**: `mem."MemberEnrollments"` — query via new `GetMyMemberEnrollment` (filters by logged-in ContactId; includes joined MembershipTier + Currency + PaymentMode + Branch for the hero card / payment summary)

**NOT stored on MemberPortalConfig**:
- Member-level data (tier, fee, payment dates, auto-renew) — read live from MemberEnrollment
- Benefits content — would be read from MembershipTierBenefit if wired (v1: SERVICE_PLACEHOLDER hardcoded sample rows)
- Activity feed entries / Event RSVPs — SERVICE_PLACEHOLDER in v1

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()` / navigation) + Frontend Developer (ApiSelect)

### Admin Setup FK (light — singleton config has minimal FKs)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|------------------|----------------|---------------|-------------------|
| CompanyId | Company | `Base.Domain/Models/CompanyOrgModels/Company.cs` | (HttpContext) | CompanyName | — (server-resolved) |
| MakeDonationLinkSlug | OnlineDonationPage | `Base.Domain/Models/DonationModels/OnlineDonationPage.cs` | GetAllOnlineDonationPageList | PageTitle / Slug | OnlineDonationPageResponseDto |

### Member-Surface Data Sources (READ-only, scoped to logged-in member)

| Source | Aggregate / Read | Used In | Filter |
|--------|------------------|---------|--------|
| MemberEnrollment | single row | Hero Card + Payment Summary | ContactId = logged-in member; Status = 'Active' (latest enrollment if multiple) |
| MemberEnrollment.MembershipTier (Include) | TierName + ColorHex + TierLabel | Hero Card tier label | (via FK join) |
| MemberEnrollment.Currency (Include) | Symbol + Code | Payment Summary fee | (via FK join) |
| MemberEnrollment.PaymentMode (Include) | DataValueName | Payment Summary "Credit Card ••••4567" | (via FK join — last 4 SERVICE_PLACEHOLDER) |
| MembershipTierBenefit | benefit rows | Benefits table | tierId = enrollment.MembershipTierId — **SERVICE_PLACEHOLDER** in v1 (hardcoded sample rows) |
| GlobalDonation | recent rows | Recent Activity feed | ContactId = logged-in member — **SERVICE_PLACEHOLDER** in v1 (empty state) |
| Event | upcoming rows | Upcoming Events table | MemberOnly = true AND StartDate > now — **SERVICE_PLACEHOLDER** in v1 (empty state) |

**FK Resolution facts (verified)**:
- `MemberEnrollment` entity at `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/MemModels/MemberEnrollment.cs`, namespace `Base.Domain.Models.MemModels`. Fields verified: `MemberCode`, `ContactId`, `MembershipTierId`, `StartDate`, `EndDate`, `StatusId` (FK MasterData), `AutoRenew`, `MembershipFee`, `CurrencyId`, `PaymentModeId` (FK MasterData), `PaymentDate`, `PaymentReference`, `BranchId`.
- `MembershipTier` entity at `Base.Domain/Models/MemModels/MembershipTier.cs` — fields: `TierCode`, `TierName`, `DisplayName`, `TierLabel`, `ColorHex`, `SortOrder`, `PricingModelId`, `AnnualFee`, `MonthlyFee`.
- `MembershipTierBenefit` child entity at `Base.Domain/Models/MemModels/MembershipTierBenefit.cs` — fields: `BenefitText`, `IsIncluded`, `SortOrder`.
- Existing GQL queries: `GetAllMemberEnrollmentList`, `GetMemberEnrollmentById`, `GetMemberEnrollmentSummary`, `GetMemberEnrollmentPaymentHistory` — at `PSS_2.0_Backend/.../Base.API/EndPoints/Mem/Queries/MemberEnrollmentQueries.cs`. **`GetMyMemberEnrollment` does NOT exist — must be created (this prompt's responsibility).**
- No member-credential auth flow exists in the frontend — `(public)` route group exists at `src/app/[lang]/(public)`, but no `(member)` route group yet. NextAuth has staff `CredentialsProvider` only. **Member auth is SERVICE_PLACEHOLDER for v1.**

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Singleton Rules:**
- One MemberPortalConfig row per tenant (filtered unique index on `CompanyId`)
- `GetMemberPortalConfig` returns the row if exists, ELSE upserts default row with all booleans = true and `PortalStatus = 'Disabled'`
- `UpdateMemberPortalConfig` is the ONLY mutation — no Create / Delete (singleton)

**Lifecycle Rules:**
| State | Set by | Member-portal route behavior |
|-------|--------|------------------------------|
| Disabled | default + admin "Disable" action | 404 on `(member)/portal/dashboard` regardless of member auth |
| Active | admin "Activate Portal" action | Renders for any authenticated member of this tenant who has an Active MemberEnrollment |

**Required-to-Activate Validation:**
- BrandingAccentHex set (non-empty hex)
- WelcomeCopyTemplate set (non-empty)
- At least 1 nav-item enabled
- At least 1 section enabled
- (If QuickActionMakeDonationEnabled = true): MakeDonationLinkSlug must reference a published OnlineDonationPage (or quick-action auto-disabled with warning)
- (If QuickActionContactUsEnabled = true): ContactUsEmail set OR Company.SupportEmail set

**Conditional Rules:**
- If `BrandingLogoUrl` null → render Company.LogoUrl (or initials fallback)
- If `WelcomeCopyTemplate` contains `{FirstName}` token → render with member's Contact.FirstName
- If `MakeDonationLinkSlug` points to a non-Active OnlineDonationPage → quick-action button shows "Donation page currently unavailable" tooltip + disabled
- If member has NO active enrollment → portal renders "You have no active membership" empty state with "Join Now" CTA linking to public registration (SERVICE_PLACEHOLDER if no public reg page exists)

**Sensitive / Security-Critical Fields:**
| Field | Sensitivity | Display Treatment | Save Treatment | Audit |
|-------|-------------|-------------------|----------------|-------|
| Member's PaymentMode + last-4 | PCI / privacy | last 4 digits only, never full PAN | server-side decrypt-and-redact in DTO | log access |
| Member's ContactId resolution | privacy | NEVER accept ContactId from client — always resolve from auth token | server-only | log |
| GetMyMemberEnrollment auth | regulatory | **only renders own enrollment** — privilege-escalation test required | server-only ContactId scoping | log access |

**Member-route Hardening (authenticated-route concerns):**
- All `(member)/*` routes require member-credential auth (NextAuth `member-credentials` provider — SERVICE_PLACEHOLDER for v1)
- Server-side check on every render: logged-in user has `UserType = 'MEMBER'` (or equivalent role) AND maps to a Contact in the current tenant
- ContactId scoping in `GetMyMemberEnrollment` — resolves from auth token, NEVER from query arg
- No admin-shell chrome leaks into `(member)` layout
- CSRF token on any member-initiated POST (renew, RSVP, profile update — all SERVICE_PLACEHOLDER in v1)
- Tenant-isolation: member of Tenant A logging in MUST NOT see Tenant B's portal config

**Dangerous Actions** (require confirm + audit):
| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Activate Portal | Portal becomes live for all members of this tenant | "Activating the portal makes it accessible to all your members. Confirm?" | log + email tenant owner |
| Disable Portal | Portal returns 404 to all members | "Disabling will immediately log out and block members. Confirm?" | log + email tenant owner |
| Reset Branding to Defaults | Wipe accent colors + logo back to Company defaults | type-name confirm | log |

**Role Gating:**
| Role | Admin setup access | Member-portal access | Notes |
|------|---------------------|----------------------|-------|
| BUSINESSADMIN | full | yes (preview only — admin can view as a member via "Preview as Member" using sample ContactId) | full lifecycle |
| Member (authenticated via member-credentials) | no setup access | yes — sees own data | scoped to own ContactId |
| Anonymous | no | no — redirects to member-login | — |

**Workflow** (no cross-page workflow — singleton config has no approval flow):
- Admin saves config → autosave persists → preview reflects immediately
- Admin clicks "Activate Portal" → confirmation → status = Active → member route starts rendering for next member visit
- Member logs in → resolved ContactId → if member has Active enrollment in this tenant + Portal is Active → Dashboard renders. Else → empty state or 404.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: EXTERNAL_PAGE
**External-Page Sub-type**: `MEMBER_PORTAL` (**NEW sub-type — not in canonical 3 (DONATION_PAGE / P2P_FUNDRAISER / CROWDFUND)**. See §⑫ ISSUE-1 for the divergence rationale.)
**Storage Pattern**: `single-config-record` (singleton-per-tenant — diverges from canonical `single-page-record` / `parent-with-children`)
**Slug Strategy**: `N/A — singleton` (route is fixed at `(member)/portal/dashboard`; tenant resolution is via auth context, not URL slug)

**Lifecycle Set** (REQUIRED — stamp the states this page uses):
- `Disabled / Active` (2-state minimal — singleton-config simplification; no Draft/Published/Closed/Archived needed because no per-page lifecycle)

**Save Model**: `autosave-with-activate` (admin edits autosave silently; explicit "Activate Portal" promotes from Disabled → Active)

**Member-Surface Render Strategy**: `csr-after-shell` (member portal is auth-required — no SEO benefit from SSR; CSR with skeleton during auth check is acceptable). The admin live-preview pane mounts the same component tree but with a mocked member-context.

**Reason**: Member Portal is not a marketing funnel (where SSR matters for SEO and anonymous public is the audience). It is an authenticated experience consumed by existing members. The conversion goal is self-service renewal + engagement signal capture, not new-donor acquisition. Singleton-config storage matches the "one portal config per tenant" reality and avoids the slug-uniqueness machinery the canonical sub-types need.

**Backend Patterns Required (MEMBER_PORTAL):**
- [x] Get{Entity}Config query — singleton, tenant-scoped, upserts default if missing
- [x] Update{Entity}Config mutation — partial updates allowed (autosave-friendly)
- [x] Activate{Entity}Portal / Disable{Entity}Portal mutations (lifecycle)
- [x] Validate{Entity}ForActivate query — returns missing-fields list before allowing Activate
- [x] **NEW**: `GetMyMemberEnrollment` query — resolves ContactId from auth token; returns single MemberEnrollmentResponseDto for logged-in member; tenant-isolated; auth-gated (NOT anonymous-allowed)
- [x] Tenant scoping (CompanyId from HttpContext) — member route uses CompanyId from member's session
- [ ] Donation / RSVP / profile-update mutations — SERVICE_PLACEHOLDER in v1

**Frontend Patterns Required:**
- [x] Admin setup page — split-pane editor + live preview pane (member-portal mockup rendered inside preview iframe)
- [x] NEW route group `(member)` — separate from `(public)` and `(core)`
- [x] Member-credentials NextAuth provider — SERVICE_PLACEHOLDER (mock login form accepts any member-code or test contact email)
- [x] Member portal layout — branded header + nav + footer; NO admin shell, NO sidebar
- [x] Dashboard page — hero card + quick actions + benefits + payment summary + recent activity + upcoming events
- [x] Stub pages for 4 other nav items (My Profile / Benefits / Payments / Events) — SERVICE_PLACEHOLDER landing pages that say "Coming soon"
- [x] "Preview as Member" mode in admin — renders member portal with a sample MemberEnrollment row

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: MEMBER_PORTAL has TWO surfaces — admin setup AND member-authenticated portal.
> The member surface is **NOT anonymous** — auth gate is mandatory.
> The mockup `html_mockup_screens/screens/membership/member-portal.html` shows the MEMBER surface
> (Dashboard tab). Admin setup surface is described below from first principles.

### 🎨 Visual Treatment Rules

1. **Member portal is tenant-branded, not platform-branded** — header logo = tenant logo; accent colors = tenant accent; the PSS / Soruban platform branding is absent. Members should never see "PeopleServe" chrome.
2. **Admin setup mirrors what the member sees** — live preview pane shows the exact member portal output with current config; mobile/desktop preview toggle defaults to desktop (since members access mostly from desktop browsers — but mobile preview must still work).
3. **Preview banner is mockup-only** — the "MEMBER PORTAL PREVIEW — This is how members see their dashboard" banner in the mockup is purely an admin-preview affordance. It MUST NOT render on the real member portal route.
4. **Lifecycle clarity** — admin top-right shows "Status: ●Disabled" or "Status: ●Active" badge; the Activate button is dominant when Disabled, dimmed when Active.
5. **Quick action CTAs are member-friendly** — large hit targets, branded accent, sit above the fold. The 5 quick-action buttons are the primary conversion surface for renewal / donation.
6. **Trust signals on member portal** — security/auth indicator near login, tax-deductible note in footer, contact email link, privacy-policy link.
7. **Empty / "no active membership" state is honest** — if a logged-in member has no active enrollment, render a clear "You have no active membership" state with one CTA, not a broken card.
8. **Card chrome differentiates from anonymous EXTERNAL_PAGE** — Member Portal card hero (Membership Card) is a credit-card-style chip; DONATION_PAGE hero is a full-bleed image. They must NOT look the same.

**Anti-patterns to refuse**:
- Member portal rendering inside admin shell with sidebar visible
- Preview banner shipping to real members
- "Save and refresh to preview" in admin — preview must update live with autosave
- Member portal rendering ContactId from URL query arg (auth scoping defect)
- Recent Activity showing other members' donations
- Disabled status shown only by a tiny gray label without affecting accessibility
- Generic Lorem ipsum sample data in Benefits table — must be the 5 named sample rows from mockup if SERVICE_PLACEHOLDER
- Member portal in `(core)` route group — must be in `(member)` route group

---

### 🅼 Block M — MEMBER_PORTAL (this sub-type)

#### M.1 — Admin Setup UI (split-pane: editor left + live preview right)

**Page Layout:**
```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ Member Portal                                       Status: ●Disabled  [Activate]    │
│ Configure the post-login portal your members see                                    │
├─────────────────────────────────────────────┬───────────────────────────────────────┤
│ EDITOR (6 settings cards)                   │ LIVE PREVIEW                          │
│                                             │ [Desktop ▼] [Mobile]                  │
│  ┌───────────────────────────────────────┐  │ ┌────────────────────────────────┐  │
│  │ ① Branding             [ph:palette]   │  │ │ ▌MEMBER PORTAL PREVIEW         │  │
│  │  • Logo upload                        │  │ ├────────────────────────────────┤  │
│  │  • Accent color  [#0e7490] picker     │  │ │  [Logo] Member Portal  Welcome,│  │
│  │  • Accent light  [#06b6d4] picker     │  │ │                       Khalid A.│  │
│  │  • Welcome copy "Welcome, {FirstName}"│  │ ├────────────────────────────────┤  │
│  └───────────────────────────────────────┘  │ │  [Dashboard][Profile][Benefits]│  │
│  ┌───────────────────────────────────────┐  │ │  [Payments][Events]            │  │
│  │ ② Nav Visibility    [ph:list]         │  │ ├────────────────────────────────┤  │
│  │  ☑ Dashboard   ☑ My Profile           │  │ │  ┌──────────────────────────┐  │  │
│  │  ☑ Benefits    ☑ Payments             │  │ │  │  💎 PLATINUM MEMBER       │  │  │
│  │  ☑ Events                             │  │ │  │       [KA]                │  │  │
│  └───────────────────────────────────────┘  │ │  │  Khalid Al-Mansouri       │  │  │
│  ┌───────────────────────────────────────┐  │ │  │  MEM-001                  │  │  │
│  │ ③ Hero Card           [ph:identification]│ │ │  │  Member Since: Jan 2024  │  │  │
│  │  ☑ Show Hero Card                     │  │ │  │  Valid Until: Jan 15 2027 │  │  │
│  │  ☑ Show Download Card PDF button      │  │ │  │  ✓ Auto-Renewal: Active   │  │  │
│  └───────────────────────────────────────┘  │ │  │  [Download Card PDF]      │  │  │
│  ┌───────────────────────────────────────┐  │ │  └──────────────────────────┘  │  │
│  │ ④ Quick Actions    [ph:lightning]     │  │ │                                │  │
│  │  ☑ Renew Membership                   │  │ │  [Renew][Update][Benefits]     │  │
│  │  ☑ Update Profile                     │  │ │  [Donate][Contact]             │  │
│  │  ☑ View Benefits                      │  │ │                                │  │
│  │  ☑ Make a Donation                    │  │ │  ┌─────────┬──────────────┐    │  │
│  │     ↳ Link Slug: [give]  (validate)   │  │ │  │My Bene… │Payment Summ…│    │  │
│  │  ☑ Contact Us                         │  │ │  └─────────┴──────────────┘    │  │
│  │     ↳ Email:  [info@org.com]          │  │ │                                │  │
│  └───────────────────────────────────────┘  │ │  [Recent Activity]             │  │
│  ┌───────────────────────────────────────┐  │ │  [Upcoming Member Events]      │  │
│  │ ⑤ Sections           [ph:squares-four]│  │ │                                │  │
│  │  ☑ Benefits        ☑ Payment Summary  │  │ └────────────────────────────────┘  │
│  │  ☑ Recent Activity ☑ Upcoming Events  │  │                                       │
│  └───────────────────────────────────────┘  │                                       │
│  ┌───────────────────────────────────────┐  │                                       │
│  │ ⑥ Footer & Misc      [ph:note]        │  │                                       │
│  │  • Tax-deductible footer copy (text)  │  │                                       │
│  └───────────────────────────────────────┘  │                                       │
└─────────────────────────────────────────────┴───────────────────────────────────────┘
```

**Editor Sections** (one row per card — order matches preview render order):

| # | Section | Icon (Phosphor) | Save Model | Notes |
|---|---------|-----------------|------------|-------|
| 1 | Branding | `ph:palette` | autosave | Logo upload (SERVICE_PLACEHOLDER for file-upload service — store URL only), 2 color pickers, welcome copy text with `{FirstName}` token preview |
| 2 | Nav Visibility | `ph:list` | autosave | 5 checkboxes (Dashboard / My Profile / Benefits / Payments / Events) — Dashboard always remains enabled-but-locked (it's the landing page) |
| 3 | Hero Card | `ph:identification` | autosave | 2 toggles — Show Hero, Show Download PDF button (the Download Card PDF itself is SERVICE_PLACEHOLDER) |
| 4 | Quick Actions | `ph:lightning` | autosave | 5 toggles + 2 conditional sub-fields (Make Donation → ApiSelect over OnlineDonationPage list; Contact Us → email input) |
| 5 | Sections | `ph:squares-four` | autosave | 4 toggles (Benefits / Payment Summary / Recent Activity / Upcoming Events) |
| 6 | Footer & Misc | `ph:note` | autosave | Tax-deductible copy text area |

**Live Preview Behavior:**
- Updates on every keystroke (debounced 300ms)
- Mobile / Desktop toggle changes preview viewport width (Desktop default)
- Preview mounts an iframe pointing at `(member)/portal/dashboard?previewToken={token}&sampleMemberId={id}` — renders with mock auth + sample member data
- "Preview as Member" sample data: hardcoded sample MemberEnrollment object (Platinum tier, "Khalid Al-Mansouri", MEM-001, expires 2027-01-15)
- The "MEMBER PORTAL PREVIEW" purple banner ONLY renders when `previewToken` query arg is present — never on the real member route

**Page Actions:**
| Action | Position | Style | Confirmation |
|--------|----------|-------|--------------|
| Activate Portal | top-right (when Status=Disabled) | primary | "Activating the portal makes it accessible to all your members. Confirm?" |
| Disable Portal | top-right (when Status=Active) | secondary destructive | "Disabling will block members from accessing their portal. Confirm?" |
| Validate for Activation | inline (when Status=Disabled) | tertiary | Returns missing-fields list |
| Reset Branding | overflow menu | destructive | type-name "RESET" confirm |
| Preview as Member | top-right tertiary | — | Opens preview in new tab |

#### M.2 — Member Portal Page (authenticated route at `(member)/portal/dashboard`)

**Page Layout** (mockup `html_mockup_screens/screens/membership/member-portal.html` is canonical reference):

```
┌────────────────────────────────────────────────────────────────────────────┐
│ [Logo] Member Portal              [Dashboard][Profile][Benefits][Payments][Events]   Welcome, Khalid Al-Mansouri  [KA]  [Logout]│
├────────────────────────────────────────────────────────────────────────────┤
│  ╔══════════════════════════════════════════╗                              │
│  ║ [Org Logo]            💎 PLATINUM MEMBER ║                              │
│  ║                                          ║   ← Hero Membership Card     │
│  ║              [KA]                        ║      (gradient bg using      │
│  ║         Khalid Al-Mansouri               ║       tier.ColorHex)         │
│  ║         Member ID: MEM-001               ║                              │
│  ║         Member Since: January 2024       ║                              │
│  ║                                          ║                              │
│  ║         Valid Until                      ║                              │
│  ║         January 15, 2027                 ║                              │
│  ║         ✓ Auto-Renewal: Active           ║                              │
│  ║                                          ║                              │
│  ║                  [Download Card PDF]     ║                              │
│  ╚══════════════════════════════════════════╝                              │
│                                                                            │
│  [Renew Membership] [Update Profile] [View Benefits] [Make Donation] [Contact Us] │
│                                                                            │
│  ┌──────────────────────────┐ ┌──────────────────────────────────────┐   │
│  │ 🎁 My Benefits           │ │ 💳 Payment Summary                  │   │
│  │                          │ │                                      │   │
│  │ Quarterly Newsletter     │ │ Current Plan: Platinum — $1,000/yr  │   │
│  │ ✓ Subscribed  | Manage   │ │ Next Payment: Jan 15, 2027          │   │
│  │ Annual Impact Report     │ │ Payment Method: 💳 Card ••••4567    │   │
│  │ ✓ Available  | Download  │ │ Status: ✓ Active                    │   │
│  │ Member-Only Events       │ │                                      │   │
│  │ 3 upcoming | View Events │ │ [Update Payment Method] [View All]   │   │
│  │ Voting Rights            │ │                                      │   │
│  │ ✓ Eligible | Next AGM... │ │                                      │   │
│  │ Director Meeting         │ │                                      │   │
│  │ ✓ Available | Schedule   │ │                                      │   │
│  └──────────────────────────┘ └──────────────────────────────────────┘   │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ 🕒 Recent Activity                                                 │   │
│  │                                                                    │   │
│  │ Apr 10  ● Donated $1,500 to Orphan Care — Thank you!               │   │
│  │ Mar 28  ● Attended Fundraising Dinner (VIP table)                  │   │
│  │ Feb 15  ○ Annual Impact Report 2025 available — Download           │   │
│  │ Jan 15  ● Membership renewed automatically — $1,000                │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ 📅 Upcoming Member Events                                          │   │
│  │  Event                     Date         Location       RSVP        │   │
│  │  Fundraising Gala 2026     Apr 20 2026  Grand Hyatt    [✓ RSVP'd] │   │
│  │  Annual General Meeting    Sep 15 2026  Virtual        [RSVP]      │   │
│  │  Member Appreciation Dinner Nov 20 2026 JW Marriott    [RSVP]      │   │
│  └────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────┘
```

**Member-route behavior:**
- Member-credentials auth REQUIRED (SERVICE_PLACEHOLDER provider in v1 — accepts any member-code or test email)
- Unauthenticated → redirect to `(member)/login`
- Authenticated but no Active enrollment → "You have no active membership" empty state with "Join Now" CTA
- Authenticated + Portal Status = Disabled → 404
- Authenticated + Portal Status = Active + has enrollment → render Dashboard with config-respecting visibility

**Header**:
- Tenant logo (from `BrandingLogoUrl` or Company fallback) + "Member Portal" brand with first word in accent color
- 5 nav items (filtered by `Nav{Item}Enabled` config) — Dashboard active by default
- Right side: "Welcome, {FirstName}" greeting (from `WelcomeCopyTemplate`) + avatar initials + Logout button

**Hero Membership Card** (when `HeroCardEnabled = true`):
- Gradient background using `enrollment.MembershipTier.ColorHex` (with fallback)
- Org logo top-left, Tier label top-right (e.g. "💎 PLATINUM MEMBER" — emoji per tier hardcoded or from MembershipTier.IconCode)
- Centered: member initials in circle, full name, Member ID (= enrollment.MemberCode), Member Since (= enrollment.CreatedDate or StartDate formatted)
- Footer: "Valid Until {EndDate formatted}" + Auto-Renewal status (✓ Active if AutoRenew=true, ⚠ Off otherwise)
- "Download Card PDF" button when `HeroDownloadCardPdfEnabled = true` — SERVICE_PLACEHOLDER handler (toast "PDF download coming soon")

**Quick Actions Row** (each respects its `QuickAction{X}Enabled` toggle):
| Action | Handler |
|--------|---------|
| Renew Membership | nav to `crm/membership/membershiprenewal?action=renew&enrollmentId={id}` — SERVICE_PLACEHOLDER toast for member-side (since members can't access admin route) — v2 will route to a self-service renew page |
| Update Profile | SERVICE_PLACEHOLDER ("My Profile coming soon" toast) |
| View Benefits | scroll-anchor to Benefits section |
| Make a Donation | if `MakeDonationLinkSlug` set and OnlineDonationPage Active → window.open(`/{lang}/p/{slug}`); else SERVICE_PLACEHOLDER toast |
| Contact Us | mailto:`ContactUsEmail` or Company.SupportEmail |

**Benefits Table** (when `SectionBenefitsEnabled = true`):
- v1: SERVICE_PLACEHOLDER — render 5 hardcoded sample rows matching mockup:
  - Quarterly Newsletter / ✓ Subscribed / Manage Preferences
  - Annual Impact Report / ✓ Available / Download 2025 Report
  - Member-Only Events / 3 upcoming / View Events
  - Voting Rights / ✓ Eligible / Next AGM: Sep 2026
  - Director Meeting / ✓ Available / Schedule Meeting
- v2: replace with live MembershipTierBenefit rows when MemberPortal v2 expansion plans Benefits-data wiring (see ISSUE-3)

**Payment Summary** (when `SectionPaymentSummaryEnabled = true`):
- Current Plan: `enrollment.MembershipTier.TierName` — `currency.Symbol``enrollment.MembershipFee`/year (or "/month" by PricingModel)
- Next Payment: `enrollment.EndDate` formatted with member locale
- Payment Method: `enrollment.PaymentMode.DataValueName` + last-4 (SERVICE_PLACEHOLDER for last-4 — show "—" or hardcoded placeholder)
- Status: ✓ Active if enrollment.Status = ACT
- "Update Payment Method" → SERVICE_PLACEHOLDER toast / "View All Payments" → SERVICE_PLACEHOLDER nav to /payments stub

**Recent Activity** (when `SectionRecentActivityEnabled = true`):
- v1: SERVICE_PLACEHOLDER — empty state with calendar icon + "Your recent activity will appear here" copy
- (Mockup shows 4 rows of activity — those are sample data; v1 ships empty state per scope decision)

**Upcoming Member Events** (when `SectionUpcomingEventsEnabled = true`):
- v1: SERVICE_PLACEHOLDER — empty state with calendar icon + "Member-only events will appear here" copy
- (Mockup shows 3 rows of events with RSVP buttons — v2 wires Event entity + EventRsvp child)

**Footer**:
- Tax-deductible copy (from `FooterTaxDeductibleCopy` if set)
- Privacy Policy link / Contact / © Tenant Name {year}

**Edge states:**
- `PortalStatus = Disabled` → 404
- Logged-in member has no Active enrollment → empty state with Join Now CTA
- Logged-in member's tenant differs from portal config tenant → 403 (cross-tenant isolation)
- Member's MembershipTier has been deleted/inactivated → fall back to "Standard" tier label

#### M.3 — Member Login Page (`(member)/login`)

> v1 SERVICE_PLACEHOLDER — simple form (Member Code OR Email + dev-only "Enter" button) that creates a mock session and redirects to /portal/dashboard.
> v2 wires real `member-credentials` NextAuth provider with password / OTP.

```
┌────────────────────────────────────┐
│  [Tenant Logo]                     │
│  Member Login                      │
│                                    │
│  Member Code / Email               │
│  [_____________________]           │
│                                    │
│  [Sign In]                         │
│                                    │
│  Not a member yet? Join now        │
└────────────────────────────────────┘
```

#### M.4 — 4 Stub Pages (Profile / Benefits / Payments / Events)

For nav items 2-5, ship route page stubs at `(member)/portal/{tab}/page.tsx` that render a "Coming soon" placeholder with consistent member-portal chrome (same header / footer / sidebar). Each says "{TabName} is coming soon. For now, please contact your organization." with a Contact Us link.

---

### Shared blocks

#### Page Header & Breadcrumbs (admin setup)

| Element | Content |
|---------|---------|
| Breadcrumb | Setting › Public Pages › Member Portal |
| Page title | Member Portal |
| Subtitle | Configure the post-login portal your members see |
| Status badge | Disabled / Active (color-coded — gray vs green) |
| Right actions | [Activate Portal / Disable Portal] [Preview as Member] [Overflow: Reset Branding / Help] |

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading (setup) | Initial fetch | Skeleton matching 6-card layout |
| Loading (member portal) | Initial fetch | Skeleton matching hero + quick actions + sections |
| Empty (member portal — no enrollment) | Logged-in member has no Active enrollment | "You have no active membership" + "Join Now" CTA |
| Disabled (member portal) | PortalStatus = Disabled | 404 |
| Error (admin setup) | GET fails | Error card with retry |
| Error (member portal) | Auth or data error | Friendly error page with "Try again" + Contact Us |

---

## ⑦ Substitution Guide

> **First MEMBER_PORTAL sub-type** — this build sets the convention for any future member-authenticated EXTERNAL_PAGE.
> Closest sibling reference: `onlinedonationpage.md` (DONATION_PAGE) for split-pane editor + live preview architecture.
> Diverges from sibling in: route group (`(member)` not `(public)`), storage (singleton not list), lifecycle (2-state not 5-state), auth (member-credentials not anonymous).

| Canonical (OnlineDonationPage) | → This Entity (MemberPortal) | Context |
|-------------------------------|------------------------------|---------|
| OnlineDonationPage | MemberPortalConfig | Entity / class name |
| onlineDonationPage | memberPortalConfig | Variable / field names |
| online-donation-page | member-portal-config | kebab-case (FE folder + filename) |
| ONLINEDONATIONPAGE | MEMBERPORTAL | Menu code + GridCode (existing MEMBERPORTAL menu already seeded) |
| `fund` schema | `mem` schema | DB schema (reuse existing) |
| DonationModels group | MemModels group | Backend group name |
| DonationBusiness | MemBusiness | Business folder |
| SET_PUBLICPAGES parent menu | SET_PUBLICPAGES parent menu | (same parent) |
| `setting/publicpages/onlinedonationpage` | `setting/publicpages/memberportal` | Admin FE route |
| `(public)/p/[slug]` | `(member)/portal/dashboard` | Public-surface FE route — **different route group** |
| single-page-record | single-config-record | Storage pattern (singleton-per-tenant) |
| Draft/Published/Active/Closed/Archived | Disabled/Active | Lifecycle set |
| anonymous public route | member-authenticated route | Public-surface auth model |
| GetOnlineDonationPageBySlug | GetMyMemberEnrollment | Member-surface data query |

---

## ⑧ File Manifest

### Backend Files (single-config-record + new member-data query)

| # | File | Path |
|---|------|------|
| 1 | Entity | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/MemModels/MemberPortalConfig.cs` |
| 2 | EF Config | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/MemConfigurations/MemberPortalConfigConfiguration.cs` |
| 3 | Schemas (DTOs) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/MemSchemas/MemberPortalConfigSchemas.cs` |
| 4 | GetMemberPortalConfig Query | `Pss2.0_Backend/.../Base.Application/MemBusiness/MemberPortalConfigs/Queries/GetMemberPortalConfig.cs` |
| 5 | GetMemberPortalConfigPublic Query (member-route, auth-gated by member token, NOT anonymous) | `Pss2.0_Backend/.../MemberPortalConfigs/Queries/GetMemberPortalConfigForMember.cs` |
| 6 | ValidateForActivate Query | `Pss2.0_Backend/.../MemberPortalConfigs/Queries/ValidateMemberPortalForActivate.cs` |
| 7 | UpdateMemberPortalConfig Command (autosave-friendly partial update) | `Pss2.0_Backend/.../MemberPortalConfigs/Commands/UpdateMemberPortalConfig.cs` |
| 8 | ActivateMemberPortal / DisableMemberPortal Commands | `Pss2.0_Backend/.../MemberPortalConfigs/Commands/ActivateMemberPortal.cs` + `DisableMemberPortal.cs` |
| 9 | ResetMemberPortalBranding Command | `Pss2.0_Backend/.../MemberPortalConfigs/Commands/ResetMemberPortalBranding.cs` |
| 10 | **NEW** GetMyMemberEnrollment Query (auth-gated, resolves ContactId from token) | `Pss2.0_Backend/.../MemBusiness/MemberEnrollments/Queries/GetMyMemberEnrollment.cs` |
| 11 | Admin Mutations endpoint | `Pss2.0_Backend/.../Base.API/EndPoints/Mem/Mutations/MemberPortalConfigMutations.cs` |
| 12 | Admin Queries endpoint | `Pss2.0_Backend/.../Base.API/EndPoints/Mem/Queries/MemberPortalConfigQueries.cs` |
| 13 | Member Queries endpoint (auth-gated, NOT anonymous — extends MemberEnrollmentQueries) | append `GetMyMemberEnrollment` field to existing `MemberEnrollmentQueries.cs` |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IMemDbContext.cs` (interface) | `DbSet<MemberPortalConfig> MemberPortalConfigs { get; }` |
| 2 | `MemDbContext.cs` | DbSet + ApplyConfiguration |
| 3 | `MemMappings.cs` | Mapster mapping `MemberPortalConfig` ↔ `MemberPortalConfigResponseDto` ↔ `MemberPortalConfigRequestDto` |
| 4 | `DecoratorMemModules.cs` | Decorator entry for `MemberPortalConfig` |
| 5 | `DependencyInjection.cs` (Base.API or Base.Application) | Register CurrentMemberService / member-context resolver — SERVICE_PLACEHOLDER (resolves ContactId from auth token; v1 falls back to query arg in DEV) |

### Frontend Files

| # | File | Path |
|---|------|------|
| 1 | Admin DTOs | `Pss2.0_Frontend/src/domain/entities/mem-service/MemberPortalConfigDto.ts` |
| 2 | GQL Query (admin) | `Pss2.0_Frontend/src/infrastructure/lib/gql-queries/mem-queries/MemberPortalConfigQuery.ts` |
| 3 | GQL Mutation (admin) | `Pss2.0_Frontend/src/infrastructure/lib/gql-mutations/mem-mutations/MemberPortalConfigMutation.ts` |
| 4 | GQL Query (member-portal surface) | `Pss2.0_Frontend/src/infrastructure/lib/gql-queries/mem-queries/MyMemberEnrollmentQuery.ts` |
| 5 | Admin Setup Page (split-pane) | `Pss2.0_Frontend/src/page-components/setting/publicpages/memberportal/setup-page.tsx` |
| 6 | Admin 6 Section components | `Pss2.0_Frontend/.../memberportal/sections/branding-section.tsx` + `nav-visibility-section.tsx` + `hero-card-section.tsx` + `quick-actions-section.tsx` + `sections-section.tsx` + `footer-misc-section.tsx` |
| 7 | Admin Live Preview iframe wrapper | `Pss2.0_Frontend/.../memberportal/components/live-preview.tsx` |
| 8 | Admin Zustand store | `Pss2.0_Frontend/.../memberportal/store/member-portal-config-store.ts` |
| 9 | Admin Page Config | `Pss2.0_Frontend/src/infrastructure/lib/pages/setting/publicpages/memberportal.tsx` |
| 10 | Admin Route Page | `Pss2.0_Frontend/src/app/[lang]/(core)/setting/publicpages/memberportal/page.tsx` (verify or create) |
| 11 | NEW `(member)` route group layout | `Pss2.0_Frontend/src/app/[lang]/(member)/layout.tsx` — member-branded chrome (no admin sidebar) |
| 12 | Member Login (SERVICE_PLACEHOLDER) | `Pss2.0_Frontend/src/app/[lang]/(member)/login/page.tsx` + form component |
| 13 | Member Portal Dashboard | `Pss2.0_Frontend/src/app/[lang]/(member)/portal/dashboard/page.tsx` |
| 14 | Member Portal — Hero Card component | `Pss2.0_Frontend/src/page-components/member/portal/components/membership-hero-card.tsx` |
| 15 | Member Portal — Quick Actions row | `Pss2.0_Frontend/.../member/portal/components/quick-actions-row.tsx` |
| 16 | Member Portal — Benefits Table | `Pss2.0_Frontend/.../member/portal/components/benefits-table.tsx` (SERVICE_PLACEHOLDER hardcoded rows) |
| 17 | Member Portal — Payment Summary | `Pss2.0_Frontend/.../member/portal/components/payment-summary.tsx` |
| 18 | Member Portal — Recent Activity | `Pss2.0_Frontend/.../member/portal/components/recent-activity-feed.tsx` (SERVICE_PLACEHOLDER empty state) |
| 19 | Member Portal — Upcoming Events | `Pss2.0_Frontend/.../member/portal/components/upcoming-events-table.tsx` (SERVICE_PLACEHOLDER empty state) |
| 20 | Member Portal — Header / Nav | `Pss2.0_Frontend/.../member/portal/components/member-portal-header.tsx` (5 nav items respecting visibility config) |
| 21 | Member Portal — Footer | `Pss2.0_Frontend/.../member/portal/components/member-portal-footer.tsx` |
| 22 | Member Portal — Preview Banner (admin-preview only) | `Pss2.0_Frontend/.../member/portal/components/preview-banner.tsx` |
| 23 | 4 stub pages for non-Dashboard tabs | `Pss2.0_Frontend/src/app/[lang]/(member)/portal/profile/page.tsx`, `/benefits/page.tsx`, `/payments/page.tsx`, `/events/page.tsx` |
| 24 | Member-credentials NextAuth provider (SERVICE_PLACEHOLDER) | extend `Pss2.0_Frontend/src/infrastructure/lib/configs/auth.ts` with a dev-only member provider OR a parallel `member-auth.ts` config |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `mem-service-entity-operations.ts` (or create if missing) | `MEMBERPORTAL` operations config |
| 2 | `operations-config.ts` | Import + register MEMBERPORTAL operations |
| 3 | `pages/index.ts` barrel | Export MemberPortalPageConfig |
| 4 | NextAuth public-route allowlist | Add `(member)/login` to anonymous-allowed routes; gate `(member)/portal/*` behind member auth |
| 5 | OG meta-tag handler | Member portal is auth-gated; OG tags can be minimal (no SEO) — but ensure `noindex` on `(member)` routes |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL

MenuName: Member Portal
MenuCode: MEMBERPORTAL
ParentMenu: SET_PUBLICPAGES
Module: SETTING
MenuUrl: setting/publicpages/memberportal
GridType: EXTERNAL_PAGE

MenuCapabilities: READ, MODIFY, ACTIVATE, DISABLE, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, MODIFY, ACTIVATE, DISABLE

GridFormSchema: SKIP
GridCode: MEMBERPORTAL
---CONFIG-END---
```

> **Note**:
> - MEMBERPORTAL menu seed already exists at `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/Pss2.0_Global_Menus_List.sql:457` under SET_PUBLICPAGES. **No new menu seed needed** — only MenuCapabilities + RoleCapabilities seeded by this build's SQL script.
> - No CREATE / DELETE capabilities — singleton config has no Add or Remove.
> - ACTIVATE / DISABLE are NEW capabilities — register in MenuCapabilities table seed.
> - `GridFormSchema: SKIP` — custom UI, not RJSF.
> - `GridType: EXTERNAL_PAGE` already exists (used by OnlineDonationPage / EventRegPage / etc.).

---

## ⑩ Expected BE→FE Contract

**GraphQL Types:**
- Query type: `MemberPortalConfigQueries` (admin)
- Mutation type: `MemberPortalConfigMutations` (admin)
- Member Query (added to existing `MemberEnrollmentQueries`): `GetMyMemberEnrollment` — auth-gated; uses CurrentMemberService to resolve ContactId

### Admin Queries

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetMemberPortalConfig | `MemberPortalConfigResponseDto` | (none — singleton scoped by HttpContext.CompanyId) |
| ValidateMemberPortalForActivate | `ValidationResultDto` (missingFields: string[]) | (none) |

### Admin Mutations

| GQL Field | Input | Returns |
|-----------|-------|---------|
| UpdateMemberPortalConfig | `MemberPortalConfigRequestDto` (partial-update friendly — only non-null fields applied) | `int` (MemberPortalConfigId) |
| ActivateMemberPortal | (none — singleton) | `MemberPortalConfigResponseDto` |
| DisableMemberPortal | (none) | `MemberPortalConfigResponseDto` |
| ResetMemberPortalBranding | (none) | `MemberPortalConfigResponseDto` |

### Member Surface Queries (auth-gated by member-credentials, NOT anonymous)

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetMyMemberEnrollment | `MemberEnrollmentResponseDto` (with .Include of MembershipTier + Currency + PaymentMode + Branch) | (none — ContactId resolved from CurrentMemberService / auth token) |
| GetMemberPortalConfigForMember | `MemberPortalConfigPublicDto` (only visibility flags + branding — NOT admin notes) | (none — CompanyId resolved from member's session) |

### DTO Shapes

**MemberPortalConfigResponseDto** (admin):
```ts
{
  memberPortalConfigId: number;
  companyId: number;
  portalStatus: 'Disabled' | 'Active';
  brandingLogoUrl: string | null;
  brandingAccentHex: string;
  brandingAccentLightHex: string;
  welcomeCopyTemplate: string;
  navDashboardEnabled: boolean;
  navMyProfileEnabled: boolean;
  navBenefitsEnabled: boolean;
  navPaymentsEnabled: boolean;
  navEventsEnabled: boolean;
  heroCardEnabled: boolean;
  heroDownloadCardPdfEnabled: boolean;
  quickActionRenewEnabled: boolean;
  quickActionUpdateProfileEnabled: boolean;
  quickActionViewBenefitsEnabled: boolean;
  quickActionMakeDonationEnabled: boolean;
  quickActionContactUsEnabled: boolean;
  sectionBenefitsEnabled: boolean;
  sectionPaymentSummaryEnabled: boolean;
  sectionRecentActivityEnabled: boolean;
  sectionUpcomingEventsEnabled: boolean;
  makeDonationLinkSlug: string | null;
  contactUsEmail: string | null;
  footerTaxDeductibleCopy: string | null;
}
```

**MemberPortalConfigPublicDto** (member-route — privacy-filtered):
```ts
// Same as above MINUS: companyId (implicit), MakeDonationLinkSlug resolved to validated URL,
// contactUsEmail kept (members need it for Contact Us mailto)
```

**MemberEnrollmentResponseDto** (existing — reused; ensure Include navigation properties populated for GetMyMemberEnrollment):
```ts
{
  memberEnrollmentId: number;
  memberCode: string;
  contactId: number;
  contactName: string;          // resolved via Include
  membershipTierId: number;
  membershipTier: {
    tierName: string;
    tierLabel: string;
    colorHex: string;
    pricingModelCode: string;   // ANNUAL | MONTHLY | LIFETIME
  };
  startDate: string;
  endDate: string;
  status: { dataValueName: string; colorHex: string };
  autoRenew: boolean;
  membershipFee: number;
  currency: { code: string; symbol: string };
  paymentMode: { dataValueName: string };
  paymentDate: string | null;
  branch: { branchName: string } | null;
}
```

**Public DTO Privacy Discipline:**
| Field | Public (member-route) DTO | Reason |
|-------|--------------------------|--------|
| Other members' contact info | excluded | privacy — never expose tenant-mate members |
| Admin notes / audit fields | excluded | internal-only |
| CompanyId / cross-tenant FKs | excluded | tenant isolation |
| ContactId (resolved on server) | NOT accepted from client | privilege-escalation prevention |
| Member's own enrollment fields | included | what they're here for |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — admin setup at `/{lang}/setting/publicpages/memberportal` loads
- [ ] `pnpm dev` — `(member)/login` loads (anonymous-allowed)
- [ ] `pnpm dev` — `(member)/portal/dashboard` loads AFTER mock member login

**Functional Verification — MEMBER_PORTAL:**
- [ ] Admin: singleton GetMemberPortalConfig upserts default row if missing on first GET
- [ ] Admin: 6 settings cards each autosave (300ms debounce) without round-trip
- [ ] Admin: live preview iframe updates immediately when config changes
- [ ] Admin: Validate-for-Activate returns missing fields list when invalid; blocks Activate
- [ ] Admin: Activate Portal transitions Disabled → Active; status badge + action button swap
- [ ] Admin: Disable Portal transitions Active → Disabled; member route returns 404 immediately
- [ ] Admin: "Preview as Member" opens new tab with sample enrollment data
- [ ] Admin: Reset Branding wipes accent + logo back to defaults
- [ ] Admin: "MakeDonationLinkSlug" ApiSelect lists existing OnlineDonationPage rows; warns if selected is not Active
- [ ] Member: `(member)/login` SERVICE_PLACEHOLDER form accepts any member-code or email; creates mock session; redirects to dashboard
- [ ] Member: `(member)/portal/dashboard` shows Hero Card with REAL data: tier name, member name, member code, dates, auto-renew, currency-aware fee
- [ ] Member: tier color hex from MembershipTier drives card gradient
- [ ] Member: Auto-Renewal status reads from `enrollment.AutoRenew` (✓ Active or ⚠ Off)
- [ ] Member: Quick Actions row shows only enabled actions; each handler fires correctly (Renew SERVICE_PLACEHOLDER toast; Make Donation opens published page or SERVICE_PLACEHOLDER; Contact Us mailto)
- [ ] Member: Benefits table renders SERVICE_PLACEHOLDER 5-row sample data (NOT real MembershipTierBenefit rows in v1)
- [ ] Member: Payment Summary shows real data (currency-aware fee, real EndDate, real PaymentMode)
- [ ] Member: Recent Activity renders empty state (SERVICE_PLACEHOLDER)
- [ ] Member: Upcoming Events renders empty state (SERVICE_PLACEHOLDER)
- [ ] Member: section visibility respects each `Section{X}Enabled` toggle from admin config
- [ ] Member: nav visibility respects each `Nav{X}Enabled` toggle
- [ ] Member: stub pages (My Profile / Benefits / Payments / Events) render "Coming soon" placeholder
- [ ] Member: Logout button clears mock session + redirects to `(member)/login`
- [ ] Member: PortalStatus=Disabled returns 404 even for authenticated member
- [ ] Member: member of Tenant A cannot see Tenant B's portal (cross-tenant isolation test)
- [ ] Member: member with no Active enrollment sees "You have no active membership" empty state
- [ ] Preview banner: renders in admin preview pane ONLY; NEVER on real member route (regex search of built bundle for the banner string + manual visit)
- [ ] OG / SEO: `(member)/*` routes carry `noindex` meta — auth-gated content not indexed

**DB Seed Verification:**
- [ ] Admin menu visible at SET_PUBLICPAGES > MEMBERPORTAL (existing seed)
- [ ] Default MemberPortalConfig row seeded with PortalStatus = 'Disabled' + all toggles = true for the sample tenant
- [ ] MEMBERPORTAL MenuCapabilities seeded: READ, MODIFY, ACTIVATE, DISABLE, ISMENURENDER
- [ ] BUSINESSADMIN RoleCapabilities granted on all 4 caps
- [ ] Sample MemberEnrollment exists for testing `GetMyMemberEnrollment` (re-use seed from #59)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**MEMBER_PORTAL sub-type warnings (highest-priority):**

- **TWO render trees + NEW route group** — admin setup in `(core)` AND member portal in `(member)`. The member route group is NEW — not `(public)`, not `(core)`. Don't try to render the member portal as an anonymous public page.
- **Auth-gating is non-negotiable** — `(member)/portal/*` is auth-required. The current NextAuth has staff-only `CredentialsProvider`. V1 ships SERVICE_PLACEHOLDER member credentials (dev login form). DO NOT skip the auth gate "for testing" — that creates a permanent privacy hole.
- **ContactId is server-resolved, NEVER client-supplied** — `GetMyMemberEnrollment` must resolve ContactId from the member's auth token (CurrentMemberService) — never accept it as a query arg. Privilege escalation otherwise.
- **Tenant isolation** — member of Tenant A logging in must NOT see Tenant B's config or data. Resolve CompanyId from member's session, never from URL.
- **Singleton storage** — one row per tenant. UpdateMemberPortalConfig is the only write — no Create / Delete. Filtered unique index on `CompanyId`.
- **Preview banner is admin-only** — the purple "MEMBER PORTAL PREVIEW" banner is for the admin live-preview pane only. It MUST NOT render on the real `(member)/portal/dashboard` route. Hard-code a `previewToken` check.
- **Lifecycle is 2-state** — Disabled (default) / Active. No Draft / Published / Closed / Archived.
- **GridFormSchema = SKIP** — custom UI.
- **GridType = EXTERNAL_PAGE** — already exists; reuse.

**Sub-type novelty:**

| Concern | This screen's approach |
|---------|------------------------|
| First-of-kind `MEMBER_PORTAL` sub-type | Adds a 4th sub-type to the canonical 3 (DONATION_PAGE / P2P_FUNDRAISER / CROWDFUND). Update `_EXTERNAL_PAGE.md` and `MEMORY.md` after build completes. |
| First-of-kind singleton EXTERNAL_PAGE | Storage divergence — first time EXTERNAL_PAGE is singleton-per-tenant. Future SETTINGS_PAGE-style external pages can copy this convention. |
| First-of-kind `(member)` route group | Frontend route-group divergence. Future member-authenticated screens (My Profile, Payments, Events) will live in this group too. Treat layout decisions carefully. |
| Member-credentials auth missing | SERVICE_PLACEHOLDER — dev login form. ISSUE-2 tracks the eventual real implementation. |

**Service Dependencies** (UI-only — no backend service implementation):

- ⚠ **SERVICE_PLACEHOLDER: Member-credentials NextAuth provider** — UI fully implemented (member login form + mock session creation). Real password/OTP/SSO flow deferred to v2. ISSUE-2 tracks.
- ⚠ **SERVICE_PLACEHOLDER: Download Membership Card PDF** — button rendered + toggle in admin config; click handler shows "PDF download coming soon" toast. Real PDF generation deferred. ISSUE-4 tracks.
- ⚠ **SERVICE_PLACEHOLDER: Benefits table data** — per user's scoping decision (MemberEnrolment-only data sourcing). Hardcoded 5 sample rows match mockup. Real MembershipTierBenefit data wiring deferred to v2. ISSUE-3 tracks.
- ⚠ **SERVICE_PLACEHOLDER: Recent Activity feed** — empty state in v1. Real GlobalDonation + activity aggregation deferred. ISSUE-5 tracks.
- ⚠ **SERVICE_PLACEHOLDER: Upcoming Member Events table** — empty state in v1. Real Event entity + EventRsvp child entity deferred. ISSUE-6 tracks.
- ⚠ **SERVICE_PLACEHOLDER: Update Profile / My Profile tab** — stub "Coming soon" page. Real profile-edit form deferred. ISSUE-7 tracks.
- ⚠ **SERVICE_PLACEHOLDER: Update Payment Method** — toast handler. Real flow needs payment-gateway re-authorization + saved-card management. ISSUE-8 tracks.
- ⚠ **SERVICE_PLACEHOLDER: Self-service Renewal (member-side Renew action)** — toast for now. Admin route exists at `crm/membership/membershiprenewal` (#60); member-self-service path needs a member-facing renew page. ISSUE-9 tracks.
- ⚠ **SERVICE_PLACEHOLDER: Last-4 card digits** — placeholder "—" or hardcoded "••••0000". Real value needs PCI-compliant token store. ISSUE-10 tracks.

Full UI must be built (6 admin cards, live preview, member portal Dashboard with all sections, 4 stub pages, member login). Only the listed handlers are mocked.

**Pre-Flagged ISSUEs** (carry into build session):

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | HIGH | template-divergence | MEMBER_PORTAL is a NEW EXTERNAL_PAGE sub-type not in the canonical 3. After this build completes, propose updating `_EXTERNAL_PAGE.md` to add a Block M (or stamp it as the canonical reference for member-authenticated portals). Don't fork the template prematurely — let this build set the convention. |
| ISSUE-2 | HIGH | auth-infra | Member-credentials NextAuth provider does not exist. V1 ships SERVICE_PLACEHOLDER dev login. V2 needs real password/OTP/SSO. Until real auth lands, member portal is BUSINESSADMIN-preview only in production tenants. |
| ISSUE-3 | MED | data-scope | Per user's planning decision, Benefits table data is NOT wired from MembershipTierBenefit in v1 (despite the data being available). Hardcoded sample rows match mockup. Revisit when v2 adds Benefits tab. |
| ISSUE-4 | LOW | service | Download Card PDF generation service does not exist. Toggle in admin config + button on hero, but handler returns toast. |
| ISSUE-5 | MED | data-scope | Recent Activity feed is empty state in v1. GlobalDonation per-member rollup query + an activity-event aggregation are out of scope for this build. |
| ISSUE-6 | MED | entity-missing | EventRsvp child entity does not exist. Upcoming Events table is empty state. v2 will add EventRsvp + member-facing RSVP flow. |
| ISSUE-7 | LOW | stub-page | My Profile tab is a "Coming soon" stub. Real profile-edit form deferred. |
| ISSUE-8 | LOW | service | Update Payment Method is a toast. Real flow needs payment-gateway re-auth + saved-card management. |
| ISSUE-9 | MED | self-service | Renew Membership from member side currently toasts; admin route is at `crm/membership/membershiprenewal` but members can't access it. Member-side self-service renew flow is a future build. |
| ISSUE-10 | MED | pci | Card last-4 digits placeholder. Real value needs PCI token store on MemberEnrollment or saved-card child entity. |
| ISSUE-11 | LOW | route-group-novelty | `(member)` is a new route group. Confirm Next.js layout inheritance: `app/[lang]/(member)/layout.tsx` is the root for everything inside `(member)/*`. Make sure no admin-shell layout leaks. |
| ISSUE-12 | LOW | seed-folder | DB seed lives in `sql-scripts-dyanmic/` (preserve typo per house convention). |
| ISSUE-13 | LOW | preview-token | Admin "Preview as Member" passes `previewToken` + `sampleMemberId` query args. The member-portal page must accept these in admin-preview context but reject them on real member routes (server-side check that the request is from an admin session). |
| ISSUE-14 | LOW | locale | Dates on Hero Card + Payment Summary should format with member's locale (Next.js `[lang]` route segment). Default to tenant locale if member has no preference. |
| ISSUE-15 | LOW | multi-currency | Membership fee must render with `enrollment.Currency.Symbol` — never hardcode `$`. Verify across all currency-displaying cells. |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | planning | HIGH | template-divergence | New MEMBER_PORTAL sub-type | SUPERSEDED (v2 re-plan) — sub-type abandoned |
| ISSUE-2 | planning | HIGH | auth-infra | Member-credentials provider missing | SUPERSEDED (v2 re-plan) — unified real auth |
| ISSUE-3 | planning | MED | data-scope | Benefits data placeholder | OPEN |
| ISSUE-4 | planning | LOW | service | Card PDF generation missing | OPEN |
| ISSUE-5 | planning | MED | data-scope | Activity feed placeholder | OPEN |
| ISSUE-6 | planning | MED | entity-missing | EventRsvp entity missing | OPEN |
| ISSUE-7 | planning | LOW | stub-page | My Profile stub | OPEN |
| ISSUE-8 | planning | LOW | service | Update Payment Method placeholder | OPEN |
| ISSUE-9 | planning | MED | self-service | Member-side renew placeholder | OPEN |
| ISSUE-10 | planning | MED | pci | Last-4 digits placeholder | OPEN |
| ISSUE-11 | planning | LOW | route-group | `(member)` route group novelty | OPEN |
| ISSUE-12 | planning | LOW | seed-folder | sql-scripts-dyanmic typo preservation | OPEN |
| ISSUE-13 | planning | LOW | preview-token | Admin preview token security | OPEN |
| ISSUE-14 | planning | LOW | locale | Date locale formatting | OPEN |
| ISSUE-15 | planning | LOW | multi-currency | Currency symbol on fees | OPEN |
| ISSUE-16 | session 1 | MED | auth-permissions | `Permissions.Activate` / `Permissions.Disable` constants do not exist in `Permissions` static class. Activate/Disable handlers currently decorate with `Permissions.Modify` so behavior collapses to MODIFY at the CQRS layer (menu-level RoleCapabilities still seeded as ACTIVATE/DISABLE). Follow-up: add the two constants and switch decorators. | MOOT (v2 re-plan) — singleton lifecycle dropped |
| ISSUE-17 | session 1 | LOW | route-naming | Member login route is `/{lang}/member-login` (not `/{lang}/login` as spec said) because `(auth)/login` already owns `/login` for staff and Next.js route groups don't differentiate URLs. All references (auth guard, header logout, auth.ts allowlist) updated to `/member-login`. Update §⑥ M.3 + §⑫ when this prompt is referenced for v2 member-credentials work. | SUPERSEDED (v2 re-plan) — unified branded login |
| ISSUE-18 | session 1 | LOW | auth-shape | `(member)/layout.tsx` does NOT wrap children with NextAuth `SessionProvider` — v1 ships a localStorage-only mock session inside `MemberAuthGuard`. When ISSUE-2 lands a real member-credentials NextAuth provider, migrate guard to read from `useSession()` and remove the localStorage helper. | SUPERSEDED (v2 re-plan) — real NextAuth session |
| ISSUE-20 | session 3 | HIGH | data-model | **`Contact.UserId` = member's own login.** UPDATED Session 4: implemented as a **RENAME** of `Contact.StaffUserId` (Assigned-Staff concept DROPPED — never used in a real filter), single 1:1 `Contact.User` nav, no `User.ContactId`. BE code + SQL done; user ran the migration. | CLOSED (session 4) |
| ISSUE-21 | session 3 | HIGH | rbac-seed | MEMBERSHIP role (tenant-scoped) + member-portal menu tree (parent + 5 leaves) + MEMBERSHIP RoleCapabilities (`ISMENURENDER`) must be seeded; portal nav renders via `GetParentChildMenu` (NO Nav*Enabled booleans). | PARTIAL (S6) — seed authored (S5); S6 moved menu/landing URLs → `portal/*` and wired the member header to consume `PARENTCHILD_MENU_QUERY(CRM)→MEMBERPORTAL_AREA` (static fallback). PENDING DB run + live `GetParentChildMenu` verify for a MEMBERSHIP login |
| ISSUE-22 | session 3 | MED | branding-store | Member-portal branding moves to `sett.OrganizationSettings` `MEMBERPORTAL` ParamCode group; `mem.MemberPortalConfigs` table DROPPED. Admin screen reclassified CONFIG/SETTINGS_PAGE reusing the OrgSettings editor. | PARTIAL (S5) — OrgSettings `MEMBERPORTAL` group (8 ParamCodes) seeded via OrgSettingsDefaultSeeder + admin screen reclassified to `MemberPortalSettingsPage` (FE done, tsc clean). PENDING build+verify. Table DROP is Stage D (not yet) |
| ISSUE-23 | session 3 | MED | provisioning | `InviteMemberToPortal` (enrollment-triggered auto + manual resend) reusing #72 invite pipeline; sets `Contact.UserId` + MEMBERSHIP role + invite email. Pre-enrollment "register the plan" funnel OUT OF SCOPE. | OPEN |
| ISSUE-24 | session 3 | MED | dependency | v2 depends on role-landing BE (`Role.DefaultLandingUrl` persist + login returns it) — **USER building**; role-landing FE already shipped. | OPEN |
| ISSUE-19 | session 2 | **ARCH/HIGH** | re-architecture | **Whole sub-type is wrong.** Member nav is modelled as static booleans (`NavDashboardEnabled`, `SectionBenefitsEnabled`, …) on `mem.MemberPortalConfigs` — a parallel hardcoded menu duplicating the app's role+menu+capability RBAC. Re-plan onto: members = real Users linked to their Contact (needs Contact→User provisioning; `Contact.StaffUserId` ≠ member login); seed a tenant-scoped **MEMBERSHIP role**; portal menus render via existing `GetParentChildMenu` (ISMENURENDER per role — Roles are tenant-scoped, NO CompanyId-on-Menu needed); KEEP only the branding/theme config (logo/colors/welcome/login styling/status) as a SETTING screen (not an external page; portal is an authenticated in-app area). Depends on the new **role-based default landing page** feature (Role.DefaultLandingMenuId; precedence: per-user DefaultDashboardCode → PrimaryRoleId role landing → lowest Role.OrderBy role landing → masterdashboard; login redirect today HARDCODED to MASTER_URL in `useAuth/index.ts:94`). Plan role-default-page FIRST, then re-plan #61 via `/plan-screens`. See memory `project_member_portal_rearchitecture_role_based`. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-14 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt — admin setup + NEW `(member)` route group + member portal dashboard + 4 stubs + member-login SERVICE_PLACEHOLDER + GetMyMemberEnrollment query + singleton config CRUD.
- **Files touched**:
  - BE: 13 created (`MemberPortalConfig.cs`, `MemberPortalConfigConfiguration.cs`, `MemberPortalConfigSchemas.cs`, `GetMemberPortalConfig.cs`, `GetMemberPortalConfigForMember.cs`, `ValidateMemberPortalForActivate.cs`, `UpdateMemberPortalConfig.cs`, `ActivateMemberPortal.cs`, `DisableMemberPortal.cs`, `ResetMemberPortalBranding.cs`, `GetMyMemberEnrollment.cs`, `MemberPortalConfigQueries.cs`, `MemberPortalConfigMutations.cs`) + 5 modified (`IMemDbContext.cs`, `MemDbContext.cs`, `DecoratorProperties.cs`, `MemMappings.cs`, `MemberEnrollmentQueries.cs`).
  - FE: 31 created — admin (DTO + 2 GQL + setup-page + memberportal-store + section-card + live-preview + 6 sections + page-config + index barrel) + member (`(member)/layout.tsx` + member-login + dashboard + 4 stubs + login-page + dashboard-page + MemberAuthGuard + header + footer + preview-banner + hero-card + quick-actions-row + benefits-table + payment-summary + recent-activity-feed + upcoming-events-table + coming-soon-page + index barrel) + 7 modified barrels/wirings (mem-service index, mem-queries index, mem-mutations index, publicpages index, admin route stub overwrite, mem-service-entity-operations, auth.ts publicRoutes).
  - DB: `sql-scripts-dyanmic/MemberPortal-sqlscripts.sql` (created — default config row + MENUCAPS + RoleCapabilities; menu pre-existed at `Pss2.0_Global_Menus_List.sql:457`).
- **Deviations from spec**: 
  - Member login URL is `/{lang}/member-login` not `/{lang}/login` (route collision with staff `(auth)/login` — see ISSUE-17). 
  - No `IRegister` Mapster discovery pattern used (codebase convention is inline mappings in `MemMappings.ConfigureMappings()`). 
  - EF config auto-discovered via `ApplyConfigurationsFromAssembly` (no explicit `ApplyConfiguration` call).
  - Member auth gate is localStorage-only (not NextAuth `SessionProvider`) — see ISSUE-18.
  - `MakeDonationLinkSlug` field is text input (not ApiSelect) — defer until ApiSelectV2/V3 registry has OnlineDonationPage entry.
  - `Reset Branding` confirm is a plain AlertDialog (not type-name confirm) — singleton has no stable target name field.
  - `Permissions.Modify` used on Activate/Disable handler decorators (Permissions.Activate/Disable constants don't exist) — see ISSUE-16.
- **Known issues opened**: ISSUE-16 (Permissions.Activate/Disable constants missing — MED) · ISSUE-17 (member-login URL renamed — LOW) · ISSUE-18 (localStorage mock session vs NextAuth SessionProvider — LOW)
- **Known issues closed**: None
- **Next step**: (empty for COMPLETED — defer ISSUEs 1, 2, 3, 5, 6, 9, 16, 17, 18 to follow-up sessions)

### Session 2 — 2026-06-15 — ARCH-DECISION — HANDOFF (no code change)

- **Scope**: Architecture review (user-raised). Concluded the MEMBER_PORTAL static-external-page model is wrong: member nav is encoded as static booleans on `mem.MemberPortalConfigs`, duplicating the app's role+menu+capability RBAC. Decided to re-architect onto a real **MEMBERSHIP role** (members = real Users linked to their Contact; menus via existing `GetParentChildMenu` ISMENURENDER filter; Roles are already tenant-scoped so no CompanyId-on-Menu needed). KEEP only the branding/theme config (reclassified SETTING screen, not an external page). New companion feature: **role-based default landing page** (Role.DefaultLandingMenuId; precedence per-user override → PrimaryRoleId → lowest Role.OrderBy → masterdashboard; login redirect today hardcoded to MASTER_URL in `useAuth/index.ts:94`).
- **Files touched**: None (analysis + planning only).
- **Deviations from spec**: This is itself a Spec change — handed off to `/plan-screens` per /continue-screen guardrails.
- **Known issues opened**: ISSUE-19 (ARCH/HIGH — re-architecture; see Known Issues table).
- **Known issues closed**: None.
- **Next step**: (1) `/plan-screens` the role-based default landing page feature FIRST (Role field + #70 Role screen + login redirect). (2) Then `/plan-screens #61` to re-blueprint Member Portal as branding-config SETTING screen + authenticated in-app member area driven by the MEMBERSHIP role. Status left COMPLETED until re-plan begins. See memory `project_member_portal_rearchitecture_role_based`.

### Session 3 — 2026-06-15 — RE-PLAN (v2 re-architecture) — COMPLETED (no code change)

- **Scope**: Re-planned #61 onto the correct architecture (see the **ⓥ2 RE-ARCHITECTURE** block at the top of this prompt — authoritative). Grounded the data model against the live schema: confirmed `Contact.StaffUserId` is FK-mapped to `auth.Users` and means "managed-by" (used for staff data-scoping), so it CANNOT be reused for member login. Settled the member↔login link as a **new `Contact.UserId`** column.
- **Locked decisions (via user)**: (1) branding → tenant OrgSettings `MEMBERPORTAL` group, DROP `mem.MemberPortalConfigs`; (2) member auth → unified tenant-branded login + role-based default landing page (no `(member)/login`, no localStorage mock); (3) provisioning → enrollment-triggered "Invite to Portal" (auto + manual resend) reusing #72 invite pipeline, pre-enrollment funnel out of scope; (4) nav/sections → real `auth.Menus` gated by MEMBERSHIP `RoleCapabilities` via `GetParentChildMenu`, drop all boolean toggles.
- **Files touched**: None (planning only — this prompt updated: frontmatter status → PROMPT_READY, v2 block inserted, ISSUE table updated, this entry).
- **Deviations from spec**: v2 abandons the v1 MEMBER_PORTAL external-page model wholesale (intentional).
- **Known issues opened**: ISSUE-20..24 (data model, RBAC seed, branding store, provisioning, role-landing dependency).
- **Known issues closed**: ISSUE-1/2/17/18 → SUPERSEDED; ISSUE-16 → MOOT.
- **Next step**: USER finishes role-landing BE §④ (`Role.DefaultLandingUrl` persist + login returns it). Then build v2 per the re-architecture block's build sequence (§H): `Contact.UserId` + MEMBERSHIP role/menu/RoleCapabilities + OrgSettings `MEMBERPORTAL` group → `InviteMemberToPortal` → member layout role-menu render + real-auth guard + branding settings screen → verify §F across ≥2 tenants.

### Session 5 — 2026-06-15 — BUILD (v2 Stage A: seeds+data + branding FE) — PARTIAL

> NOTE: Session 4 (the `Contact.StaffUserId`→`UserId` rename + user-run migration) landed earlier without its own § Sessions entry — it is recorded in the ⓥ2 block §B/§E and ISSUE-20. This is the first **code-build** session of v2. Prereqs verified live this session: `Contact.UserId` ✅, `Role.DefaultLandingUrl` + `GetUserCredential` landing-resolution ✅ (USER's role-landing BE), `GetParentChildMenu` ✅, #72 invite pipeline ✅, OrganizationSettings business layer ✅.

- **Scope**: Build-sequence §H step 2 (additive seeds + data, NO v1 deletes — user chose "Stage A only") + the user-chosen FE increment (branding admin screen → OrgSettings editor). Backend build/seed-run is the USER's (they declined the in-session `dotnet build`).
- **Files touched**:
  - BE: `Base.Application/.../MemBusiness/MemberEnrollments/Queries/GetMyMemberEnrollment.cs` (modified — resolves ContactId from `Contact.UserId` via auth UserId claim; dropped v1 latest-active-in-tenant placeholder) · `Base.Infrastructure/Seeders/OrgSettingsDefaultSeeder.cs` (modified — new `MEMBERPORTAL` group + 8 ParamCodes: STATUS/LOGO_URL/ACCENT_HEX/ACCENT_LIGHT_HEX/WELCOME_COPY/FOOTER_COPY/CONTACT_EMAIL/DONATION_SLUG) · `Base.Application/.../OrganizationSettings/Seeders/IOrgSettingsDefaultSeeder.cs` (modified — baseline bumped ExpectedGroupCount 12→13, ExpectedSettingCount 111→119 so existing tenants re-seed).
  - DB: `sql-scripts-dyanmic/MemberPortal-v2-rbac-seed.sql` (created — per-tenant MEMBERSHIP role w/ `DefaultLandingUrl='crm/membership/memberportal'`; global `MEMBERPORTAL_AREA` parent + 5 leaf menus MP_DASHBOARD/PROFILE/BENEFITS/PAYMENTS/EVENTS under CRM module; MenuCapabilities READ+ISMENURENDER; per-tenant MEMBERSHIP RoleCapabilities + RoleModules(CRM); `LANDINGPAGE` MasterDataType + 2 options). Idempotent. **USER runs after build.**
  - FE: `presentation/components/page-components/setting/publicpages/memberportal/member-portal-settings-page.tsx` (created — MEMBERPORTAL-group OrgSettings editor: reuses `GET_ORGANIZATION_SETTINGS_VIEW_QUERY` + `BULK_UPDATE_ORG_SETTINGS_MUTATION` `{request:{items:[{organizationSettingId,paramCode,currentValue}]}}`, dirty-map, ColorPickerInput, status segmented toggle, lightweight live preview) · `.../memberportal/index.ts` (modified — additive export) · `presentation/pages/setting/publicpages/memberportal.tsx` (modified — wrapper now renders `MemberPortalSettingsPage`; route + `menuCode:"MEMBERPORTAL"` gate unchanged). tsc clean.
- **Deviations from spec**: (1) Only the branding settings screen built on the FE — member-layout role-menu render + "Invite to Portal" action + all v1 deletes deferred (user scoped to Stage A / additive). (2) **`LANDINGPAGE` masterdata is seeded by THIS file** though role-landing spec §④a assigns it to the USER's role-landing BE — coordinate to avoid a double-seed (both are idempotent WHERE-NOT-EXISTS, so a collision is harmless). (3) `GetMyMemberEnrollment` resolves company via `GetCurrentUserStaffCompanyId()` (reads the `CurrentCompanyId` claim — valid for member logins despite the "Staff" name). (4) Logo field is a plain URL input (file-upload remains SERVICE_PLACEHOLDER, [[ISSUE-4]] family). (5) v1 boolean-card section files left orphaned in place (no-deletes scope) — they are no longer imported.
- **Known issues opened**: None.
- **Known issues closed**: None. ISSUE-21 (RBAC seed) → seed authored, PENDING DB run+verify. ISSUE-22 (branding store) → OrgSettings `MEMBERPORTAL` group + reclassified admin editor DONE on FE, PENDING build+verify.
- **Next step**: (USER) `dotnet build` BE + run `MemberPortal-v2-rbac-seed.sql` + confirm OrgSettings reseed (first `organizationSettingsView` call reseeds to 119/13). Then resume: **Stage B** `InviteMemberToPortal` (+ `CreateMemberEnrollment` hook + resend mutation); **Stage C remainder** member layout role-menu render (`GetParentChildMenu`, real NextAuth guard) + "Invite to Portal" action on MemberEnrollment grid; **Stage D** drop v1 `MemberPortalConfig` subsystem + dead v1 FE; **Stage E** verify §F across ≥2 tenants incl. a member-who-is-also-volunteer.

### Session 6 — 2026-06-15 — BUILD (v2 Stage C: login + dashboard, FE) — PARTIAL

> Increment chosen by user: "setup the login + dashboard ... then later the settings configuration screen." Layout fork resolved by user → **"Reuse (member) group at /portal"** (member-branded chrome, NO admin shell; swap localStorage→NextAuth; nav→GetParentChildMenu; move seed URLs `crm/membership/memberportal*` → `portal/*`). USER owns BE build + seed run. Recon confirmed: role-landing redirect already live in `useAuth` (`router.push(/en/${defaultLandingUrl})`); unified branded login `(auth)/login` already SSR-tenant-resolves; app-wide auth is currently **soft** (RouteGuard is a no-op, middleware only does locale) so the real member gate = role-landing + server-side `GetMyMemberEnrollment` ContactId-from-token.

- **Scope**: FE "login + dashboard" half of Stage C (member-layout role-menu render + real-auth guard). NO v1 deletes (kept no-deletes discipline). Branding/status-from-OrgSettings + "Invite to Portal" action deferred to later increments.
- **Files touched**:
  - DB: `sql-scripts-dyanmic/MemberPortal-v2-rbac-seed.sql` (modified — MEMBERSHIP `DefaultLandingUrl`, the 5 leaf menu URLs, and the `LANDINGPAGE` Member-Portal `DataValue` all moved `crm/membership/memberportal*` → `member-portal/dashboard`|`member-portal/profile`|`member-portal/benefits`|`member-portal/payments`|`member-portal/events` (Session 5 rename from `portal/*` → `member-portal/*`, matching the `(member)/member-portal/*` route group; leaves room for a future `volunteer-portal/*`). **USER re-runs.**
  - FE: `app/[lang]/(member)/layout.tsx` (modified — comment only; guard is now real-auth) · `.../member/portal/components/member-auth-guard.tsx` (rewrote — localStorage mock → NextAuth `useSession`; unauthenticated → `/{lang}/login`; `previewToken` bypass kept; removed `get/set/clearMemberSession` + `MemberSession`) · `.../member/portal/components/member-portal-header.tsx` (rewrote nav — RBAC-driven from `PARENTCHILD_MENU_QUERY(moduleCode:"CRM")` → `MEMBERPORTAL_AREA` childMenus, ordered, with a static 5-item fallback; logout → `signOut({callbackUrl:/{lang}/login})`) · `.../member/portal/login-page.tsx` (rewrote — v1 mock member-login → redirect to unified `/login`, so legacy `/member-login` bookmarks don't 404) · `.../member/portal/dashboard-page.tsx` (modified — dropped `GET_MEMBER_PORTAL_CONFIG_FOR_MEMBER` + its `portalStatus!=='Active'→notFound` trap (v1 config defaults Disabled → would 404); renders with an all-on `DEFAULT_CONFIG`; keeps `GET_MY_MEMBER_ENROLLMENT`, ContactId resolved server-side from token). `pnpm tsc --noEmit` clean.
- **Deviations from spec**: (1) Member-side **branding/status still uses component defaults** — the OrgSettings `MEMBERPORTAL` read is intentionally deferred to the settings-config increment (clean seam; avoids the dead-config Disabled trap now). (2) v1 `(member)/member-login` route + `login-page.tsx` component **kept as a redirect** (not deleted — no-deletes discipline); `GET_MEMBER_PORTAL_CONFIG_FOR_MEMBER` query doc + the v1 config-toggle child props left in place (orphaned). (3) Double `ApolloWrapper` in the member layout left as-is (root `[lang]/layout` already provides one — redundant but harmless). (4) MEMBERSHIP-role enforcement is **soft** — guard requires a NextAuth session; role-scoping is enforced naturally by the role-filtered menu query + the enrollment query's empty-state (matches the app's existing soft-auth posture).
- **Known issues opened**: None.
- **Known issues closed**: ISSUE-2 / ISSUE-17 / ISSUE-18 (member-auth localStorage mock / `/member-login` URL / mock session) — CLOSED: real NextAuth session + unified `/login` + `signOut`. (Already SUPERSEDED in §G; now also code-closed on the FE.)
- **Next step**: (USER) re-run the updated `MemberPortal-v2-rbac-seed.sql` (URLs now `portal/*`) + finish role-landing BE so `login` returns `defaultLandingUrl='portal/dashboard'`; then live-verify: MEMBERSHIP member logs in at `/login` → lands `/en/portal/dashboard` → sees hero/payment from their own enrollment, nav from `GetParentChildMenu`, Sign-out → `/login`. Then resume: **settings-config increment** = wire member-side branding/status to the OrgSettings `MEMBERPORTAL` group (replaces `DEFAULT_CONFIG`); **Stage B** `InviteMemberToPortal`; **Stage D** drop v1 `MemberPortalConfig` subsystem + the now-orphaned v1 FE (member-login route, config query, boolean-card files); **Stage E** verify §F across ≥2 tenants.
