---
screen: MembershipTier
registry_id: 58
module: Membership
status: PENDING
scope: FULL
screen_type: MASTER_GRID
complexity: Medium
new_module: YES — mem schema
planned_date: 2026-04-22
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed
- [x] Existing code reviewed (FE route stub only — no BE)
- [x] Business rules extracted
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized
- [ ] User Approval received
- [ ] Backend code generated
- [ ] Backend wiring complete
- [ ] Frontend code generated
- [ ] Frontend wiring complete
- [ ] DB Seed script generated (including GridFormSchema)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at correct route
- [ ] CRUD flow tested (Create → Read → Update → Toggle → Delete)
- [ ] Tier cards render correctly with card-grid display
- [ ] RJSF modal form renders with all fields + validation
- [ ] Benefits list (child collection) renders inline in form with add/delete
- [ ] Currency dropdown loads data via CURRENCIES_QUERY
- [ ] MemberCount aggregation renders on each card (0 placeholder until MemberEnrolment built)
- [ ] Benefits Comparison Table renders below card grid
- [ ] Duplicate action works — clones tier + benefits
- [ ] DB Seed — menu visible in sidebar, grid + form schema render

---

## ① Screen Identity & Context

Screen: MembershipTier
Module: Membership (CRM)
Schema: mem
Group: Membership (new — does not exist yet)

Business: The Membership Tiers screen allows administrators to define and manage the different membership levels an NGO offers (e.g., Bronze, Silver, Gold, Platinum, Lifetime). Each tier configures the membership's pricing model (annual, monthly, one-time), fee amounts, auto-renew defaults, grace periods, and eligibility rules (minimum donation history, upgrade/downgrade paths, member capacity). Tiers also carry a per-tier list of benefits (e.g., Newsletter, Voting Rights, VIP Seating) that can be added and managed inline. This is a foundational setup entity — Member Enrollment (#59) and Membership Renewal (#60) both FK into this table. The screen also features a Benefits Comparison Table (read-only cross-tier matrix) shown below the tier cards, which helps admins review which benefits are offered across all tiers at a glance.

---

## ② Entity Definition

### Primary Entity

Table: mem."MembershipTiers"

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| MembershipTierId | int | — | PK | — | Primary key |
| TierName | string | 100 | YES | — | e.g., "Bronze", "Gold" |
| DisplayName | string | 100 | NO | — | Shown to members, e.g., "Gold Member" |
| Description | string | 500 | NO | — | Rich text description |
| TierIcon | string | 20 | NO | — | Emoji or icon badge, e.g., "🥇" |
| TierLabel | string | 50 | NO | — | Category label, e.g., "Premium" |
| SortOrder | int | — | NO | — | Display order |
| TierColor | string | 10 | NO | — | Hex color code, e.g., "#FFD700" |
| PricingModel | string | 50 | YES | — | Fixed Annual / Fixed Monthly / Tiered / Pay What You Want / Free |
| AnnualFee | decimal? | — | NO | — | Annual membership fee |
| MonthlyFee | decimal? | — | NO | — | Monthly fee if monthly option offered |
| JoiningFee | decimal? | — | NO | — | One-time setup/joining fee |
| CurrencyId | int | — | NO | com."Currencies" | FK → Currency |
| AutoRenewDefault | bool | — | NO | — | Default true |
| GracePeriodDays | int? | — | NO | — | Days allowed after expiry (15/30/60/90) |
| MinDonationHistory | string | 50 | NO | — | e.g., "No minimum", "$500+" |
| UpgradePath | string | 100 | NO | — | Which tier this upgrades from, e.g., "From Silver" |
| DowngradePolicy | string | 50 | NO | — | Allow / Prevent / Allow with pro-rata refund |
| MaxMembers | int? | — | NO | — | null = Unlimited |

### Child Entity

