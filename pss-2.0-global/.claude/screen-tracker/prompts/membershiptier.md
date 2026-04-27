---
screen: MembershipTier
registry_id: 58
module: Membership
status: COMPLETED
scope: FULL
screen_type: MASTER_GRID
complexity: High
new_module: YES — `mem` schema (IMemDbContext, MemDbContext, MemMappings, DecoratorMemModules)
planned_date: 2026-04-24
completed_date: 2026-04-24
last_session_date: 2026-04-24
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (`html_mockup_screens/screens/membership/membership-tiers.html`)
- [x] Existing code reviewed (FE stub confirmed 4-line "Need to Develop" at `[lang]/crm/membership/membershiptier/page.tsx`; no BE entity; no `mem` schema)
- [x] Business rules extracted
- [x] FK targets resolved (Currency, MasterData, self-FK verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt Sections ①-④ pre-complete; agent phase skipped per token-budget directive)
- [x] Solution Resolution complete (Section ⑤ pre-complete)
- [x] UX Design finalized (Section ⑥ pre-complete)
- [x] User Approval received (pre-filled CONFIG ⑨ auto-approved per user directive "do not ask for repeated yes/no confirmations")
- [x] **NEW MODULE bootstrap** — `mem` schema: `IMemDbContext`, `MemDbContext`, `MemMappings`, `DecoratorMemModules` created and wired (IApplicationDbContext inheritance, DependencyInjection.ConfigureMappings, GlobalUsing ×3, DependencyInjection.AddDbContext entry)
- [x] Backend code generated (MembershipTier + MembershipTierBenefit child + 11 CRUD files + diff-persist child-handling)
- [x] Backend wiring complete (DbSet lines, MappingsConfigure, Decorator entry, MasterData seed)
- [x] Frontend code generated (card-grid index + slide-panel form + benefits child-grid + comparison-table widget)
- [x] Frontend wiring complete (entity-operations, operations-config, card-variant-registry, sidebar, route)
- [x] DB Seed script generated (menu + grid + MASTER_GRID card-grid + GridFormSchema SKIP + 4 MasterDataType seeds + 5 sample rows)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` — no errors (new `mem` schema registered in EF design snapshot)
- [ ] `pnpm dev` — page loads at `/{lang}/crm/membership/membershiptier`
- [ ] CRUD flow tested (Create → Read → Update → Toggle → Delete including benefit child collection)
- [ ] Horizontal-scroll card grid renders 5 seeded tiers with emoji, name, label, price, member count, Edit + kebab menu
- [ ] Top-border color per tier card matches `colorHex` (Bronze #cd7f32, Silver #c0c0c0, Gold #ffd700, Platinum #e5e4e2, Lifetime #f59e0b)
- [ ] Slide-panel (520px right) opens on "+New Tier" and on card "Edit" click
- [ ] Overlay-click, ESC, Cancel close without save; body-scroll locks while open
- [ ] All 4 form sections render (Tier Details / Pricing / Benefits / Eligibility & Rules)
- [ ] PricingModel dropdown; selecting "Free" disables/zeros fee inputs; "Pay What You Want" shows hint; "Fixed Monthly" hides AnnualFee; etc.
- [ ] Benefits child-grid: checkbox (IsIncluded) + text + edit/delete per row + "Add Custom Benefit" dashed button; diff-persist on Save
- [ ] Auto-Renew Default toggle persists; Grace Period select (15/30/60/90) persists
- [ ] Currency + PricingModel + DowngradePolicy + MinDonationHistory ApiSelectV2 all load MasterData / Currency
- [ ] Upgrade Path self-FK loads siblings (excluding current tier on edit)
- [ ] Maximum Members "Unlimited" option maps to null; "50 / 100 / Custom" accepts integer
- [ ] Benefits Comparison Table (below card grid) renders matrix: rows=distinct benefit texts across all tiers, cols=tiers (emoji + name), cells=check-yes/check-no
- [ ] Kebab menu actions: Edit (opens drawer), View Members (nav to `memberlist?tierId=X` — SERVICE_PLACEHOLDER until #59 built), Duplicate (clones tier into new draft open in drawer), Deactivate (toggle IsActive), Delete (confirm dialog → soft delete)
- [ ] `memberCount` renders 0 with tooltip "Computed when Member Enrollment module is available" (SERVICE_PLACEHOLDER)
- [ ] DB Seed — menu `MEMBERSHIPTIER` visible in sidebar under `CRM_MEMBERSHIP`; 4 MasterDataTypes seeded; 5 sample Tiers + benefit rows seeded

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: MembershipTier
Module: Membership
Schema: `mem` (**NEW — first entity in this schema**)
Group: `Mem` (Models=`MemModels`, Configs=`MemConfigurations`, Schemas=`MemSchemas`, Business=`MemBusiness`, Endpoints=`Mem`)

Business:
The Membership Tier screen is the foundational master of the Membership module. It defines the membership levels offered by the NGO (e.g., Bronze, Silver, Gold, Platinum, Lifetime), including per-tier pricing, benefits, eligibility rules, and upgrade/downgrade policies. Membership operations staff and program managers use this screen to configure the tier catalogue before enrolling any members — every `MemberEnrolment` (#59) and `MembershipRenewal` (#60) row FKs back to a tier defined here, so this master must exist before either can be created. The screen also provides a visual "Benefits Comparison" table below the tier cards, giving admins a matrix view of which benefit is included in which tier for quick auditing. Member counts shown on each card are computed aggregates from `MemberEnrolment` — because that entity is not yet built, counts render as SERVICE_PLACEHOLDER (`0` with tooltip) until #59 lands.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> 2 entities total (1 parent + 1 child 1:M). Audit columns inherited from `Entity`.

### Parent Entity — `mem."MembershipTiers"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| MembershipTierId | int | — | PK | — | Primary key |
| TierCode | string | 50 | YES | — | Unique per Company (e.g., `BRONZE`, `GOLD`, `PLATINUM`) |
| TierName | string | 100 | YES | — | Display name shown on card (e.g., "Gold") |
| DisplayName | string | 150 | NO | — | Marketing label shown to members (e.g., "Gold Member") — falls back to TierName when null |
| TierLabel | string | 50 | NO | — | Short classification shown in card subtitle (e.g., "Basic", "Standard", "Premium", "VIP", "Elite"). Free text; `NULL` allowed |
| Description | string | 1000 | NO | — | Tier description / marketing blurb |
| IconEmoji | string | 10 | NO | — | Single emoji, default 🏅 |
| ColorHex | string | 7 | NO | — | `#RRGGBB`, default `#d97706` (mem-accent amber) — drives card top-border color |
| SortOrder | int | — | YES | — | Display order in card list (lowest first). Default: next multiple of 10 on create |
| PricingModelId | int | — | YES | `sett.MasterDatas` (TypeCode `MEMBERSHIPPRICINGMODEL`) | FIXED_ANNUAL / FIXED_MONTHLY / TIERED / PWYW / FREE |
| AnnualFee | decimal(18,2)? | — | NO | — | Fixed annual amount. Required when PricingModelCode=`FIXED_ANNUAL`. Null when `FREE`/`PWYW` |
| MonthlyFee | decimal(18,2)? | — | NO | — | Fixed monthly amount. Required when PricingModelCode=`FIXED_MONTHLY`; optional sidebar on `FIXED_ANNUAL`. Null when `FREE`/`PWYW` |
| SetupFee | decimal(18,2) | — | YES | — | One-time joining fee. Default `0`. Allowed ≥ 0 |
| CurrencyId | int? | — | NO | `shared.Currencies` | Default currency for fees. Falls back to Company default when null |
| AutoRenewDefault | bool | — | YES | — | Default auto-renew checkbox state presented to new members. Default `true` |
| GracePeriodDays | int | — | YES | — | Days of lapsed-access grace after renewal due. Enum-capped values: 15 / 30 / 60 / 90. Default `30` |
| MinDonationHistoryId | int? | — | NO | `sett.MasterDatas` (TypeCode `MEMBERSHIPMINDONATION`) | NONE / $100+ / $500+ / $1,000+ — drives member-eligibility filter |
| UpgradeFromTierId | int? | — | NO | `mem.MembershipTiers` (self-FK) | Tier that a member must currently hold to upgrade into this one. Null = no upgrade-path restriction |
| DowngradePolicyId | int | — | YES | `sett.MasterDatas` (TypeCode `MEMBERSHIPDOWNGRADEPOLICY`) | ALLOW / PREVENT / PRORATA. Default `ALLOW` |
| MaxMembers | int? | — | NO | — | Cap on concurrent members. `NULL` = unlimited. `0` not allowed (use `IsActive=false` to close tier) |
| CompanyId | int? | — | — | `app.Companies` | Tenant scope (HttpContext) |