Table: mem."MembershipTierBenefits"

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| MembershipTierBenefitId | int | — | PK | — | Primary key |
| MembershipTierId | int | — | YES | mem."MembershipTiers" | FK — cascade delete |
| BenefitDescription | string | 500 | YES | — | e.g., "Quarterly newsletter (exclusive content)" |
| IsIncluded | bool | — | NO | — | Whether benefit is active for this tier; default true |
| SortOrder | int | — | NO | — | Display order |

---

## ③ FK Resolution Table

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| CurrencyId | Currency | Base.Domain/Models/SharedModels/Currency.cs | currencies | currencyName (+ currencyCode) | CurrencyResponseDto |

**Currency GQL note**: The Shared module uses `currencies` field (not `GetAllCurrencyList`). FE dev must import `CURRENCIES_QUERY` from `src/infrastructure/gql-queries/shared-queries/CurrencyQuery.ts` and use the `currencies` query field name in ApiSelectV2.

**MemberCount aggregation note**: MemberEnrolment entity (Wave 2, screen #59) does not exist yet. Implement the `memberCount` aggregation as `SELECT COUNT(*) FROM mem."MemberEnrolments" WHERE MembershipTierId = X` using LINQ — it will return 0 until #59 is built. Do NOT skip — add the SQL but it will find 0 rows.

---

## ④ Business Rules & Validation

**Uniqueness Rules:**
- TierName must be unique per Company (ValidateUniqueWhenCreate + ValidateUniqueWhenUpdate)

**Required Field Rules:**
- TierName is mandatory
- PricingModel is mandatory
- CurrencyId is required when AnnualFee or MonthlyFee is provided

**Conditional Rules:**
- If PricingModel = "Fixed Annual" → AnnualFee should be provided
- If PricingModel = "Fixed Monthly" → MonthlyFee should be provided
- If PricingModel = "Free" → fees are optional (default 0)
- MaxMembers = null means "Unlimited" — UI shows "Unlimited" option

**Business Logic:**
- Duplicate action: clones the tier and all its MembershipTierBenefits with new TierName = "{original} (Copy)"
- Benefits child collection: inline add/edit/delete within the RJSF modal form
- IsIncluded on MembershipTierBenefit: lets admin include/exclude a benefit from the active benefits list without deleting the record
- TierColor + TierIcon are visual customization — no business enforcement

**Workflow**: None — MASTER_GRID setup entity

---

## ⑤ Screen Classification & Pattern Selection

**Screen Type**: MASTER_GRID
**Type Classification**: Type 1 — Flat entity with one child collection, FK to shared entity, no workflow
**Reason**: Simple tier config entity; add/edit via slide-in form (implemented as wide RJSF modal); no URL navigation for add/edit. Has one child collection (TierBenefits) managed inline.

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) — always
- [x] Nested child creation — MembershipTierBenefit (1:many inline)
- [ ] Multi-FK validation — only 1 optional FK (CurrencyId)
- [x] Unique validation — TierName
- [ ] File upload command
- [x] Custom mutation — DuplicateMembershipTier (clone tier + child benefits)

**Frontend Patterns Required:**
- [x] AdvancedDataTable (card-grid display mode with `details` variant)
- [x] RJSF Modal Form (driven by GridFormSchema — wide modal to accommodate benefits list)
- [ ] File upload widget
- [x] Benefits Comparison Panel — below-grid custom component (read-only matrix of benefits vs tiers)
- [x] Grid aggregation columns — memberCount per tier card
- [ ] Info panel / side panel
- [ ] Drag-to-reorder
- [ ] Click-through filter

---

## ⑥ UI/UX Blueprint

### Grid/List View

**Display Mode**: `card-grid`
**Card Variant**: `details`

**Card Config:**
```yaml
cardConfig:
  headerField: "tierName"
  metaFields: ["tierLabel", "pricingModel"]
  snippetField: "description"
  footerField: "memberCount"
```

**Card visual details** (from mockup — FE dev should match):
- Each card has a colored top border (TierColor — 4px solid)
- Large tier icon (emoji) centered at top
- Tier name bold, tier label below in small uppercase
- Price line: formatted fee (annualFee with "/year" or monthly with "/mo" or "one-time")
- Member count: "{N} members" (from memberCount aggregation)
- Action row: Edit button (primary) + More dropdown (Edit, View Members, Duplicate, Deactivate, Delete)
- **View Members** in More dropdown navigates to: `crm/membership/memberlist` (filter by this tier) — use `router.push` with query param

**Grid Columns** (backend pagination/sort reference — rendered as card fields):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Tier Name | tierName | text | auto | YES | Primary |
| 2 | Label | tierLabel | text | 100px | YES | Category |
| 3 | Pricing Model | pricingModel | badge | 140px | YES | |
| 4 | Annual Fee | annualFee | currency | 120px | YES | |
| 5 | Currency | currencyCode | text | 80px | NO | From FK |
| 6 | Auto-Renew | autoRenewDefault | badge | 100px | NO | Yes/No |
| 7 | Member Count | memberCount | count | 120px | YES | Aggregation |
| 8 | Status | isActive | badge | 100px | YES | Active/Inactive |

**Search/Filter Fields**: tierName, pricingModel, isActive

**Grid Actions**: Edit, Duplicate, Toggle Active (Deactivate/Activate), Delete
- "View Members" in More dropdown: navigate to `crm/membership/memberlist`

### RJSF Modal Form

> Wide modal (lg or xl width) to accommodate the benefits list section.

**Form Sections** (in order):
| Section | Title | Layout | Fields |
|---------|-------|--------|--------|
| 1 | Tier Details | 2-column | TierName*, DisplayName, Description (full-width), TierIcon, SortOrder, TierColor |
| 2 | Pricing | 2-column | PricingModel*, AnnualFee, MonthlyFee, JoiningFee, CurrencyId, AutoRenewDefault (toggle), GracePeriodDays |
| 3 | Benefits | 1-column full-width | MembershipTierBenefits array — inline list with add/delete/reorder |
| 4 | Eligibility & Rules | 2-column | MinDonationHistory, UpgradePath, DowngradePolicy, MaxMembers |

**Field Widget Mapping:**
| Field | Widget | Placeholder / Options | Validation | Notes |
|-------|--------|----------------------|------------|-------|
| TierName | text | "Enter tier name" | required, max 100, unique | |
| DisplayName | text | "Shown to members" | max 100 | Optional |
| Description | textarea | "Describe this tier" | max 500 | Full-width |
| TierIcon | text | "🥇 Enter emoji or icon" | max 20 | Emoji input |
| SortOrder | number | "Display order" | min 0 | |
| TierColor | color | "#FFD700" | max 10 | Color picker input + hex text |
| PricingModel | select | Fixed Annual / Fixed Monthly / Tiered / Pay What You Want / Free | required | |
| AnnualFee | number | "0.00" | min 0 | Show when PricingModel not Free |
| MonthlyFee | number | "0.00" | min 0 | Optional |
| JoiningFee | number | "0.00" | min 0 | |
| CurrencyId | ApiSelectV2 | "Select currency" | — | Query: `currencies` (from CURRENCIES_QUERY) |
| AutoRenewDefault | checkbox/toggle | "Auto-Renew by Default" | — | Boolean toggle |
| GracePeriodDays | select | 15 days / 30 days / 60 days / 90 days | — | Mapped as int: 15, 30, 60, 90 |
| MembershipTierBenefits | array | inline editable list | — | Child collection array widget; each item has BenefitDescription (text) + IsIncluded (checkbox) + SortOrder |
| MinDonationHistory | select | No minimum / $100+ / $500+ / $1000+ | — | |
| UpgradePath | select | None / From Bronze / From Silver / From Gold / From Platinum | — | |
| DowngradePolicy | select | Allow / Prevent / Allow with pro-rata refund | — | |
| MaxMembers | select | Unlimited / 50 / 100 / Custom | — | "Unlimited" maps to null |

### Page Widgets & Summary Cards