(IsActive, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate inherited from `Entity` base.)

### Child Entity — `mem."MembershipTierBenefits"` (1:Many via MembershipTierId, cascade delete)

| Field | C# Type | MaxLen | Required | Notes |
|-------|---------|--------|----------|-------|
| MembershipTierBenefitId | int | — | PK | — |
| MembershipTierId | int | — | YES | FK parent (cascade) |
| BenefitText | string | 500 | YES | Free-text benefit label (e.g., "Quarterly newsletter (exclusive content)") |
| IsIncluded | bool | — | YES | Checkbox in mockup; default `true` (unchecked rows mean tier SHOULD show the benefit in comparison table but mark as ✗) |
| SortOrder | int | — | YES | Display order within tier. Default: row index on create |

(IsActive, audit cols inherited from `Entity`.)

### Projected / computed fields on `MembershipTierResponseDto` (NOT stored; returned by GetAll/GetById projections)

| Field | Computation | Buildable Now? |
|-------|-------------|----------------|
| pricingModelName / pricingModelCode | nav join on MasterData | ✅ YES |
| downgradePolicyName / downgradePolicyCode | nav join on MasterData | ✅ YES |
| minDonationHistoryName / minDonationHistoryCode | nav join on MasterData | ✅ YES |
| currencyCode | nav join on Currency | ✅ YES |
| upgradeFromTierName | self-FK nav join | ✅ YES |
| benefits | inline collection projection from `MembershipTierBenefits` | ✅ YES (load on GetById; summary on GetAll can inline OR send via separate round-trip — see §⑩) |
| includedBenefitCount | `Benefits.Count(b => b.IsIncluded && b.IsActive)` | ✅ YES |
| displayPrice | computed string per PricingModel — see §④ business logic | ✅ YES — compute in projection OR in FE renderer. Prefer FE renderer for locale flexibility |
| memberCount | count of `MemberEnrolment` rows WHERE TierId = this & IsActive (NOT BUILT YET) | ❌ **SERVICE_PLACEHOLDER** — return `0` constant. TODO when MemberEnrolment #59 lands |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| PricingModelId | MasterData (TypeCode `MEMBERSHIPPRICINGMODEL`) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/MasterData.cs` | `getMasterDatas` (filter by `masterDataTypeCode=MEMBERSHIPPRICINGMODEL`) | DataName | MasterDataResponseDto |
| MinDonationHistoryId | MasterData (`MEMBERSHIPMINDONATION`) | same | `getMasterDatas` | DataName | MasterDataResponseDto |
| DowngradePolicyId | MasterData (`MEMBERSHIPDOWNGRADEPOLICY`) | same | `getMasterDatas` | DataName | MasterDataResponseDto |
| CurrencyId | Currency | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/Currency.cs` | `getCurrencies` (confirmed via `EndPoints/Shared/Queries/CurrencyQueries.cs`) | CurrencyCode | CurrencyResponseDto |
| UpgradeFromTierId | MembershipTier (self-FK) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/MemModels/MembershipTier.cs` (NEW this build) | `getMembershipTiers` (our own GetAll) with `isActive=true` filter; FE must exclude current `tierId` from options on Edit | TierName | MembershipTierResponseDto |
| CompanyId | Company | auto via HttpContext / tenant resolver | — | — | — |

**MasterData filter convention**: `getMasterDatas` accepts a filter arg for MasterDataType — same pattern used by Program #51 / SavedFilter #27 / ContactType #19. If the top-level `masterDataTypeCode` arg is not present, the `ApiSelectV2` widget passes it via the `advancedFilter` payload (`field=MasterDataType.TypeCode, operator=equals, value=...`). Confirm convention during build against the sibling that last shipped (likely Program #51).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `TierCode` must be unique per Company (`ValidateUniqueWhenCreate` + `ValidateUniqueWhenUpdate`). Soft-deleted (IsActive=false) rows must NOT block re-use — follow ContactType / Program pattern.
- `TierName` SHOULD be unique per Company (warn via soft-validation in FE; not a BE validation error).
- `SortOrder` SHOULD be unique per Company — BE does NOT enforce uniqueness (reorder UX can legitimately overlap mid-drag). If two tiers share the same SortOrder, display order falls back to `MembershipTierId` ASC.

**Required Field Rules:**
- Mandatory: `TierCode`, `TierName`, `SortOrder`, `PricingModelId`, `SetupFee`, `AutoRenewDefault`, `GracePeriodDays`, `DowngradePolicyId`.
- Child `MembershipTierBenefits`: `BenefitText` and `IsIncluded` mandatory; `SortOrder` auto-filled.

**Conditional Rules (BE + FE):**
- If `PricingModelCode` = `FIXED_ANNUAL` → `AnnualFee` REQUIRED ≥ 0; `MonthlyFee` optional (sidebar display only).
- If `PricingModelCode` = `FIXED_MONTHLY` → `MonthlyFee` REQUIRED ≥ 0; `AnnualFee` MAY be null.
- If `PricingModelCode` = `TIERED` → neither fee field is hard-required; persist whatever is entered (future: sliding-scale child table — out of MVP scope).
- If `PricingModelCode` = `PWYW` → `AnnualFee` and `MonthlyFee` MUST be null; FE shows hint "Member chooses amount at enrollment".
- If `PricingModelCode` = `FREE` → `AnnualFee`, `MonthlyFee`, and `SetupFee` MUST equal 0 or null; FE disables the inputs.
- `SetupFee` ≥ 0 always.
- `GracePeriodDays` ∈ {15, 30, 60, 90} — FE dropdown; BE validator whitelists these four values.
- `MaxMembers` — if provided, must be ≥ 1. UI "Unlimited" maps to null. UI "Custom" reveals a number input.
- `UpgradeFromTierId` cannot be self-referential (`UpgradeFromTierId != MembershipTierId`).
- `UpgradeFromTierId`, if set, must reference a tier with `SortOrder < this.SortOrder` (you upgrade FROM a lower tier). **Soft warning** in FE; **hard BE validation** rejects otherwise — confirm with user during approval.

**Business Logic:**
- **Cascade on delete**: Hard-delete MembershipTier → cascade-delete its `MembershipTierBenefits`. Soft-delete toggles IsActive only (children remain as historical audit rows, filtered out of GetById by `.Where(b => b.IsActive)`).
- **Restrict delete** if the tier has child `MemberEnrolment` rows (#59) once that screen is built. For MVP (MemberEnrolment not built): allow delete, but log a TODO placeholder. See **ISSUE-4**.
- **Benefits diff-persist**: Create/Update accepts inline `benefits[]` array. BE handler must diff against DB state within a single transaction: INSERT new rows (no `id`), UPDATE existing (match by `id`), DELETE rows removed from payload. Same pattern as Program #51 child collections and Family #20 `setFamilyMembers`.
- **Duplicate action** (kebab menu): FE-level operation — GET the source tier (+benefits) → pre-fill a new `createMembershipTier` payload with `TierCode = {sourceCode}_COPY`, `TierName = "{sourceName} (Copy)"`, `SortOrder = max+10`, all other fields copied including benefits (with new `id` stripped). Open drawer in "new" mode pre-filled; user tweaks + Save. No dedicated BE `DuplicateMembershipTier` mutation — keep surface minimal.
- **displayPrice rendering** (FE-side):
  - `FREE` → `"Free"`
  - `PWYW` → `"Pay what you want"`
  - `FIXED_ANNUAL` → `"{currencyCode} {annualFee} /year"` (formatted with locale + thousands separator)
  - `FIXED_MONTHLY` → `"{currencyCode} {monthlyFee} /month"`
  - `TIERED` → `"{currencyCode} {annualFee}+ /year"` (suffixed `+` to indicate sliding scale)
  - Lifetime tier with `FIXED_ANNUAL` and a big amount is still `/year` — there is NO "one-time" flag. Mockup shows "Lifetime — $5,000 one-time" visually; the BA interpretation for MVP is to rename Lifetime's PricingModel to `FIXED_ANNUAL` with a special `TierLabel="Elite"` — the "/one-time" phrasing is a copy liberty in the seed. See **ISSUE-9** for "add PricingModel=LIFETIME_ONETIME" follow-up.

**Workflow**: None. IsActive toggle is the only state mutation. Kebab menu "Deactivate" is an alias for toggle-off.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: `MASTER_GRID` (per Registry + DEPENDENCY-ORDER.md Wave 1.2)

**Type Classification**: **Master with inline custom form + 1 child collection + below-grid comparison widget** — a **non-canonical MASTER_GRID** (same class as Program #51, Family #20):

- List view is **card-grid** (5 horizontally-scrollable tier cards in mockup), not a table.
- Add/Edit form is a **520px right slide-panel** with 4 sections and a benefits child-grid — NOT an RJSF modal.
- `GridFormSchema = SKIP` because form is code-driven (RHF + zod), not RJSF-driven.
- Still registered as MASTER_GRID because the URL is a single route — no `?mode=new/edit/read` URL sync (drawer state is component-local).
- Below the card grid: a **Benefits Comparison Table** widget (a separate FE component that reads the GetAll response and pivots benefits into a matrix view).

**Reason for choosing MASTER_GRID over FLOW**: the entity has no multi-step workflow, no separate detail view/page, no status machine. Drawer-based edit with URL-stable route matches MASTER_GRID semantics even though form is code-driven.

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) — always
- [x] Nested child creation — `MembershipTierBenefit` diff-persist in Create + Update
- [x] Multi-FK validation (ValidateForeignKeyRecord ×4: PricingModelId, DowngradePolicyId, MinDonationHistoryId?, CurrencyId?)
- [x] Unique validation — TierCode per Company
- [ ] File upload command — N/A
- [x] Custom business rule validators — PricingModel ↔ fee conditional rules; self-FK sort-order guard; GracePeriodDays whitelist
- [x] **NEW MODULE bootstrap** — first entity in `mem` schema

**Frontend Patterns Required:**
- [x] `<CardGrid>` with **NEW `membership-tier` variant** — card shows emoji (2rem), name (bold), label (uppercase small), price (prominent accent color), member count, Edit button + kebab menu
- [ ] AdvancedDataTable — N/A (replaced by CardGrid)
- [ ] RJSF Modal Form — N/A (replaced by code-driven slide-panel with RHF + zod)
- [x] Code-driven slide-panel (520px right; backdrop + ESC + body-lock; same architecture as Program #51 drawer but narrower width)
- [x] Benefits child-grid widget (inline checkbox + text + edit/delete per row + "Add Custom Benefit" dashed button)
- [x] Below-grid Benefits Comparison Table widget — pivots `tiers[].benefits[]` into matrix (rows=distinct benefit texts, cols=tiers)
- [x] ApiSelectV2 for PricingModel / DowngradePolicy / MinDonationHistory / Currency / UpgradeFromTier (self-FK, exclude current)
- [x] Kebab menu per card: Edit / View Members (nav placeholder) / Duplicate (FE-only) / Deactivate (toggle) / Delete (confirm → soft delete)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.

### Grid/List View

**Display Mode**: `card-grid` (REQUIRED — matches mockup's horizontally scrollable tier cards)

**Card Variant**: `membership-tier` (**NEW — build this variant**)

| Variant decision | Why |
|------------------|-----|
| `membership-tier` | Mockup tier cards are visually distinct pricing tiles with top-border color, emoji, name, label, price, member count, dual actions. None of the existing `details`/`profile`/`iframe`/`family`/`program` variants fit (details=text snippet, profile=avatar+name, iframe=HTML preview, family=member-chip roster, program=capacity+budget). Add a new variant file + one registry entry. |

**Card Config** (for `membership-tier` variant):

```yaml
cardConfig:
  iconField: "iconEmoji"                  # emoji, default 🏅
  topBorderField: "colorHex"               # maps to inline style: border-top: 4px solid <hex>
  nameField: "tierName"                    # e.g., "Gold" (bold, 1rem)
  labelField: "tierLabel"                  # e.g., "Premium" (uppercase, letter-spaced, muted)
  priceField: "displayPrice"               # computed FE-side string — see §④ displayPrice logic
  memberCountField: "memberCount"          # integer; "{n} members" label
  primaryAction: { label: "Edit", icon: "ph:pencil", handler: "openEditPanel" }
  kebabActions:
    - { label: "Edit", icon: "ph:pencil", handler: "openEditPanel" }
    - { label: "View Members", icon: "ph:users", handler: "navViewMembers" }    # SERVICE_PLACEHOLDER — links to /crm/membership/memberlist?tierId=X; #59 NOT built
    - { label: "Duplicate", icon: "ph:copy", handler: "duplicateTier" }
    - { label: "Deactivate", icon: "ph:pause", handler: "toggleTier" }          # toggles IsActive
    - { divider: true }
    - { label: "Delete", icon: "ph:trash", handler: "deleteTier", tone: "danger" }
```

**Card styling notes (matched to mockup .tier-card):**
- Card width: `min-w-[200px]` (horizontal scroll when overflow)
- Card padding: `p-4`
- Border: default `border-2 border-slate-200`, top-only via inline `border-top: 4px solid {colorHex}`
- Hover: `shadow-md translate-y-[-2px]` transition
- Inactive tiers: render with `opacity-60` + badge "Inactive" in top-right corner
- Icon (emoji): `text-3xl mb-2`, centered
- Name: `text-base font-bold`, centered
- Label: `text-[0.6875rem] uppercase tracking-wide text-slate-500 mb-3`
- Price: `text-xl font-bold text-accent mb-1` (accent = `--primary`/`text-cyan-700` via design tokens)
- Members line: `text-xs text-slate-500 mb-3` with bold `{n}` prefix
- Actions: flex-center, gap-1.5, Edit (outlined-accent small) + kebab trigger (outlined-muted small with dots icon)

**Responsive breakpoints** (custom for this card, NOT the default CardGrid grid):
- xs-sm: horizontal scroll, each card min-w-[200px], gap-3, overflow-x-auto
- lg-xl: same horizontal scroll (design keeps tiers side-by-side for comparability even on wide screens)
- NOT using the default 1-col→2→3→4 grid — stamp `layoutOverride: "hscroll"` in cardConfig for FE dev to branch.

**Build dependency**: `card-grid` shell + `card-variant-registry` exist (first built by SMS Template #29 / reused by Program #51, Family #20, Email Template #24). This screen adds ONE new variant file (`membership-tier-card.tsx`) + ONE registry line + ONE skeleton file. Shell untouched. Also extends `CardVariant` type union with `'membership-tier'` if typed.

**Search/Filter**: Search by `tierName`, `tierCode`, `description`. **Filter chips**: None in mockup (only 5 cards total — filters unnecessary).

**Grid Actions** (per card): Edit, kebab menu (see `kebabActions` above).

**Toolbar (ScreenHeader right-side)**:
- Primary: **"+ New Tier"** button (accent filled) — opens slide-panel in new mode.

### Slide-Panel Edit Form

> This is **NOT** an RJSF modal. It is a hand-built React component with RHF + zod.
> Width: `520px` (mockup) — NOT 80% like Program #51. Fixed-width desktop, full-width on mobile.
> Header: mem-accent background tint (`#fffbeb`), title "Edit Tier — {tierName}" or "New Tier", close-X top-right.
> Body: scrollable; 4 sections stacked.
> Footer: sticky with Cancel (ghost, left) + Save Tier (accent filled with check icon, right).

**Slide-Panel Behavior:**
- Trigger: "+ New Tier" button → panel opens empty (mode=new).
- Trigger: Card "Edit" button or kebab "Edit" → panel opens pre-filled via `getMembershipTierById(id)` (mode=edit).
- Trigger: kebab "Duplicate" → panel opens in new mode pre-filled with cloned source (see §④ Duplicate logic).
- Backdrop overlay dims page (bg-black/30, z=1040).
- Close: backdrop click / ESC key / Cancel button / successful Save.
- "Save Tier" submits → Create/Update mutation → on success: close panel + refresh card grid + toast "Tier saved".
- URL does NOT change (no `?mode=...` query sync). Panel state is `useState`/Zustand local.
- Body locks scroll while panel is open (`document.body.style.overflow = 'hidden'` on open; restore on close).

**Form Sections** (in slide-panel body, top-to-bottom; mockup fidelity — match order + icons exactly):

| # | Section Title | Icon (Phosphor) | Layout | Fields |
|---|---------------|-----------------|--------|--------|
| 1 | Tier Details | `ph:identification-card` | 1-col + 2-col row | `tierName` (col-12, required), `displayName` (col-12, placeholder "Shown to members"), `description` (col-12, textarea rows=2), `iconEmoji` (col-6, text with emoji-preview, default 🏅) + `sortOrder` (col-6, number), `colorHex` (col-12 color-row: `<input type="color">` + hex text input side-by-side) |
| 2 | Pricing | `ph:money` | 1-col + 2-col rows | `pricingModelId` (col-12, required, ApiSelectV2), `annualFee` (col-6, currency-input) + `monthlyFee` (col-6, currency-input, placeholder "If monthly option"), `setupFee` (col-6) + `currencyId` (col-6, ApiSelectV2), `autoRenewDefault` (col-12, toggle-switch + label "Auto-Renew Default"), `gracePeriodDays` (col-12, select 15/30/60/90 days) |
| 3 | Benefits | `ph:check-square` | benefit-list (inline child-grid) | Child-grid rows (see widget spec below) + "Add Custom Benefit" dashed button |
| 4 | Eligibility & Rules | `ph:shield-check` | 1-col repeat | `minDonationHistoryId` (col-12, ApiSelectV2 MasterData), `upgradeFromTierId` (col-12, ApiSelectV2 self-FK — excludes current tier on edit; shows "None" option), `downgradePolicyId` (col-12, ApiSelectV2 MasterData, required, default ALLOW), `maxMembersMode` (col-12, select: Unlimited/50/100/Custom) + `maxMembers` (col-12, number — conditional visible only when `maxMembersMode=Custom`) |

**Field Widget Mapping**:

| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| tierName | `<input text>` | "Enter tier name" | required, 1..100 | — |
| tierCode | Hidden on form (derived from TierName uppercased on create via zod `.transform`); READ-ONLY on edit with small "Tier Code" label above TierName input | — | required, 1..50, `^[A-Z][A-Z0-9_]{1,49}$` | Auto-derive on Create from TierName (e.g., "Gold" → "GOLD"). If collision, append `_2`, `_3`, etc. |
| displayName | `<input text>` | "Shown to members" | optional, 1..150 | Falls back to tierName in UI if empty |
| tierLabel | `<input text>` | "Basic / Premium / VIP…" | optional, 1..50 | Free text |
| description | `<textarea rows=2>` | "Describe the tier benefits and positioning" | optional, max 1000 | — |
| iconEmoji | `<input text>` with emoji preview | "🏅" | optional, 1..10 | Default 🏅 if blank |
| sortOrder | `<input type="number">` | — | required, ≥ 0 | Default on create: `(max existing SortOrder + 10)` |
| colorHex | `<input type="color">` + `<input type="text">` bound to same hex | "#FFD700" | optional (default `#d97706`), `^#[0-9A-Fa-f]{6}$` | Drives card top-border |
| pricingModelId | `<ApiSelectV2 query=getMasterDatas typeCode=MEMBERSHIPPRICINGMODEL>` | "Select pricing model" | required | Drives conditional visibility of fee inputs |
| annualFee | `<NumberInput>` (decimal 2) with currency prefix | "0.00" | ≥ 0, nullable; required when pricingModelCode=`FIXED_ANNUAL` | Disabled+zeroed when `FREE` |
| monthlyFee | `<NumberInput>` (decimal 2) | "0.00" | ≥ 0, nullable; required when pricingModelCode=`FIXED_MONTHLY` | Disabled+zeroed when `FREE`/`PWYW` |
| setupFee | `<NumberInput>` (decimal 2) | "0.00" | ≥ 0 | Disabled+zeroed when `FREE` |
| currencyId | `<ApiSelectV2 query=getCurrencies>` | "Select currency" | optional | Defaults to Company default currency |
| autoRenewDefault | toggle-switch | — | bool, default true | — |
| gracePeriodDays | `<select>` with 4 options | — | required, ∈ {15,30,60,90} | Default 30 |
| minDonationHistoryId | `<ApiSelectV2 query=getMasterDatas typeCode=MEMBERSHIPMINDONATION>` | "No minimum" | optional | Null = no minimum |
| upgradeFromTierId | `<ApiSelectV2 query=getMembershipTiers>` with client-side filter excluding current `tierId` on edit | "None" | optional | First option "None" maps to null |
| downgradePolicyId | `<ApiSelectV2 query=getMasterDatas typeCode=MEMBERSHIPDOWNGRADEPOLICY>` | "Select policy" | required | Default ALLOW |
| maxMembersMode | client-side `<select>` (not a DB field) | — | — | Options: `UNLIMITED` (maps `maxMembers`→null) / `50` / `100` / `CUSTOM` (reveals number input) |
| maxMembers | `<NumberInput>` integer | — | nullable, ≥ 1 | Visible only when `maxMembersMode=CUSTOM`. When mode=50/100, auto-set value. |

**Benefits Child-Grid widget spec** (Section 3):

- Rows render one per benefit in `benefits[]` array (RHF `useFieldArray`).
- Row layout: `[checkbox IsIncluded] [benefit-text (inline-editable)] [edit-icon] [delete-icon]`.
  - Checkbox binds to `benefits[i].isIncluded`.
  - Benefit text is either a read-only label with edit-icon entering edit mode (inline input), OR always editable inline text input — prefer **always-editable inline input** for simpler UX; the "edit icon" from mockup becomes a no-op / removed.
  - Delete icon removes the row from the array (persists as DELETE on Save via diff-persist).
- **"Add Custom Benefit"** — dashed-border button at bottom of list. Clicking appends `{ id: null, benefitText: "", isIncluded: true, sortOrder: rows.length }`. Focus jumps to the new input.
- Visual: checkboxes use mem-accent; rows have `border-bottom: 1px solid #f1f5f9`; last row no border.
- Drag-to-reorder: NOT in mockup; skip for MVP (ISSUE-6).
- Seed display tip: the 5 seeded tiers have 5–9 benefits each, with check-yes pattern matching the Benefits Comparison Table.

### Page Widgets & Summary Cards

**Widgets**: **NONE** above the card grid (mockup has no KPI widgets).

**Layout Variant**: `widgets-above-grid` — **Variant B mandatory**.

> Reason: `<CardGrid>` has no internal page header. FE Dev uses `<ScreenHeader>` at the top with title "Membership Tiers", subtitle "Configure membership levels, pricing, and benefits", right action "+ New Tier". Below it: the `<CardGrid>` (tier cards). Below that: the Benefits Comparison Table widget. There is no data-widget row of KPIs between header and grid, but the layout is NOT `grid-only` because we have a ScreenHeader + below-grid section — mirrors Program #51's pattern.

### Below-Grid Widget — Benefits Comparison Table

> This IS part of the screen (mockup shows it prominently below the tier cards). BUILD it as a separate FE component.

- Component: `<MembershipTierBenefitsComparison tiers={tiers} />`
- Data: reads the `getMembershipTiers` GetAll response (which includes `benefits[]` nested per tier).
- Derivation:
  - Distinct benefit rows: union of all `benefit.benefitText` values across all tiers (case-insensitive dedup).
  - Columns: each active tier (emoji + name header cell).
  - Cells: `check-yes` icon (green) if tier has a benefit with matching text AND `isIncluded=true`; otherwise `check-no` (muted minus-circle).
- Card wrapper: `<Card>` with header `<CardTitle icon="ph:table" color="mem-accent">Benefits Comparison</CardTitle>`, overflow-x-auto.
- Table: `<table>` inside scrollable div — plain HTML table (NOT AdvancedDataTable).
- Column header style: `bg-slate-50 text-xs uppercase text-muted p-2.5`; first column left-aligned (benefit name); other columns center-aligned (emoji + tier name two lines).
- Row hover: `bg-slate-50`.
- If no tiers active → render empty-state card "No active tiers yet. Create a tier to see benefits comparison."

### Side Panels / Info Displays

**Side Panel**: The slide-panel IS the edit form. No separate viewer panel.

### User Interaction Flow

1. User lands on `/{lang}/crm/membership/membershiptier` → `<ScreenHeader>` renders with title + "+ New Tier" action.
2. `<CardGrid variant="membership-tier" layoutOverride="hscroll">` below renders all active tiers as horizontally-scrollable cards.
3. Below CardGrid: `<MembershipTierBenefitsComparison>` renders matrix.
4. User clicks **"+ New Tier"** → slide-panel (520px, right) slides in; title "New Tier"; form empty with sensible defaults (SortOrder=nextMax, GracePeriodDays=30, AutoRenewDefault=true, DowngradePolicyId=ALLOW, ColorHex=`#d97706`).
5. User fills Sections 1–4, adds benefit rows → clicks **Save Tier** → `createMembershipTier` mutation fires → on success: toast "Tier created", panel closes, card grid refreshes, comparison table re-renders.
6. User clicks a card's **Edit** button (or kebab → Edit) → slide-panel opens pre-filled via `getMembershipTierById(id)`; title "Edit Tier — {tierName}"; form hydrated with all benefits.
7. User edits → **Save Tier** → `updateMembershipTier` mutation fires → same close/refresh.
8. User clicks kebab **Duplicate** → FE clones current tier payload (see §④ Duplicate logic) → panel opens in new mode pre-filled → user tweaks + Save.
9. User clicks kebab **Deactivate** → confirm toast → `toggleMembershipTier` mutation → card renders with opacity-60 + "Inactive" badge.
10. User clicks kebab **Delete** → confirm dialog "Delete tier {name}? Benefits will be removed. Existing members are NOT affected (MemberEnrolment #59 not yet built)." → `deleteMembershipTier` → card removed from grid.
11. User clicks kebab **View Members** → `router.push('/{lang}/crm/membership/memberlist?tierId={id}')` — target page is #59 MemberEnrolment list; until that's built, the route renders the stub. **Flag as SERVICE_PLACEHOLDER in §⑫**.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps canonical references to MembershipTier.

**Canonical References**:
- **Program (#51)** — New schema bootstrap (CaseModels→MemModels), card-grid + code-driven side-drawer form, diff-persist child collections, SERVICE_PLACEHOLDER aggregates. Closest architectural sibling.
- **ContactType (#19)** — Basic MASTER_GRID CRUD 11-file skeleton; entity/schemas/commands/queries structure.
- **Family (#20)** — Card-grid + new variant pattern (`family-card`). Reference for adding `membership-tier` variant.
- **Email Template (#24)** — Card-grid iframe variant; shell-untouched variant-add.

| Canonical (Program) | → MembershipTier | Context |
|---------------------|------------------|---------|
| Program | MembershipTier | Entity/class name |
| program | membershipTier | Variable/field names (JS camel) |
| ProgramId | MembershipTierId | PK |
| Programs | MembershipTiers | Table name (DbSet plural) |
| program (kebab) | membership-tier | FE kebab folder / variant name |
| programmanagement (flat) | membershiptier | FE route path segment (per MODULE_MENU_REFERENCE.md) |
| PROGRAMMANAGEMENT | MEMBERSHIPTIER | MenuCode / GridCode / DecoratorMemModules entry |
| case | mem | DB schema (NEW) |
| Case | Mem | Backend group name (NEW) |
| CaseModels | MemModels | Namespace suffix (NEW) |
| CaseConfigurations | MemConfigurations | EF configurations folder (NEW) |
| CaseSchemas | MemSchemas | DTO namespace (NEW) |
| CaseBusiness | MemBusiness | Commands/Queries root namespace (NEW) |
| CRM_CASEMANAGEMENT | CRM_MEMBERSHIP | ParentMenuCode |
| CRM | CRM | Module code (same) |
| crm/casemanagement/programmanagement | crm/membership/membershiptier | FE route path |
| case-service | **mem-service** (NEW FE service folder) | FE domain entity folder |
| case-queries / case-mutations | **mem-queries / mem-mutations** (NEW GQL folders) | FE GQL folders |

**Reference patterns** by need:

| Need | Look at |
|------|---------|
| NEW module bootstrap (schema + DbContext + Mappings + Decorator + GlobalUsing ×3) | **Program #51** — mirror the 5 wiring steps exactly; swap `Case`→`Mem` |
| 11-file CRUD skeleton | **ContactType #19** + **Program #51** |
| Child 1:M diff-persist (Benefits) in Create/Update handler | **Program #51** Eligibility/Services/OutcomeMetrics inline diff-persist, or **Family #20** `setFamilyMembers`, or **NotificationTemplate #36** template children |
| Card-grid + NEW variant (`membership-tier`) | **Family #20** `family-card` variant; **Email Template #24** `iframe` variant (shell untouched, one file + one registry line) |
| Code-driven side-drawer form (narrower 520px not 80%) | **Program #51** program-drawer — copy skeleton, change width |
| SERVICE_PLACEHOLDER aggregate field returning `0` | **Program #51** `enrolledCount` / `spentBudget` |
| Self-FK with "exclude current" FE filter | **Campaign #39** parent-campaign, or **OrganizationalUnit #44** parent-unit |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Exact files to create, with computed paths. No guessing.

### Backend — New Module Bootstrap (4 created + 6 wiring modifications)

| # | File | Path | Purpose |
|---|------|------|---------|
| B1 | IMemDbContext.cs | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Data/Persistence/IMemDbContext.cs` | DbSet signatures for both mem entities |
| B2 | MemDbContext.cs | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Persistence/MemDbContext.cs` | EF DbContext implementing IMemDbContext |
| B3 | MemMappings.cs | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Mappings/MemMappings.cs` | `public static void ConfigureMappings() { ... }` — Mapster maps |
| B4 | DecoratorMemModules (add to DecoratorProperties.cs) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Extensions/DecoratorProperties.cs` | Add `public static class DecoratorMemModules { public const string MembershipTier = "MEMBERSHIPTIER", MembershipTierBenefit = "MEMBERSHIPTIERBENEFIT"; }` |

**Backend Wiring Updates for new module:**

| # | File | Change |
|---|------|--------|
| W1 | IApplicationDbContext.cs | Add `IMemDbContext` to inheritance list |
| W2 | DependencyInjection.cs (Base.Infrastructure) | Register `MemDbContext` in `AddDbContext` / register interface mapping |
| W3 | DependencyInjection.cs (Base.Application) | Call `MemMappings.ConfigureMappings()` |
| W4 | GlobalUsing.cs (Base.Application) | Add `global using Base.Domain.Models.MemModels;` + `global using Base.Application.Schemas.MemSchemas;` + (as needed) `global using Base.Application.Business.MemBusiness.MembershipTiers.*` |
| W5 | GlobalUsing.cs (Base.Infrastructure) | Add `global using Base.Domain.Models.MemModels;` |
| W6 | GlobalUsing.cs (Base.API) | Add `global using Base.Application.Schemas.MemSchemas;` + `global using Base.Application.Business.MemBusiness.MembershipTiers.Queries;` etc. |

### Backend — Entities + EF Configs (2 entities + 2 configs = 4 files)

| # | File | Path |
|---|------|------|
| E1 | MembershipTier.cs | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/MemModels/MembershipTier.cs` |
| E2 | MembershipTierBenefit.cs | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/MemModels/MembershipTierBenefit.cs` |
| C1 | MembershipTierConfiguration.cs | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/MemConfigurations/MembershipTierConfiguration.cs` |
| C2 | MembershipTierBenefitConfiguration.cs | same folder |

### Backend — Schemas / DTOs (1 file)

| # | File | Path |
|---|------|------|
| S1 | MembershipTierSchemas.cs | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/MemSchemas/MembershipTierSchemas.cs` |

Contains:
- `MembershipTierRequestDto` (Create/Update — includes inline `benefits[]` array with child DTO)
- `MembershipTierResponseDto` (GetAll flat card columns + nested `benefits[]` for GetById; also inlined for GetAll since list has only ~5–20 rows — no pagination concerns)
- `MembershipTierListItemDto` (OPTIONAL lightweight — skip for MVP, use ResponseDto directly)
- `MembershipTierBenefitDto` (child: benefitId, membershipTierId, benefitText, isIncluded, sortOrder, isActive)
- `MembershipTierSummaryDto` — *defer: no top-of-page KPI widgets for MVP* (add later if needed)

### Backend — Business (Commands + Queries = 6 files)

| # | File | Path |
|---|------|------|
| CQ1 | CreateMembershipTier.cs | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/MemBusiness/MembershipTiers/CreateCommand/CreateMembershipTier.cs` |
| CQ2 | UpdateMembershipTier.cs | `.../MemBusiness/MembershipTiers/UpdateCommand/UpdateMembershipTier.cs` |
| CQ3 | DeleteMembershipTier.cs | `.../MemBusiness/MembershipTiers/DeleteCommand/DeleteMembershipTier.cs` |
| CQ4 | ToggleMembershipTier.cs | `.../MemBusiness/MembershipTiers/ToggleCommand/ToggleMembershipTier.cs` |
| CQ5 | GetAllMembershipTiers.cs | `.../MemBusiness/MembershipTiers/GetAllQuery/GetAllMembershipTiers.cs` |
| CQ6 | GetMembershipTierById.cs | `.../MemBusiness/MembershipTiers/GetByIdQuery/GetMembershipTierById.cs` |

### Backend — Endpoints (2 files)

| # | File | Path |
|---|------|------|
| EP1 | MembershipTierMutations.cs | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Mem/Mutations/MembershipTierMutations.cs` |
| EP2 | MembershipTierQueries.cs | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Mem/Queries/MembershipTierQueries.cs` |

**Backend total**: 4 (bootstrap) + 6 (wiring mods) + 4 (entities/configs) + 1 (schemas) + 6 (business) + 2 (endpoints) = **17 created + 6 modified** + **1 EF migration** (`AddMemModule_MembershipTiers_Initial`).

### Frontend — DTO + GQL (3 created)

| # | File | Path |
|---|------|------|
| F1 | MembershipTierDto.ts | `PSS_2.0_Frontend/src/domain/entities/mem-service/MembershipTierDto.ts` *(NEW service folder `mem-service`)* |
| F2 | MembershipTierQuery.ts | `PSS_2.0_Frontend/src/infrastructure/gql-queries/mem-queries/MembershipTierQuery.ts` *(NEW folder)* |
| F3 | MembershipTierMutation.ts | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/mem-mutations/MembershipTierMutation.ts` *(NEW folder)* |

### Frontend — Page + Components (10 created + 1 overwritten)

| # | File | Path |
|---|------|------|
| F4 | Page config (exports `<MembershipTierPage>`) | `PSS_2.0_Frontend/src/presentation/pages/crm/membership/membership-tier.tsx` *(extends/updates `pages/crm/membership/index.ts` barrel)* |
| F5 | Index page component (Variant B: ScreenHeader + CardGrid + BenefitsComparison) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membership-tier/index-page.tsx` |
| F6 | `membership-tier-card.tsx` variant | `PSS_2.0_Frontend/src/presentation/components/page-components/card-grid/variants/membership-tier-card.tsx` |
| F7 | `membership-tier-card-skeleton.tsx` | `PSS_2.0_Frontend/src/presentation/components/page-components/card-grid/skeletons/membership-tier-card-skeleton.tsx` |
| F8 | Slide-panel container (520px right, backdrop, ESC, body-lock) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membership-tier/membership-tier-drawer.tsx` |
| F9 | Membership tier form (4 sections, RHF + zod) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membership-tier/membership-tier-form.tsx` |
| F10 | Form schemas (zod) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membership-tier/membership-tier-form-schemas.ts` |
| F11 | Benefits child-grid | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membership-tier/membership-tier-benefits-field.tsx` |
| F12 | Benefits Comparison Table widget | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membership-tier/membership-tier-benefits-comparison.tsx` |
| F13 | Zustand store (drawer state + optimistic refresh hook) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membership-tier/membership-tier-store.ts` |
| F14 | Route page (OVERWRITE existing stub) | `PSS_2.0_Frontend/src/app/[lang]/crm/membership/membershiptier/page.tsx` *(replaces the 4-line "Need to Develop" stub)* |

### Frontend — Wiring Updates (5–7 files modified)

| # | File | What to Add |
|---|------|-------------|
| FW1 | `src/application/configs/data-table-configs/mem-service-entity-operations.ts` **(CREATE — first mem-service file)** | `MemServiceEntityOperations` array with `MEMBERSHIPTIER` entry; mirror `case-service-entity-operations.ts` pattern |
| FW2 | `src/application/configs/data-table-configs/index.ts` | Import + spread `MemServiceEntityOperations` into `DataTableOperationConfigs` |
| FW3 | `src/presentation/components/page-components/card-grid/card-variant-registry.ts` | Register `'membership-tier'` → `MembershipTierCard` variant mapping (+ skeleton entry) |
| FW4 | `src/presentation/components/page-components/card-grid/types.ts` | Add `'membership-tier'` to `CardVariant` union |
| FW5 | `src/presentation/pages/crm/membership/index.ts` | Export `MembershipTierPage` |
| FW6 | `src/presentation/pages/crm/index.ts` (if it re-exports membership) | Verify / pass-through — may be no-op |
| FW7 | Sidebar menu | Menu `MEMBERSHIPTIER` loaded from DB seed — no FE code change needed if dynamic. Verify rendering. |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens so user just reviews and confirms.

```
---CONFIG-START---
Scope: FULL

MenuName: Tiers & Plans
MenuCode: MEMBERSHIPTIER
ParentMenu: CRM_MEMBERSHIP
Module: CRM
MenuUrl: crm/membership/membershiptier
GridType: MASTER_GRID
OrderBy: 3

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, EXPORT

GridFormSchema: SKIP    # form is code-driven (RHF + zod), not RJSF
GridCode: MEMBERSHIPTIER

GridColumns (card-grid — 7 projected fields, no RJSF fieldSchema):
  - iconEmoji           | Icon             | EmojiPreview     | 50px
  - tierName            | Tier Name        | text-bold        | auto
  - tierLabel           | Label            | text-muted       | 100px
  - displayPrice        | Price            | text-accent-bold | 130px
  - memberCount         | Members          | number           | 80px   (SERVICE_PLACEHOLDER 0)
  - includedBenefitCount| Benefits         | number           | 80px
  - isActive            | Active           | status-badge     | 90px

MasterDataTypes (seed — 3 types):
  - MEMBERSHIPPRICINGMODEL (5 rows):
      FIXED_ANNUAL   → "Fixed Annual"
      FIXED_MONTHLY  → "Fixed Monthly"
      TIERED         → "Tiered/Sliding Scale"
      PWYW           → "Pay What You Want"
      FREE           → "Free"
  - MEMBERSHIPMINDONATION (4 rows):
      NONE    → "No minimum"   (dataValue="0")
      D_100   → "$100+"        (dataValue="100")
      D_500   → "$500+"        (dataValue="500")
      D_1000  → "$1,000+"      (dataValue="1000")
  - MEMBERSHIPDOWNGRADEPOLICY (3 rows):
      ALLOW    → "Allow"
      PREVENT  → "Prevent"
      PRORATA  → "Allow with pro-rata refund"

SampleRows (seed 5 tiers end-to-end for visual verification — match mockup):
  1. Bronze   (TierCode=BRONZE,   TierLabel=Basic,    IconEmoji=🥉, ColorHex=#cd7f32, SortOrder=10, PricingModel=FIXED_ANNUAL, AnnualFee=50,   SetupFee=0, CurrencyCode=USD, AutoRenew=true, GracePeriod=30, DowngradePolicy=ALLOW, 5 benefits: Newsletter=1)
  2. Silver   (TierCode=SILVER,   TierLabel=Standard, IconEmoji=🥈, ColorHex=#c0c0c0, SortOrder=20, PricingModel=FIXED_ANNUAL, AnnualFee=150,  SetupFee=0, CurrencyCode=USD, AutoRenew=true, GracePeriod=30, DowngradePolicy=ALLOW, 7 benefits: Newsletter+ImpactReport+MemberEvents=1)
  3. Gold     (TierCode=GOLD,     TierLabel=Premium,  IconEmoji=🥇, ColorHex=#ffd700, SortOrder=30, PricingModel=FIXED_ANNUAL, AnnualFee=500,  SetupFee=0, CurrencyCode=USD, AutoRenew=true, GracePeriod=30, DowngradePolicy=ALLOW, UpgradeFromTier=SILVER, 8 benefits)
  4. Platinum (TierCode=PLATINUM, TierLabel=VIP,      IconEmoji=💎, ColorHex=#e5e4e2, SortOrder=40, PricingModel=FIXED_ANNUAL, AnnualFee=1000, SetupFee=0, CurrencyCode=USD, AutoRenew=true, GracePeriod=30, DowngradePolicy=ALLOW, UpgradeFromTier=GOLD, 9 benefits)
  5. Lifetime (TierCode=LIFETIME, TierLabel=Elite,    IconEmoji=⭐, ColorHex=#f59e0b, SortOrder=50, PricingModel=FIXED_ANNUAL, AnnualFee=5000, SetupFee=0, CurrencyCode=USD, AutoRenew=false, GracePeriod=90, DowngradePolicy=PREVENT, 10 benefits — all boxes ticked matching the Comparison Table)

Menu seed: MEMBERSHIPTIER at OrderBy=3 under CRM_MEMBERSHIP (per MODULE_MENU_REFERENCE.md — after MEMBERLIST=1, MEMBERENROLLMENT=2, MEMBERSHIPTIER=3, MEMBERSHIPRENEWAL=4).

Seed file location: `sql-scripts-dyanmic/` (preserve repo typo — ChequeDonation #6 / Program #51 precedent).
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — knows EXACTLY what the backend will expose before BE is even built.

**GraphQL Types:**
- Query type: `MembershipTierQueries`
- Mutation type: `MembershipTierMutations`

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getMembershipTiers` | `PaginatedApiResponse<[MembershipTierResponseDto]>` | `GridFeatureRequest` (searchText, pageNo, pageSize, sortField, sortDir, isActive). **Inline `benefits[]` on each row** — list is ≤ ~50 rows, so inlining is cheap and enables BenefitsComparison widget without extra round-trip |
| `getMembershipTierById` | `BaseApiResponse<MembershipTierResponseDto>` | `membershipTierId` |

> **Note**: no `getMembershipTierSummary` for MVP — mockup has no KPI widgets.

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createMembershipTier` | `MembershipTierRequestDto` (includes `benefits[]`) | `int` (new `MembershipTierId`) |
| `updateMembershipTier` | `MembershipTierRequestDto` (includes `membershipTierId` + `benefits[]` for diff-persist) | `int` |
| `deleteMembershipTier` | `membershipTierId: Int!` | `int` |
| `toggleMembershipTier` | `membershipTierId: Int!` | `int` |

**Response DTO Fields — `MembershipTierResponseDto`** (what FE receives):

| Field | Type | Notes |
|-------|------|-------|
| membershipTierId | number | PK |
| tierCode | string | — |
| tierName | string | — |
| displayName | string? | — |
| tierLabel | string? | — |
| description | string? | — |
| iconEmoji | string? | Default server-side fallback 🏅 |
| colorHex | string? | Default `#d97706` |
| sortOrder | number | — |
| pricingModelId | number | FK |
| pricingModelName | string | FK display |
| pricingModelCode | string | FK code — FE uses for displayPrice branching |
| annualFee | number? | decimal |
| monthlyFee | number? | decimal |
| setupFee | number | decimal ≥ 0 |
| currencyId | number? | FK |
| currencyCode | string? | e.g., "USD" |
| autoRenewDefault | boolean | — |
| gracePeriodDays | number | 15/30/60/90 |
| minDonationHistoryId | number? | FK |
| minDonationHistoryName | string? | FK display |
| minDonationHistoryCode | string? | FK code |
| upgradeFromTierId | number? | self-FK |
| upgradeFromTierName | string? | self-FK display |
| downgradePolicyId | number | FK |
| downgradePolicyName | string | FK display |
| downgradePolicyCode | string | FK code |
| maxMembers | number? | null = unlimited |
| isActive | boolean | Inherited from Entity |
| memberCount | number | **SERVICE_PLACEHOLDER** — always `0` for MVP (until #59 built) |
| includedBenefitCount | number | `benefits.Count(b => b.isIncluded && b.isActive)` — BUILDABLE |
| benefits | `MembershipTierBenefitDto[]` | Inlined on both GetAll and GetById |

**Child DTO — `MembershipTierBenefitDto`:**

| Field | Type | Notes |
|-------|------|-------|
| membershipTierBenefitId | number | PK (null in create payload — signals INSERT on server) |
| membershipTierId | number | FK parent |
| benefitText | string | required, ≤ 500 |
| isIncluded | boolean | — |
| sortOrder | number | — |
| isActive | boolean | Inherited |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (new `mem` schema registered; EF design snapshot clean; migration `AddMemModule_MembershipTiers_Initial` created)
- [ ] `pnpm dev` — page loads at `/{lang}/crm/membership/membershiptier`
- [ ] `pnpm tsc --noEmit` — no errors in new MembershipTier files (pre-existing unrelated errors allowed)

**Functional Verification (Full E2E — MANDATORY):**
- [ ] CardGrid renders 5 seeded tiers in horizontal-scroll layout
- [ ] Each card shows: emoji (2rem), name (bold), label (uppercase muted), displayPrice (accent bold), member count ("0 members" with tooltip), Edit button + kebab trigger
- [ ] Top border color per card matches seeded `colorHex` (Bronze #cd7f32 / Silver #c0c0c0 / Gold #ffd700 / Platinum #e5e4e2 / Lifetime #f59e0b)
- [ ] Search filters by `tierName`, `tierCode`, `description`
- [ ] Click **"+ New Tier"** → slide-panel opens (520px, right) with empty form + backdrop dim
- [ ] ESC closes panel; backdrop click closes; Cancel button closes; all three restore body scroll
- [ ] Click card **Edit** → panel opens pre-filled via `getMembershipTierById`; header title "Edit Tier — {tierName}"
- [ ] Section 1 (Tier Details) — all 6 fields render; color picker + hex text input sync bidirectionally; emoji preview visible
- [ ] Section 2 (Pricing) — PricingModel dropdown renders 5 MasterData options; selecting FREE disables+zeroes fee inputs; selecting PWYW hides Annual/Monthly (or disables); selecting FIXED_MONTHLY makes MonthlyFee required + AnnualFee optional; Currency ApiSelectV2 loads; AutoRenewDefault toggle persists; GracePeriodDays select restricted to 15/30/60/90
- [ ] Section 3 (Benefits) — child-grid loads all existing benefits on edit; each row has checkbox (IsIncluded) + inline-editable text + delete icon; "Add Custom Benefit" dashed button appends row with focus; deleting a row removes it from UI (persists as DELETE on Save)
- [ ] Section 4 (Eligibility & Rules) — MinDonationHistory ApiSelectV2 loads (NONE/100+/500+/1000+); UpgradeFromTier ApiSelectV2 loads siblings, excludes current tier on edit, has "None" option; DowngradePolicy ApiSelectV2 loads (ALLOW/PREVENT/PRORATA); MaxMembers mode select (Unlimited/50/100/Custom) — Custom reveals number input; 50 and 100 auto-set value
- [ ] **Save Tier** (new) — `createMembershipTier` fires with benefits[] payload → toast "Tier created" → panel closes → card grid refreshes → new card appears → Benefits Comparison Table re-renders including new tier column
- [ ] **Save Tier** (edit) — `updateMembershipTier` persists diff (add new / update existing / delete removed benefits) → card refreshes
- [ ] Kebab **Duplicate** — opens panel in new mode pre-filled with `{sourceCode}_COPY` + `{sourceName} (Copy)` + all benefits cloned without ids → save creates new tier
- [ ] Kebab **Deactivate** — confirm toast → `toggleMembershipTier` → card renders with opacity-60 + "Inactive" badge; Deactivate label flips to "Activate"
- [ ] Kebab **Delete** — confirm dialog → `deleteMembershipTier` → card removed from grid
- [ ] Kebab **View Members** — navigates to `/{lang}/crm/membership/memberlist?tierId={id}` — target page is stub until #59 built; toast "Member list module pending" allowed as alternative (SERVICE_PLACEHOLDER)
- [ ] BenefitsComparison Table renders below card grid: rows = union of distinct `benefitText` across all tiers; columns = each active tier (emoji + name 2-line header); cells = ✔ (green) when tier has matching benefit with `isIncluded=true`, ✖ (muted minus) otherwise
- [ ] When no tiers exist (fresh install before seeding): card-grid empty state "Create your first membership tier" + BenefitsComparison widget hidden or empty-state
- [ ] Permissions respected: buttons/actions hidden or disabled per BUSINESSADMIN capabilities

**DB Seed Verification:**
- [ ] Menu `MEMBERSHIPTIER` appears in sidebar under `CRM_MEMBERSHIP` at OrderBy=3
- [ ] 3 MasterDataTypes + 12 MasterData rows seeded (MEMBERSHIPPRICINGMODEL×5, MEMBERSHIPMINDONATION×4, MEMBERSHIPDOWNGRADEPOLICY×3)
- [ ] 5 sample `MembershipTier` rows + ~39 `MembershipTierBenefit` rows seeded (per sample breakdown above)
- [ ] Comparison Table in rendered page matches `html_mockup_screens/screens/membership/membership-tiers.html` Benefits Comparison section (8 benefit rows × 5 tier columns — Newsletter/Impact Report/Member Events/Voting Rights/Website Recognition/VIP Seating/Director Meeting/Named Sponsorship)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **NEW schema `mem`** — first entity in this schema. BE dev MUST bootstrap IMemDbContext + MemDbContext + MemMappings + DecoratorMemModules + 6 wiring files (GlobalUsing ×3, IApplicationDbContext inheritance, both DependencyInjection.cs). Follow **Program #51** (Case schema bootstrap) as the reference — swap `Case`→`Mem` everywhere.
- **FE stub exists** at `PSS_2.0_Frontend/src/app/[lang]/crm/membership/membershiptier/page.tsx` (4-line "Need to Develop"). FE dev must **overwrite** this file, not create a new one at a different path. Route path is `membershiptier` (one word, no hyphens, per MODULE_MENU_REFERENCE.md) — do NOT use `membership-tier` or `membership-tiers`.
- **NEW card variant `membership-tier`** — Add ONE new variant file + ONE new skeleton + ONE registry line. Do NOT touch the `<CardGrid>` shell. Reference: Family #20 `family-card` variant + Email Template #24 `iframe` variant.
- **Custom `layoutOverride: hscroll`** — mockup shows horizontal-scroll tier cards, not the default 1→4 column responsive grid. FE dev should introduce a new CardGrid layout mode (`hscroll`) OR wrap the CardGrid in a horizontal-scroll div with `flex gap-3 overflow-x-auto pb-2`. Discuss with UX agent if complexity warrants extending CardGrid vs wrapping. If wrapping, still register the variant normally — only the outer list renders differently.
- **Slide-panel width 520px (not 80%)** — Program #51's drawer is 80%-right. MembershipTier's panel is fixed 520px (mockup-specific). On mobile (<768px), panel becomes full-width. FE dev can copy Program's drawer skeleton but override the width class.
- **PricingModel conditional visibility** — FREE disables all fee inputs; PWYW nulls annual+monthly fees; FIXED_ANNUAL requires `annualFee`; FIXED_MONTHLY requires `monthlyFee`. Enforce in BOTH zod schema (FE) AND validator (BE). See §④.
- **TierCode auto-derive on Create** — not a BE concern. FE derives `tierCode = tierName.toUpperCase().replaceAll(/[^A-Z0-9]/g, '_')` on Create submit. If BE returns "duplicate" error, FE retries with `_2`, `_3` suffix (max 5 retries). Alternative: BE handles auto-increment suffix. Document decision during UX review.
- **`memberCount` SERVICE_PLACEHOLDER** — always returns 0 until MemberEnrolment #59 lands. Card renders "0 members" with tooltip "Computed when Member Enrollment module is available". Do NOT add TODO dead code — return `0` constant in the query projection.
- **`View Members` kebab action** — navigates to `/{lang}/crm/membership/memberlist?tierId={id}`. Target screen is #59 (status PARTIAL — FE stub). Until #59 is built, the navigation takes user to the stub page. Acceptable for MVP. Add toast "Member list coming with #59" as optional fallback.
- **Benefits Comparison Table derivation** — is purely FE logic (reads `tiers[].benefits[]`, unions benefit texts case-insensitively, pivots). No BE query needed. The dedup by `benefitText.toLowerCase().trim()` MAY cluster legitimately-different benefits if seed authors type casing differently ("VIP Seating" vs "VIP seating"). Advise seed author to use consistent casing.
- **Self-FK `UpgradeFromTierId`** — zod schema must validate `upgradeFromTierId != membershipTierId`. BE validator also enforces. FE ApiSelect must filter out current tier on edit mode (pass `excludeIds: [tierId]` payload to the select component — if unsupported, filter in-component via `.filter(opt => opt.value !== tierId)`).
- **Sort-order guard for Upgrade Path** — "you upgrade FROM a lower tier" is enforced by BE (`upgradeFrom.SortOrder < this.SortOrder`). Confirm with BA during approval; if user disagrees, soften to FE-only soft warning (no BE validation error).
- **Lifetime tier "one-time" copy** — mockup shows "$5,000 one-time" for Lifetime. There is no dedicated `LIFETIME_ONETIME` pricing model in MVP. Seed Lifetime as `FIXED_ANNUAL` with a special `TierLabel="Elite"` and note the copy liberty. See **ISSUE-9** for the follow-up.
- **Seed folder typo** — preserve `sql-scripts-dyanmic/` (not `dynamic/`) — matches ChequeDonation #6 / Program #51 / Refund #13 precedent.
- **Comparison matrix & kebab icons** — use Phosphor `ph:*` icons per UI uniformity memory (no `fa-*`). Mockup uses FontAwesome; substitute Phosphor equivalents: `ph:check-circle-fill` / `ph:minus-circle` for check-yes/check-no; `ph:pencil` / `ph:users` / `ph:copy` / `ph:pause` / `ph:trash` for kebab.

**Service Dependencies** (UI-only — no backend service implementation):

- ⚠ **SERVICE_PLACEHOLDER — `memberCount`**: Full UI implemented (card shows "{n} members" line with tooltip). Handler returns `0` constant because `MemberEnrolment` entity (#59) does not exist yet. When #59 lands, replace the projection with `Context.MemberEnrolments.Count(m => m.MembershipTierId == t.Id && m.IsActive)`.
- ⚠ **SERVICE_PLACEHOLDER — `View Members` kebab action**: Full UI implemented (kebab option present, navigates). Target `memberlist` route exists as a 4-line stub until #59. Toast fallback optional.
- ⚠ **SERVICE_PLACEHOLDER — Delete cascade impact warning**: Confirm dialog says "Existing members are NOT affected (MemberEnrolment #59 not yet built)". When #59 lands, extend dialog to show count of blocked members and require reassignment before delete.

Full UI must be built (buttons, panel, form, benefits child-grid, comparison matrix). Only `memberCount` computation and `View Members` target screen are placeholders.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues (pre-flagged by /plan-screens)

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Planning (2026-04-24) | HIGH | BE-AGG | `memberCount` SERVICE_PLACEHOLDER — returns 0 constant until MemberEnrolment #59 lands. Replace projection with `Context.MemberEnrolments.Count(m => m.MembershipTierId == t.Id && m.IsActive)` when #59 builds. | OPEN |
| ISSUE-2 | Planning (2026-04-24) | HIGH | FE-NAV | `View Members` kebab action navigates to `memberlist` route (#59 stub). Confirm UX behavior with BA — toast fallback vs silent stub. | OPEN |
| ISSUE-3 | Planning (2026-04-24) | MED | BE-VAL | Sort-order guard for `UpgradeFromTierId.SortOrder < this.SortOrder` — BE hard-validation vs FE soft-warning. Confirm with BA during approval. | OPEN |
| ISSUE-4 | Planning (2026-04-24) | MED | BE-DEL | Delete-cascade restriction when MemberEnrolment #59 builds — current MVP allows delete freely. Add restrict-delete guard + migration note to re-enable when #59 ships. | OPEN |
| ISSUE-5 | Planning (2026-04-24) | MED | FE-FORM | `TierCode` auto-derive on Create conflict strategy — FE retry with `_2/_3` suffix vs BE auto-increment. Decide during UX review; document in form-schemas. | OPEN |
| ISSUE-6 | Planning (2026-04-24) | LOW | FE-UX | Benefits drag-to-reorder NOT in mockup; deferred for MVP. If enablement requested, use `@dnd-kit/sortable` (precedent from Program #51 or MasterData). | OPEN |
| ISSUE-7 | Planning (2026-04-24) | MED | FE-CARDGRID | Custom `layoutOverride: hscroll` — either extend `<CardGrid>` to support horizontal-scroll layout mode OR wrap CardGrid in overflow-x-auto div. Discuss with UX agent during UX design phase. | OPEN |
| ISSUE-8 | Planning (2026-04-24) | LOW | FE-COMPARE | BenefitsComparison dedup by `benefitText` is case-insensitive-trim. Legitimate case differences in seed (e.g., "VIP Seating" vs "VIP seating") will cluster. Advise consistent casing; surface as BA note during seed review. | OPEN |
| ISSUE-9 | Planning (2026-04-24) | LOW | SEED | Lifetime tier seeded as `FIXED_ANNUAL` (not `LIFETIME_ONETIME`). Mockup copy says "$5,000 one-time" but DB pricing model doesn't support one-time for MVP. Follow-up: add `LIFETIME_ONETIME` to MEMBERSHIPPRICINGMODEL MasterData + FE displayPrice branch. | OPEN |
| ISSUE-10 | Planning (2026-04-24) | LOW | SEED | `sql-scripts-dyanmic/` folder typo — preserve per ChequeDonation #6 precedent. Do NOT "fix" during this build. | OPEN |
| ISSUE-11 | Planning (2026-04-24) | MED | BE-BOOT | `mem` schema is NEW — bootstrap ordering matters. Must create ALL of IMemDbContext + MemDbContext + MemMappings + DecoratorMemModules + GlobalUsing lines BEFORE running `dotnet ef migrations add` or EF will miss the DbSet in model scanning. Follow Program #51 ordering exactly. | OPEN |
| ISSUE-12 | Planning (2026-04-24) | LOW | FE-ICON | Mockup uses `fa-*` FontAwesome icons. Per UI uniformity memory, substitute Phosphor `ph:*` equivalents in all new components (card variant, form sections, comparison table). Do NOT import FontAwesome. | OPEN |
| ISSUE-13 | Planning (2026-04-24) | LOW | FE-FORM | Mockup Benefits section shows "edit icon" next to each benefit row. Proposed simplification: make inline text always-editable, drop the edit-icon. Confirm during UX design. | OPEN |
| ISSUE-14 | Planning (2026-04-24) | MED | BE-UNIQUE | `TierCode` unique-per-Company vs soft-deleted reuse — follow ContactType pattern (exclude `IsActive=false` from uniqueness check). Explicitly test on soft-delete→recreate flow in E2E. | OPEN |
| ISSUE-15 | Planning (2026-04-24) | LOW | FE-STORE | Zustand store for drawer state (open/mode/editingTierId) — mirror `chequedonation-store.ts` shape for consistency. Alternative: useState co-located in index-page. Decide based on whether Zustand is required for optimistic refresh after mutation (preferred). | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}