**Layout Variant**: `widgets-above-grid`
→ FE Dev uses **Variant B**: `<ScreenHeader>` + `<DataTableContainer showHeader={false}>` + `<MembershipBenefitsComparisonPanel>`

**IMPORTANT layout note**: The Benefits Comparison Table is positioned **BELOW** the card grid, not above it. The page render order is:
1. `<ScreenHeader>` — page title + New Tier button
2. `<DataTableContainer showHeader={false}>` — tier cards (card-grid)
3. `<MembershipBenefitsComparisonPanel>` — benefits matrix (below the grid)

No KPI/summary widgets above the grid. The layout uses Variant B solely to accommodate the below-grid comparison panel.

**Page Widgets**: NONE (no above-grid KPI cards)

### Grid Aggregation Columns

**Aggregation Columns**:
| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| memberCount | Count of active member enrollments for this tier | `MemberEnrolments` table → COUNT WHERE MembershipTierId = row.Id AND IsActive = true | LINQ subquery in GetAll query; returns 0 until MemberEnrolment (#59) is built |

### Benefits Comparison Panel (below-grid)

**Component**: `<MembershipBenefitsComparisonPanel>` — separate component, rendered below `<DataTableContainer>`

**Data source**: `GetAllMembershipTierList` response — each tier DTO includes `benefits: [MembershipTierBenefitDto]`.

**Layout** (from mockup):
- Table with benefit rows × tier columns
- Row header: BenefitDescription (left-aligned)
- Column headers: tier icon + name (centered)
- Cell: ✓ (check-yes, green) or — (check-no, gray) based on IsIncluded
- "Benefits Comparison" title with fa-table-list icon
- Horizontally scrollable for many tiers

**Notes**:
- The benefit rows are dynamic (from each tier's benefits collection) — aggregate unique benefit descriptions across all tiers
- For a benefit not listed on a tier, show — (not included)
- This panel is read-only. Editing benefits happens via the Edit tier form.

### User Interaction Flow

1. Page loads → ScreenHeader + tier cards grid (card-grid) + benefits comparison table below
2. "+New Tier" → RJSF modal opens (Create mode) — all sections blank
3. Fill Tier Details, Pricing, add Benefits items, set Eligibility Rules → Save
4. Edit: click Edit on card or More → Edit → modal opens pre-filled
5. Duplicate: More dropdown → Duplicate → `DuplicateMembershipTier` mutation → new card appears with "{Name} (Copy)"
6. Deactivate/Activate: More dropdown → Deactivate → toggle mutation → badge updates on card
7. Delete: More dropdown → Delete → confirm → soft-delete → card disappears
8. View Members: More dropdown → View Members → navigate to `crm/membership/memberlist`
9. Benefits comparison table auto-updates after any tier add/edit/delete (refetch GetAllMembershipTierList)

---

## ⑦ Substitution Guide

**Canonical Reference**: ContactType (MASTER_GRID in CorgModels / `corg` schema)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| ContactType | MembershipTier | Entity/class name |
| contactType | membershipTier | Variable/field names |
| ContactTypeId | MembershipTierId | PK field |
| ContactTypes | MembershipTiers | Table name, collection names |
| contact-type | membership-tier | FE file names |
| contacttype | membershiptier | FE folder, import paths |
| CONTACTTYPE | MEMBERSHIPTIER | Grid code, menu code |
| corg | mem | DB schema |
| Corg | Membership | Backend group name |
| CorgModels | MembershipModels | Namespace suffix |
| CorgBusiness | MembershipBusiness | Business folder name |
| CONTACT | CRM_MEMBERSHIP | Parent menu code |
| CRM | CRM | Module code |
| crm/contact/contacttype | crm/membership/membershiptier | FE route path |
| corg-service | membership-service | FE service folder name |
| Contact | Membership | API EndPoint group folder |

---

## ⑧ File Manifest

### Backend Files — New Module Infrastructure (create BEFORE entity files)

| # | File | Path |
|---|------|------|
| I1 | IMembershipDbContext | Base.Application/Data/Persistence/IMembershipDbContext.cs |
| I2 | MembershipDbContext | Base.Infrastructure/Data/Persistence/MembershipDbContext.cs |
| I3 | MembershipMappings | Base.Application/Mappings/MembershipMappings.cs |

**Module Infrastructure Wiring:**
| # | File to Modify | What to Add |
|---|---------------|-------------|
| W1 | IApplicationDbContext.cs | Add `: IMembershipDbContext` to inheritance list + `//IDbContextLines` entry |
| W2 | ApplicationDbContext.cs (Infrastructure) | Inherit `IMembershipDbContext` + add DbSet properties |
| W3 | DecoratorProperties.cs | Add `DecoratorMembershipModules` class |
| W4 | DependencyInjection.cs | Register `MembershipMappings.ConfigureMappings()` |
| W5 | GlobalUsing.cs (3 files: Domain, Application, Infrastructure) | Add `using Base.Domain.Models.MembershipModels;` (and Application/Infrastructure variants) |

### Backend Entity Files (11 files)

| # | File | Path |
|---|------|------|
| 1 | MembershipTier Entity | Base.Domain/Models/MembershipModels/MembershipTier.cs |
| 2 | MembershipTierBenefit Entity | Base.Domain/Models/MembershipModels/MembershipTierBenefit.cs |
| 3 | EF Config (MembershipTier) | Base.Infrastructure/Data/Configurations/MembershipConfigurations/MembershipTierConfiguration.cs |
| 4 | EF Config (MembershipTierBenefit) | Base.Infrastructure/Data/Configurations/MembershipConfigurations/MembershipTierBenefitConfiguration.cs |
| 5 | Schemas (DTOs) | Base.Application/Schemas/MembershipSchemas/MembershipTierSchemas.cs |
| 6 | Create Command | Base.Application/Business/MembershipBusiness/MembershipTiers/CreateCommand/CreateMembershipTier.cs |
| 7 | Update Command | Base.Application/Business/MembershipBusiness/MembershipTiers/UpdateCommand/UpdateMembershipTier.cs |
| 8 | Delete Command | Base.Application/Business/MembershipBusiness/MembershipTiers/DeleteCommand/DeleteMembershipTier.cs |
| 9 | Toggle Command | Base.Application/Business/MembershipBusiness/MembershipTiers/ToggleCommand/ToggleMembershipTier.cs |
| 10 | Duplicate Command | Base.Application/Business/MembershipBusiness/MembershipTiers/DuplicateCommand/DuplicateMembershipTier.cs |
| 11 | GetAll Query | Base.Application/Business/MembershipBusiness/MembershipTiers/GetAllQuery/GetAllMembershipTier.cs |
| 12 | GetById Query | Base.Application/Business/MembershipBusiness/MembershipTiers/GetByIdQuery/GetMembershipTierById.cs |
| 13 | Mutations | Base.API/EndPoints/Membership/Mutations/MembershipTierMutations.cs |
| 14 | Queries | Base.API/EndPoints/Membership/Queries/MembershipTierQueries.cs |

### Backend Wiring Updates (entity-level)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IMembershipDbContext.cs | DbSet\<MembershipTier\> + DbSet\<MembershipTierBenefit\> |
| 2 | MembershipDbContext.cs | Same DbSet properties |
| 3 | DecoratorProperties.cs | Decorator entry for MembershipTier |
| 4 | MembershipMappings.cs | Mapster mapping for MembershipTier + MembershipTierBenefit |

### Frontend Files (6 files)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | PSS_2.0_Frontend/src/domain/entities/membership-service/MembershipTierDto.ts |
| 2 | GQL Query | PSS_2.0_Frontend/src/infrastructure/gql-queries/membership-queries/MembershipTierQuery.ts |
| 3 | GQL Mutation | PSS_2.0_Frontend/src/infrastructure/gql-mutations/membership-mutations/MembershipTierMutation.ts |
| 4 | Page Config | PSS_2.0_Frontend/src/presentation/pages/crm/membership/membershiptier.tsx |
| 5 | Index Page Component | PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membershiptier/index-page.tsx |
| 6 | Route Page | PSS_2.0_Frontend/src/app/[lang]/crm/membership/membershiptier/page.tsx ← **EXISTS AS STUB — REPLACE** |

**Additional FE components (new):**
| # | File | Path |
|---|------|------|
| 7 | Benefits Comparison Panel | PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/membershiptier/membership-benefits-comparison.tsx |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | MEMBERSHIPTIER operations config |
| 2 | operations-config.ts | Import + register MEMBERSHIPTIER operations |
| 3 | sidebar menu config | MEMBERSHIPTIER entry under CRM_MEMBERSHIP → MEMBERSHIPTIER |
| 4 | gql-queries/index.ts | Export new membership-queries |
| 5 | gql-mutations/index.ts | Export new membership-mutations |
| 6 | domain/entities/index.ts | Export MembershipTierDto |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL

MenuName: Tiers & Plans
MenuCode: MEMBERSHIPTIER
ParentMenu: CRM_MEMBERSHIP
Module: CRM
MenuUrl: crm/membership/membershiptier
GridType: MASTER_GRID

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: GENERATE
GridCode: MEMBERSHIPTIER
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

**GraphQL Types:**
- Query type: `MembershipTierQueries`
- Mutation type: `MembershipTierMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetAllMembershipTierList | [MembershipTierResponseDto] | searchText, pageNo, pageSize, sortField, sortDir, isActive |
| GetMembershipTierById | MembershipTierResponseDto | membershipTierId |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| CreateMembershipTier | MembershipTierRequestDto | int (new ID) |
| UpdateMembershipTier | MembershipTierRequestDto | int |
| DeleteMembershipTier | membershipTierId: int | int |
| ToggleMembershipTier | membershipTierId: int | int |
| DuplicateMembershipTier | membershipTierId: int | int (new ID) |

**Response DTO Fields** (MembershipTierResponseDto):
| Field | Type | Notes |
|-------|------|-------|
| membershipTierId | number | PK |
| tierName | string | |
| displayName | string | |
| description | string | |
| tierIcon | string | emoji |
| tierLabel | string | |
| sortOrder | number | |
| tierColor | string | hex |
| pricingModel | string | |
| annualFee | number \| null | |
| monthlyFee | number \| null | |
| joiningFee | number \| null | |
| currencyId | number \| null | |
| currencyName | string | FK display |
| currencyCode | string | FK display |
| autoRenewDefault | boolean | |
| gracePeriodDays | number \| null | |
| minDonationHistory | string | |
| upgradePath | string | |
| downgradePolicy | string | |
| maxMembers | number \| null | null = Unlimited |
| memberCount | number | Aggregation — COUNT of active MemberEnrolments |
| isActive | boolean | Inherited |
| benefits | MembershipTierBenefitDto[] | Child collection — included in GetAll + GetById |

**MembershipTierBenefitDto:**
| Field | Type | Notes |
|-------|------|-------|
| membershipTierBenefitId | number | PK |
| membershipTierId | number | FK |
| benefitDescription | string | |
| isIncluded | boolean | |
| sortOrder | number | |

**MembershipTierRequestDto (for Create/Update):**
- All MembershipTier scalar fields
- `benefits: MembershipTierBenefitRequestDto[]` — inline child collection (full replace on update)

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/en/crm/membership/membershiptier`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Tier cards render in card-grid layout with icon, name, label, price, member count
- [ ] New Tier → RJSF modal opens with all 4 sections
- [ ] Benefits section in form — can add/edit/delete benefit items inline
- [ ] Currency dropdown loads correctly (CURRENCIES_QUERY)
- [ ] Save → API call → new tier card appears in grid
- [ ] Edit → modal pre-fills all fields including benefits list
- [ ] Duplicate → clones tier → new card "{Name} (Copy)" appears
- [ ] Deactivate/Activate → badge updates on card
- [ ] Delete → card disappears
- [ ] View Members → navigates to memberlist route
- [ ] Benefits Comparison Panel renders below grid with correct matrix
- [ ] memberCount shows 0 (no enrollments yet — expected)
- [ ] Permissions: actions respect role capabilities

**DB Seed Verification:**
- [ ] "Tiers & Plans" menu appears under CRM → Membership in sidebar
- [ ] Grid columns render correctly in card-grid mode
- [ ] GridFormSchema renders form correctly with all 4 sections

---

## ⑫ Special Notes & Warnings

1. **NEW MODULE (CRITICAL)**: This is the FIRST entity in the `mem` schema. The Membership module infrastructure does NOT exist yet. Backend developer must create all 5 infrastructure items BEFORE entity files:
   - `IMembershipDbContext.cs` in `Base.Application/Data/Persistence/`
   - `MembershipDbContext.cs` in `Base.Infrastructure/Data/Persistence/`
   - `MembershipMappings.cs` in `Base.Application/Mappings/`
   - Add `IMembershipDbContext` to `IApplicationDbContext` inheritance
   - Register in `DependencyInjection.cs`
   - Add `DecoratorMembershipModules` class in `DecoratorProperties.cs`
   - Update GlobalUsing.cs in all 3 projects with `using Base.Domain.Models.MembershipModels;`

2. **Existing FE route stub**: `PSS_2.0_Frontend/src/app/[lang]/crm/membership/membershiptier/page.tsx` already exists with a placeholder ("Need to Develop"). FE developer must REPLACE this file, not create a new one at a different path.

3. **New FE service folders**: `membership-service` (domain/entities), `membership-queries` (gql-queries), `membership-mutations` (gql-mutations) do not exist yet — create them as new folders.

4. **Currency FK non-standard query**: Currency uses GQL field `currencies` (not `GetAllCurrencyList`). FE dev must use `CURRENCIES_QUERY` from `src/infrastructure/gql-queries/shared-queries/CurrencyQuery.ts` when wiring the CurrencyId ApiSelectV2.

5. **Child collection — MembershipTierBenefit**: Create/Update commands must handle full-replace of the benefits collection (delete all existing + re-insert). The child entity is `MembershipTierBenefit` in the same `mem` schema.

6. **memberCount aggregation**: The `MemberEnrolment` entity (screen #59, Wave 2) does NOT exist yet. The GetAllMembershipTier LINQ query should include the subquery:
   ```csharp
   memberCount = context.MemberEnrolments.Count(e => e.MembershipTierId == t.MembershipTierId && e.IsActive)
   ```
   This will return 0 for all tiers until #59 is built. The query will fail to compile if MemberEnrolment DbSet isn't available — use a try-0 approach or leave as `0` until that entity is added to `IMembershipDbContext`.

   **Recommended**: For now, hardcode `memberCount = 0` in the GetAll query and add a TODO comment. Uncomment when #59 is built.

7. **Duplicate mutation** (custom, not standard CRUD): `DuplicateMembershipTier` clones the parent tier record (TierName = "{original} (Copy)", IsActive = true) and all child `MembershipTierBenefit` records with new IDs.

8. **Benefits Comparison Panel**: This is a bonus component that reads from the GetAllMembershipTierList result (which includes child benefits). No separate query needed. The FE dev renders it as a separate component below `<DataTableContainer>` in the index-page.

9. **card-grid infrastructure**: The `<CardGrid>` infrastructure and `details` card variant were introduced in screen #36 (SMS Template, Wave 2.4). These should already be available for this screen to use (check `.claude/feature-specs/card-grid.md` for details). This screen does NOT need to create the card-grid shell — only supply its `cardConfig`.

**Service Dependencies**: None — no external service calls required. All functionality is standard CRUD + custom clone mutation.

---

## ⑬ Build Log (append-only)

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| — | — | — | — | (empty — no issues raised yet) | — |

### § Sessions

{No sessions recorded yet — filled in after /build-screen completes.}
