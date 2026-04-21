# Staff (#42) — FLOW screen prompt

> **Scope**: ALIGN — near-greenfield rebuild of form + detail UX, major BE schema extension.
> **Canonical sibling**: RecurringDonationSchedule #8 (drawer-based DETAIL) + Family #20 (accordion FORM + 4 KPI widgets) + StaffCategory #43 (Organization module conventions).
> **Status**: PROMPT_READY (2026-04-20)

---

## ① Identity & Context

- **Screen**: Staff Management (`/[lang]/organization/staff/staff`)
- **Registry**: #42
- **Module**: Organization (Module code: `ORGANIZATION`)
- **Parent Menu**: `STAFF` (parent group `ORG_STAFF`, MenuId 363 — shared with StaffCategory #43)
- **MenuCode**: `STAFFS` (plural — per MODULE_MENU_REFERENCE; NOT "STAFF" which is the ParentMenu)
- **Screen Type**: `FLOW`
- **Complexity**: High
- **Business Context**: Unified directory of organization staff members (programme staff, fundraising, field officers, administrators, finance, etc.) across branches/org-units. Each staff record optionally maps to a system user for login access. Acts as the assignee entity for donations-collector, receipt-issuer, campaign-owner relationships across CRM. Precedes Volunteer #53, Field Collection Ambassador #67, and any screen that needs a "reporting-to"/"owner" dropdown.

- **Mockup**: [`html_mockup_screens/screens/organization/staff-management.html`](../../../html_mockup_screens/screens/organization/staff-management.html) (2037 lines — list + right-drawer detail + right-drawer form)

---

## ② Entity Definition

### Current BE entity (`Base.Domain/Models/ApplicationModels/Staff.cs`)

```csharp
[Table("Staffs", Schema = "app")]
public class Staff : Entity   // Entity base = Id/IsActive/IsDeleted/CreatedBy/CreatedDate/ModifiedBy/ModifiedDate
{
    public int StaffId { get; set; }
    [CaseFormat("title")] public string StaffName { get; set; } = default!;
    public string StaffEmpId { get; set; } = default!;
    public string StaffEmail { get; set; } = default!;
    public string StaffMobileNumber { get; set; } = default!;
    public int StaffCategoryId { get; set; }
    public int UserId { get; set; }
    public int? CompanyId { get; set; }
    public int? BranchId { get; set; }
    public StaffCategory StaffCategory { get; set; } = default!;
    public User User { get; set; } = default!;
    public Company Company { get; set; } = default!;
    public virtual Branch? Branch { get; set; }
    public ICollection<GlobalReceiptDonation>? GlobalReceiptDonationCollectors { get; set; }
    public ICollection<GlobalReceiptDonation>? GlobalReceiptIssuers { get; set; }
    public ICollection<GlobalReceiptDonation>? GlobalReceiptDonationDepositors { get; set; }
    public ICollection<ChequeDonation>? ChequeDonationCollectors { get; set; }
    public ICollection<ChequeDonation>? ChequeDonationDepositors { get; set; }
    public ICollection<GlobalDonation>? GlobalDonations { get; set; }
}
```

### Target BE entity (ALIGN — new columns)

Add the following columns (all nullable where appropriate — preserve backward compat with existing 8-field entity):

| Column | Type | Null? | Notes |
|--------|------|-------|-------|
| `FirstName` | `string` (100) | NOT NULL | Mockup Section 1 * |
| `LastName` | `string` (100) | NOT NULL | Mockup Section 1 * |
| `DisplayName` | `string` (200) | computed | `= FirstName + ' ' + LastName` — keep `StaffName` as derived/legacy (backfill = DisplayName) |
| `Gender` | `string` (20) | nullable | ENUM-like string `Male/Female/Other/Prefer not to say` |
| `DateOfBirth` | `DateOnly?` | nullable | |
| `PhotoUrl` | `string` (500) | nullable | SERVICE_PLACEHOLDER until upload infra |
| `PersonalEmail` | `string` (200) | nullable | |
| `PersonalPhone` | `string` (50) | nullable | |
| `OrganizationalUnitId` | `int?` | nullable FK | → `OrganizationalUnit.OrganizationalUnitId` |
| `JobTitle` | `string` (200) | nullable | "Role / Job Title" free text (e.g. "Program Coordinator") |
| `EmploymentType` | `string` (30) | nullable | ENUM-like `FULLTIME/PARTTIME/CONTRACT/VOLUNTEER/INTERN` — stored as code string |
| `JoinDate` | `DateOnly?` | NOT NULL on mockup * | required at Create when EmploymentType set |
| `EndDate` | `DateOnly?` | nullable | future-dated or historical |
| `ReportingToStaffId` | `int?` | nullable self-FK | → `Staff.StaffId` (no cycle) |
| `StaffStatus` | `string` (20) | nullable | `ACTIVE/INACTIVE/ONLEAVE` code string (independent of `IsActive` which is soft-delete semantics) |
| `EmergencyContactName` | `string` (100) | nullable | |
| `EmergencyContactPhone` | `string` (50) | nullable | |
| `EmergencyContactRelationship` | `string` (50) | nullable | |
| `Skills` | `string` (2000) | nullable | CSV — comma-separated tags (MVP; junction table future) |
| `Languages` | `string` (500) | nullable | CSV — comma-separated tags |
| `Notes` | `string` (2000) | nullable | |

### Derived / projected fields (NOT stored)

- `CategoryName` (from `StaffCategory.StaffCategoryName`)
- `CategoryCode` (from `StaffCategory.StaffCategoryCode`)
- `CategoryColorHex` (from `StaffCategory.ColorHex` — added in #43)
- `BranchName` (from `Branch.BranchName`)
- `OrganizationalUnitName` (from `OrganizationalUnit.UnitName`)
- `OrganizationalUnitCode` (from `OrganizationalUnit.UnitCode`)
- `ReportingToName` (projected from reporting-to Staff.DisplayName via join)
- `UserName` (from `User.UserName`)
- `UserProfilePathUrl` (from `User.ProfilePathUrl`)
- `HasUserAccount` = `UserId > 0`
- `LastLogin` (from `User.LastLoginDate` — if exists, else null → SERVICE_PLACEHOLDER)
- `FullName` = `FirstName + ' ' + LastName` (if already on entity, use directly)

### Inheritance (audit columns — skip)

From `Entity`: `Id`, `IsActive`, `IsDeleted`, `CreatedBy`, `CreatedDate`, `ModifiedBy`, `ModifiedDate`.

---

## ③ FK Resolution Table

| FK Field | Target Entity | Entity Path | GraphQL Query (field name) | Display Field | Group/Schema |
|----------|---------------|-------------|----------------------------|---------------|-------------|
| `StaffCategoryId` | StaffCategory | `Base.Domain/Models/ApplicationModels/StaffCategory.cs` | `staffCategories` (paginated) | `staffCategoryName` (id: `staffCategoryId`) | Application / `app` |
| `BranchId` | Branch | `Base.Domain/Models/ApplicationModels/Branch.cs` | `branches` (paginated) | `branchName` (id: `branchId`) | Application / `app` |
| `OrganizationalUnitId` **[NEW]** | OrganizationalUnit | `Base.Domain/Models/ApplicationModels/OrganizationalUnit.cs` | `organizationalUnits` (paginated) | `unitName` (id: `organizationalUnitId`) | Application / `app` |
| `UserId` | User (auth) | `Base.Domain/Models/AuthModels/User.cs` | `users` (paginated) | `userName` (id: `userId`) | Auth / `auth` |
| `ReportingToStaffId` **[NEW, self-FK]** | Staff | (this entity) | `staffs` (paginated) | `displayName` (id: `staffId`) | Application / `app` |
| `CompanyId` | Company | `Base.Domain/Models/ApplicationModels/Company.cs` | `companies` (paginated) | `companyName` (id: `companyId`) | Application / `app` |

**MasterData-backed** (no FK column, dropdown uses `masterDatas` query with `advancedFilter: typeCode = X`):

| Field | TypeCode | Notes |
|-------|----------|-------|
| `Gender` | `GENDER` | Seeded: Male, Female, Other, Prefer not to say |
| `EmploymentType` | `STAFFEMPLOYMENTTYPE` | Seeded: Full-time, Part-time, Contract, Volunteer, Intern |
| `StaffStatus` | `STAFFSTATUS` | Seeded: Active, Inactive, On Leave |

> **Storage decision**: Store code strings (not MasterDataId FK) for these three — keeps schema simpler, aligns with existing entity style (`StaffEmpId` etc.), avoids 3 extra FK columns. MasterData is used for the *dropdown options source* only.

### FK already resolved in existing entity (no work needed)

- `Company`, `StaffCategory`, `User`, `Branch` navs already present with proper inverse-nav setup.

---

## ④ Business Rules

### Identification & uniqueness
- **`StaffEmpId` auto-generated**: format `STF-{NNNN}` (zero-padded, per Company). Existing handler does NOT auto-gen — currently user-entered. MUST be added to CreateStaff handler: `$"STF-{nextSeq:D4}"`.
- `StaffEmpId` **unique per Company** (existing validator — keep; relax scope from global to per-Company).
- `StaffEmail` (work email) **unique per Company** (existing).
- `StaffMobileNumber` (work phone) **unique per Company** (existing).
- `FirstName` + `LastName` required.
- `StaffCategoryId`, `OrganizationalUnitId`, `JobTitle`, `JoinDate`, `StaffEmail` required (Section 1 + 2 mockup `*` asterisks).

### User account linkage
- Create mode offers **two paths**: (a) Link existing User account (dropdown of users with `UserId NOT IN (SELECT UserId FROM Staffs)` — unassigned users only), OR (b) Create New User Account sub-form (username, roleId, sendWelcomeEmail toggle).
- When creating new User: `UserName = WorkEmail`, `AlternateUserName = WorkMobileNumber`, `Password` field (min 6 chars), `UserTypeId` = "Staff" usertype (resolved in handler as today).
- Edit mode: shows "Linked account display" with unlink option (sets UserId back to unassigned — but since current entity has `UserId int` (non-nullable int), unlink NOT supported without migration. Mark as SERVICE_PLACEHOLDER for now — unlink shows toast "Not yet supported". Alternative: rely on future Unlink command.
- "Send welcome email" toggle is SERVICE_PLACEHOLDER (no email pipeline yet).

### Lifecycle
- **Soft delete** via `IsDeleted` flag (existing `DeleteStaff` handler). No hard-delete even for admins.
- **`IsActive` vs `StaffStatus`**: `IsActive` = admin-enabled flag (ToggleStaffStatus); `StaffStatus` = HR state (`ACTIVE/INACTIVE/ONLEAVE`). When `IsActive=false`, grid displays "Inactive" regardless of StaffStatus. Grid Status badge prefers `StaffStatus` when `IsActive=true`, else shows "Inactive".
- Deactivate from More menu → calls `ToggleStaffStatus` (existing) which flips `IsActive` only.
- Activate from More menu (shown when `IsActive=false`) → same toggle.

### Guards
- Cannot delete/deactivate a Staff that has any `GlobalReceiptDonation`/`ChequeDonation`/`GlobalDonation` with their StaffId in any of the collector/issuer/depositor roles → return 422 `Cannot delete: Staff is linked to N donation records`. Show counts in tooltip.
- Cannot set `ReportingToStaffId = self` → validator.
- Cannot set `ReportingToStaffId` to a descendant (cycle prevention) → validator via reverse-walk (up to 10 levels — same pattern as OrganizationalUnit Move check).
- `JoinDate <= EndDate` if EndDate set.
- `DateOfBirth` → age ≥ 14 (sanity).

### Transfer action (mockup "Transfer" menu item)
- Shows a small Transfer modal → selects new `BranchId` and/or `OrganizationalUnitId`. Calls a new `TransferStaffCommand` which updates those two FKs and timestamps `ModifiedDate`. No branch-history table (SERVICE_PLACEHOLDER for audit trail; mockup Branch History section stays as a static stub rendered from ModifiedDate deltas — actual tracked table deferred).

### Activity Summary (detail drawer)
- **Donations processed YTD** — count of `GlobalDonation WHERE StaffId = X AND Year(CreatedDate) = Now.Year` — project via new query handler (or SERVICE_PLACEHOLDER initially).
- **Collections made** — count of `GlobalReceiptDonation WHERE CollectorStaffId = X`.
- **Events managed** — count of `Event WHERE OwnerStaffId = X` — but `Event.OwnerStaffId` does NOT exist yet → SERVICE_PLACEHOLDER → `0`.
- **Last login** — `User.LastLoginDate` (field availability TBD; if User doesn't track it, SERVICE_PLACEHOLDER).

All four in one new query: `GetStaffActivitySummary(staffId) → { donationsYtd, collections, events, lastLogin }`. Detail drawer fetches lazily on open.

### Header KPI widgets (4)
One new query `GetStaffSummary() → StaffSummaryDto`:
- `totalCount`, `activeCount`, `inactiveCount` → card 1
- `categoryCount`, `categoryBreakdown: [{code, name, count}]` (top 5) → card 2
- `totalBranches`, `branchesWithStaff` → card 3 (requires grouping Staff by BranchId, count distinct where non-null)
- `totalStaff`, `staffWithUser` (count where UserId > 0) → card 4 (percentage computed on FE)

### Filter args (GetAll extension)
Add to `GetStaffsQuery` (top-level args — NOT via advancedFilter):
- `categoryId: int?`
- `organizationalUnitId: int?`
- `branchId: int?`
- `staffStatus: string?` (code: ACTIVE/INACTIVE/ONLEAVE)
- `hasUserAccount: bool?` (true = UserId > 0, false = UserId == 0 or null — requires nullable migration OR treat 0 as null)

### Free-text search (existing, extend)
Extend search to also match: `FirstName`, `LastName`, `DisplayName`, `JobTitle`, `PersonalEmail`, `OrganizationalUnit.UnitName`.

---

## ⑤ Classification

| Dimension | Value |
|-----------|-------|
| Template | `_FLOW.md` |
| Index variant | `widgets-above-grid` → **Variant B mandatory** (ScreenHeader + DataTableContainer `showHeader={false}`) |
| URL modes | `?mode=new`, `?mode=edit&id=X`, `?mode=read&id=X` |
| FORM layout | **Full-page** view-page with **4 collapsible accordion cards** (icons per mockup: fa-user, fa-briefcase, fa-user-shield, fa-circle-info) |
| DETAIL layout | **Right-side drawer** (520px) — 3 sections: Employment Details (2-col grid), Activity Summary (4 stats), Branch History (placeholder list) |
| Grid shape | Tabular (not card-grid) — 10 columns, row-click = open detail drawer |
| KPI widgets | 4 above grid |
| Filter chips | None in mockup — use advanced filter dropdowns (Category/OrgUnit/Status/UserAccount) via an `advanced-filter-panel` collapsed above grid |
| GridFormSchema | **SKIP** (FLOW — no dynamic JSON schema; form is code-driven) |
| Multi-tenant | Yes — `CompanyId` scoping in GetAll (apply `CompanyScope` — currently only soft-implemented via `HttpContextAccessor.GetCurrentUserStaffCompanyId()`) |
| Re-orderable? | No (mockup has no drag handle) |
| Bulk actions? | No (mockup has none) |
| Export? | Yes — existing `ExportStaff` query; keep |
| Import? | Stub — "Import Staff" button in header → SERVICE_PLACEHOLDER toast |
| Print? | No |
| Subtype in registry Notes | `CODE_EXISTS` — both BE+FE exist but substantially diverge from mockup |

---

## ⑥ UI/UX Blueprint

### Page-level composition (INDEX — `?mode` absent)

Layout: Variant B.

```
<AdvancedDataTableStoreProvider gridCode="STAFFS">
  <ScreenHeader
    title="Staff Management"
    subtitle="Manage staff across your organization"
    primaryAction={{ label: "Add Staff", icon: "ph:plus", onClick: () => setCrudMode("add") }}
    secondaryActions={[
      { label: "Import Staff", icon: "ph:file-arrow-up", onClick: () => toast.info("Import pending") }, // SERVICE_PLACEHOLDER
      { label: "Export", icon: "ph:file-arrow-down", onClick: exportHandler },
    ]}
  />
  <StaffWidgets />                         {/* 4 KPI cards, grid-cols-1 sm:2 lg:4 gap-4 mb-4 */}
  <StaffAdvancedFilterPanel />             {/* Collapsible chip bar + 4 selects */}
  <FlowDataTableStoreProvider gridCode="STAFFS">
    <DataTableContainer
      gridCode="STAFFS"
      showHeader={false}
      onRowClick={(row) => openDetailDrawer(row.staffId)}
    />
  </FlowDataTableStoreProvider>
  <StaffDetailDrawer />                    {/* portal — open when URL has ?mode=read&id=X */}
</AdvancedDataTableStoreProvider>
```

### KPI widgets (`<StaffWidgets />`)

Query: `GetStaffSummary()` → 4 cards, `grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4`:

| # | Icon (Phosphor) | Color-token | Value | Sub |
|---|----------------|-------------|-------|-----|
| 1 | `ph:identification-badge` | `bg-blue-50 text-blue-600` | `totalCount` | `Active: {activeCount} · Inactive: {inactiveCount}` |
| 2 | `ph:stack-simple` | `bg-purple-50 text-purple-600` | `categoryCount` | join top-5 `{name}: {count}` |
| 3 | `ph:buildings-apartment` | `bg-green-50 text-green-600` | `{branchesWithStaff} / {totalBranches}` | `{totalBranches - branchesWithStaff} branches have no staff` |
| 4 | `ph:user-circle-gear` | `bg-amber-50 text-amber-600` | `{staffWithUser} / {totalCount}` | `{(staffWithUser/totalCount*100).toFixed(1)}% have system login` |

Loading → shaped Skeletons (`h-5 w-16` for value, `h-3 w-32` for sub). Empty-state on null summary → render "—".

### Advanced filter panel (`<StaffAdvancedFilterPanel />`)

Collapsible section above grid (default: collapsed). 5-col grid: Search (already part of DataTableContainer internal? — keep external search override) + Category select + OrgUnit select + Status select + UserAccount select + Clear button.

Pushes values into `FlowDataTableStore.advancedFilter` (or better: top-level GQL args once BE adds them — per mockup spec `/④`).

Cells:
- Category dropdown: `<ApiSelectV2 query={STAFFCATEGORIES_QUERY} valueField="staffCategoryId" labelField="staffCategoryName" placeholder="All Categories" allowClear />`
- OrgUnit dropdown: `<ApiSelectV2 query={ORGANIZATIONAL_UNITS_QUERY} valueField="organizationalUnitId" labelField="unitName" placeholder="All Units" allowClear />`
- Status dropdown: static `<Select>` with ACTIVE/INACTIVE/ONLEAVE
- UserAccount: static `<Select>` with Yes/No

### Grid columns (`STAFFS` — 10 columns, seeded via SQL script)

| Order | Header | GridComponentName (renderer) | Field mapping | Widths (min) |
|-------|--------|------------------------------|---------------|--------------|
| 1 | Staff ID | `staff-id-chip` *(new — small mono chip)* | `staffEmpId` | 90 |
| 2 | Name | `staff-avatar-name` *(reuse contact-avatar-name or create new — avatar with initials)* | `displayName` + `photoUrl` + row for click-to-drawer | 220 |
| 3 | Category | `category-badge` *(reuse from StaffCategory #43 registry)* | `categoryName` + `categoryColorHex` | 130 |
| 4 | Org Unit | `link-cell` *(simple link — new or reuse existing anchor-text renderer)* → `/[lang]/organization/structure/organizationalunit?id={orgUnitId}` | `organizationalUnitName` | 140 |
| 5 | Role / Title | `text-truncate` | `jobTitle` | 150 |
| 6 | Email | `text-truncate` | `staffEmail` | 200 |
| 7 | Phone | `text-cell` | `staffMobileNumber` | 130 |
| 8 | User Account | `user-account-cell` *(NEW — ✓ userName OR ✗ No account + [Create Account] link)* | `hasUserAccount` + `userName` | 170 |
| 9 | Status | `status-badge` *(reuse)* — show `ACTIVE/INACTIVE/ONLEAVE` with colors | `effectiveStatusCode` (computed: IsActive ? StaffStatus : "INACTIVE") | 100 |
| 10 | Actions | `row-actions` (built-in — View / Edit / More menu) | n/a | 120 |

**Row-click behavior**: click anywhere outside Actions column → open DETAIL drawer (`setCrudMode("read") + setRecordId(id) + push URL ?mode=read&id=X`).

**More menu items**:
- View Profile → `?mode=read&id=X`
- Edit → `?mode=edit&id=X`
- Manage User Account → navigate to `/[lang]/accesscontrol/usersroles/user?userId={userId}` (user management screen #72 — may be stub) OR if `!hasUserAccount`, change label to "Create User Account" and navigate similarly with intent
- Transfer → opens `<TransferStaffModal />` (new small dialog with OrgUnit + Branch selects)
- Deactivate / Activate → calls `ACTIVATE_DEACTIVATE_STAFF_MUTATION`, toast + refetch

### LAYOUT 1 — FORM (`?mode=new` or `?mode=edit&id=X`)

Full-page view with `FlowFormPageHeader` + 4 collapsible `<FormAccordionCard>`. Replace existing `StaffWizardWidget` (3 tabs) with new code.

```
<FlowFormPageHeader
  title={isEdit ? `Edit: ${displayName}` : "Add New Staff"}
  onBack={handleBack}
  onSave={handleSave}                 // wired via useStaffStore.saveFormCallback
  isSaving={isSaving}
  isDirty={isDirty}
  rightActions={isEdit ? [<MoreMenu />] : undefined}
/>

<StaffAccordionForm>      {/* <form onSubmit={...}> — React Hook Form + Zod */}
  <FormAccordionCard icon="ph:user" title="Personal Information" defaultOpen>
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
      <StaffIdField value={staffEmpId} readonly />    {/* auto-gen, readonly */}
      <div /> {/* spacer */}
      <FormInput name="firstName" label="First Name" required />
      <FormInput name="lastName"  label="Last Name"  required />
      <PhotoUploadField colSpan="full" />             {/* SERVICE_PLACEHOLDER — shows circle + "Upload photo" + constraint text */}
      <FormSelectFromMasterData typeCode="GENDER" name="gender" label="Gender" placeholder="Select..." />
      <FormDatePicker name="dateOfBirth" label="Date of Birth" />
      <FormInput name="personalEmail" label="Personal Email" type="email" />
      <FormInput name="personalPhone" label="Personal Phone" type="tel" />
    </div>
  </FormAccordionCard>

  <FormAccordionCard icon="ph:briefcase" title="Employment Details" defaultOpen>
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
      <FormSearchableSelect
        name="organizationalUnitId"
        label="Org Unit" required
        query={ORGANIZATIONAL_UNITS_QUERY}
        valueField="organizationalUnitId" labelField="unitName"
      />
      <FormSearchableSelect
        name="staffCategoryId"
        label="Staff Category" required
        query={STAFFCATEGORIES_QUERY}
        valueField="staffCategoryId" labelField="staffCategoryName"
      />
      <FormInput name="jobTitle" label="Role / Job Title" placeholder="e.g. Program Coordinator" required />
      <FormSelectFromMasterData typeCode="STAFFEMPLOYMENTTYPE" name="employmentType" label="Employment Type" />
      <FormDatePicker name="joinDate" label="Join Date" required />
      <FormDatePicker name="endDate" label="End Date" />
      <FormSearchableSelect
        name="reportingToStaffId"
        label="Reporting To"
        query={STAFFS_QUERY} variables={{ excludeStaffId: recordId }}
        valueField="staffId" labelField="displayName"
      />
      <FormSelectFromMasterData typeCode="STAFFSTATUS" name="staffStatus" label="Status" />
      <FormInput name="staffEmail" label="Work Email" type="email" placeholder="name@org.com" required />
      <FormInput name="staffMobileNumber" label="Work Phone" type="tel" />
    </div>
  </FormAccordionCard>

  <FormAccordionCard icon="ph:user-circle-gear" title="System Access" defaultOpen>
    <div className="space-y-3">
      {/* Conditional UI depending on (a) edit with existing user, (b) create with link, (c) create with new user */}
      {isEdit && hasUserAccount ? (
        <LinkedAccountDisplay userName={userName} roleName={roleName} onUnlink={...} />
      ) : (
        <>
          <FormSearchableSelect
            name="userId"
            label="Link to User Account"
            query={UNASSIGNED_USERS_QUERY}    {/* NEW — users with no staff record */}
            valueField="userId" labelField="userName"
            placeholder="Select existing user account..."
          />
          <div className="text-center text-xs text-muted-foreground">Or</div>
          <Button variant="outline" onClick={toggleNewUserSubForm}>
            <Icon icon="ph:user-plus" className="mr-2" /> Create New User Account
          </Button>
          {showNewUserSubForm && (
            <div className="bg-muted/50 rounded-md border p-4 grid grid-cols-1 md:grid-cols-2 gap-4">
              <FormInput name="newUser.username" label="Username" placeholder="e.g. f.hassan" />
              <FormSearchableSelect
                name="newUser.roleId" label="Role Assignment"
                query={ROLES_QUERY}
                valueField="roleId" labelField="roleName"
              />
              <FormInput name="newUser.password" label="Password" type="password" />
              <FormSwitch name="newUser.sendWelcomeEmail" label="Send welcome email" defaultChecked />
            </div>
          )}
        </>
      )}
      <InfoBox icon="ph:info">
        A user account gives this staff member access to PSS 2.0. The role determines what they can see and do.
      </InfoBox>
    </div>
  </FormAccordionCard>

  <FormAccordionCard icon="ph:info" title="Additional Information">
    <div className="grid grid-cols-1 gap-4">
      <TagsField name="skills" label="Skills / Expertise" placeholder="Add skill..." />
      <TagsField name="languages" label="Languages" placeholder="Add language..." />
      <div>
        <Label>Emergency Contact</Label>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <FormInput name="emergencyContactName" placeholder="Name" />
          <FormInput name="emergencyContactPhone" placeholder="Phone" />
          <FormInput name="emergencyContactRelationship" placeholder="Relationship" />
        </div>
      </div>
      <FormTextarea name="notes" label="Notes" rows={3} placeholder="Additional notes..." />
    </div>
  </FormAccordionCard>
</StaffAccordionForm>
```

**`FormAccordionCard`**: A shared component (check existing before creating — `Accordion` primitives exist in shadcn, but a "card with collapsible body + icon header" may be new). If not in registry, create a small local component.

**`TagsField`**: reuse existing tag-input if present (check `components/ui/tags-input`); otherwise create small local component (CSV backing). Mockup uses native-looking chips with `×` remove button.

**`FormSelectFromMasterData`**: existing component wrapping `masterDatas` query with `advancedFilter: typeCode = X`. Confirm it exists; if not, create small wrapper.

### LAYOUT 2 — DETAIL (`?mode=read&id=X`)

**Right-side drawer, 520px**, using existing `<Sheet>` primitive (shadcn) — NOT a full-page route.

- Rendered inside the INDEX page layout (grid stays visible behind a 20% black overlay).
- Triggered by row-click or More-menu "View Profile".
- URL syncs: `push(pathname + '?mode=read&id=X')` on open, `push(pathname)` on close.
- On "Edit" button inside drawer → `push(pathname + '?mode=edit&id=X')` + close drawer.
- On drawer close (X button or overlay click or ESC) → navigate back to `?` (no mode).

Drawer structure (per mockup lines 1570-1679):

```
<Sheet open={isDetailOpen} onOpenChange={handleClose}>
  <SheetContent side="right" className="w-[520px] sm:max-w-[520px] p-0">
    <SheetHeader className="p-6 border-b flex flex-row items-center justify-between">
      <SheetTitle>Staff Profile</SheetTitle>
      <div className="flex gap-2">
        <Button variant="outline" size="sm" onClick={() => switchToEdit()}>
          <Icon icon="ph:pencil" className="mr-1" /> Edit
        </Button>
        <SheetClose asChild><Button variant="ghost" size="icon"><Icon icon="ph:x" /></Button></SheetClose>
      </div>
    </SheetHeader>

    <div className="p-6 overflow-y-auto space-y-6">
      {/* Profile Header */}
      <div className="flex items-center gap-4">
        <StaffAvatar size="lg" name={displayName} photoUrl={photoUrl} />
        <div>
          <h3 className="text-lg font-semibold">{displayName}</h3>
          <p className="text-sm text-muted-foreground">{jobTitle} · {branchName}</p>
          <div className="mt-1 flex gap-1">
            <StatusBadge code={effectiveStatusCode} />
            <CategoryBadge name={categoryName} colorHex={categoryColorHex} />
          </div>
        </div>
      </div>

      {/* Employment Details — 2-col grid */}
      <DetailSection title="Employment Details">
        <DetailGrid columns={2}>
          <DetailItem label="Staff ID" value={staffEmpId} />
          <DetailItem label="Employment Type" value={employmentTypeLabel} />
          <DetailItem label="Join Date" value={formatDate(joinDate)} />
          <DetailItem label="Reporting To" value={reportingToName} />
          <DetailItem label="Work Email" value={staffEmail} />
          <DetailItem label="Work Phone" value={staffMobileNumber} />
          <DetailItem label="User Account" value={hasUserAccount ? `✓ ${userName}` : "No account"} color={hasUserAccount ? "success" : "muted"} />
          <DetailItem label="Last Login" value={lastLogin ?? "—"} />
        </DetailGrid>
      </DetailSection>

      {/* Activity Summary — 4-stat grid (Query: GetStaffActivitySummary) */}
      <DetailSection title="Activity Summary">
        <ActivityStats
          stats={[
            { value: donationsYtd, label: "Donations processed (YTD)" },
            { value: collections,  label: "Collections made" },
            { value: eventsManaged, label: "Events managed" },                          {/* SERVICE_PLACEHOLDER */}
            { value: formatShortDate(lastLogin), label: `Last login${lastLoginTime ? ` (${lastLoginTime})` : ""}` },
          ]}
        />
      </DetailSection>

      {/* Branch History — placeholder timeline */}
      <DetailSection title="Branch History">
        <BranchHistoryList entries={branchHistory /* currently mocked/empty per ISSUE-7 */} />
      </DetailSection>
    </div>
  </SheetContent>
</Sheet>
```

All detail data fetched via `STAFF_BY_ID_QUERY` (extended) + lazily `GET_STAFF_ACTIVITY_SUMMARY_QUERY`.

### Empty / loading / error states

- Grid empty: reuse `<EmptyState icon="ph:users" title="No staff yet" description="Click Add Staff to onboard your first staff member." />`.
- Grid loading: shaped skeleton rows (existing FlowDataTable pattern).
- Widget loading: skeletons inside card.
- Drawer loading: skeleton inside each section.
- Form submit error: toast + field-level messages via React Hook Form.

### Responsive

- ≥ `lg`: 4-col KPI, 2-col form, 2-col detail grid.
- `md`: 2-col KPI, 2-col form, 2-col detail grid.
- `sm`: 1-col everywhere; drawer becomes full-screen sheet (`sm:max-w-[520px]` naturally collapses).
- Tags-field wraps freely.

### Layout Variant Stamp

**Grid layout variant**: `widgets-above-grid` → **Variant B mandatory** (ScreenHeader lifted to page root + `FlowDataTableStoreProvider` wrapping + `<DataTableContainer showHeader={false} />`).

### Service placeholders (section ⑥ UI → handler behavior)

| UI element | Behavior | ISSUE# |
|------------|----------|--------|
| Photo upload | Shows camera circle + "Upload photo" link → `toast.info("Photo upload pending infra")` | ISSUE-3 |
| Import Staff button | Toast "Import pending" | ISSUE-4 |
| Manage User Account link | Navigates to `/[lang]/accesscontrol/usersroles/user` (#72 screen may be stub) | ISSUE-5 |
| Transfer action | Opens small modal → calls `TransferStaffCommand` (new). Branch history: NOT recorded in separate table yet. | ISSUE-6 |
| Branch History section (drawer) | Static placeholder list until audit trail BE table added | ISSUE-7 |
| Activity Summary: Events managed | `0` until Event.OwnerStaffId FK added | ISSUE-8 |
| Activity Summary: Last login | `—` if User.LastLoginDate not present on entity | ISSUE-9 |
| Send welcome email toggle | Wired to `newUser.sendWelcomeEmail` flag; BE CreateUserCommand currently ignores — flag is persisted for future pipeline | ISSUE-10 |
| Unlink user (edit mode) | SERVICE_PLACEHOLDER — requires UserId → nullable migration; disabled with tooltip | ISSUE-11 |

---

## ⑦ Substitution Guide

Canonical reference: `recurringdonationschedule.md` (FLOW w/ drawer detail) + `staffcategory.md` (Organization-module conventions).

| Canonical (in reference prompts) | This screen (Staff) |
|----------------------------------|---------------------|
| `RecurringDonationSchedule` | `Staff` |
| `recurringdonationschedule` | `staff` |
| `RECURRINGDONORS` (feFolder) | `staff` (feFolder — `organization/staff/staff/*`) |
| `RECURRINGDONOR` (MenuCode) | `STAFFS` (MenuCode — plural) |
| `CRM_DONATION` (ParentMenu) | `STAFF` (ParentMenu — parent group `ORG_STAFF`) |
| `CRM` (Module) | `ORGANIZATION` (Module) |
| `crm/donation/recurringdonors` | `organization/staff/staff` |
| `fund` schema | `app` schema |
| `DonationModels` | `ApplicationModels` |
| `DonationBusiness` | `ApplicationBusiness` |
| `DonationSchemas` | `ApplicationSchemas` |
| `Mutations/Donation` + `Queries/Donation` | `Mutations/Application` + `Queries/Application` |
| `IDonationDbContext` | `IApplicationDbContext` (entity on root interface; `DbSet<Staff> Staffs` already registered) |
| `DecoratorDonationModules` | `DecoratorApplicationModules` (already has `.Staff = "STAFF"`) |
| `NotifyMappings` / `DonationMappings` | `ApplicationMappings` (already has 3 Staff Mapster configs — see §⑫ ISSUE-2) |
| `fe-folder = recurringdonors` | `fe-folder = staff` (under `[lang]/organization/staff/staff/`) |
| `donation-service` | `application-service` (DTO + entity-operations folder name) |

Camel/Pascal variants:
- `staffs` (GraphQL field name — plural, confirmed in existing endpoint)
- `Staff` (Pascal entity)
- `staff` (camel var)
- `STAFFS` (MenuCode + GridCode)
- `STAFF` (ParentMenu code)

---

## ⑧ File Manifest

### Backend — modify

| Path | Action | Notes |
|------|--------|-------|
| `Base.Domain/Models/ApplicationModels/Staff.cs` | MODIFY | Add 20 new columns (§②). Keep existing 8 fields + nav + inverse collections. Add `virtual Staff? ReportingTo { get; set; }` + `ICollection<Staff>? Reports` self-nav. Add `virtual OrganizationalUnit? OrganizationalUnit { get; set; }`. |
| `Base.Application/Schemas/ApplicationSchemas/StaffSchemas.cs` | MODIFY | `StaffRequestDto` += 20 new fields + `NewUser` child DTO (username/roleId/password/sendWelcomeEmail). `StaffResponseDto` += projected fields (categoryName/categoryColorHex/organizationalUnitName/branchName/reportingToName/hasUserAccount/userName/userProfilePathUrl/displayName/effectiveStatusCode/employmentTypeLabel). NEW `StaffSummaryDto { totalCount, activeCount, inactiveCount, categoryCount, categoryBreakdown, totalBranches, branchesWithStaff, staffWithUser }`. NEW `StaffActivitySummaryDto { donationsYtd, collections, events, lastLogin }`. |
| `Base.Application/Business/ApplicationBusiness/Staffs/Commands/CreateStaff.cs` | MODIFY | (a) auto-gen `StaffEmpId = "STF-{seq:D4}"` (next seq = count+1 where CompanyId matches); (b) validate + persist 20 new columns; (c) handle two branches: existing User link vs new User create; (d) compute `DisplayName`; (e) set default `StaffStatus = "ACTIVE"` and `IsActive = true` when not provided. |
| `Base.Application/Business/ApplicationBusiness/Staffs/Commands/UpdateStaff.cs` | MODIFY | Handler currently doesn't persist `StaffEmpId` change — keep as readonly after create. Extend to update all 20 new columns + recompute `DisplayName`. Validate reporting-to cycle. |
| `Base.Application/Business/ApplicationBusiness/Staffs/Queries/GetStaffs.cs` | MODIFY | Include StaffCategory, OrganizationalUnit, Branch, User, ReportingTo. Apply CompanyId scope. Extend search (firstName/lastName/displayName/jobTitle/personalEmail/unitName). Add top-level filter args: `categoryId`, `organizationalUnitId`, `branchId`, `staffStatus`, `hasUserAccount`. Project `StaffResponseDto` with computed fields. |
| `Base.Application/Business/ApplicationBusiness/Staffs/Queries/GetStaffById.cs` | MODIFY | Include: StaffCategory, OrganizationalUnit, Branch, User, ReportingTo. Return full `StaffResponseDto`. |
| `Base.API/EndPoints/Application/Queries/StaffQueries.cs` | MODIFY | Register new: `staffSummary` → GetStaffSummaryQuery; `staffActivitySummary(staffId)` → GetStaffActivitySummaryQuery. Extend `staffs` signature with new filter args. |
| `Base.API/EndPoints/Application/Mutations/StaffMutations.cs` | MODIFY | Register new: `transferStaff` → TransferStaffCommand. |
| `Base.Application/Mappings/ApplicationMappings.cs` | MODIFY | (a) Fix copy-paste error (§⑫ ISSUE-2). Add explicit Mapster configs: `Staff → StaffResponseDto` with `.Map(d => d.CategoryName, s => s.StaffCategory.StaffCategoryName)`, `.Map(d => d.CategoryColorHex, s => s.StaffCategory.ColorHex)`, `.Map(d => d.OrganizationalUnitName, s => s.OrganizationalUnit.UnitName)`, `.Map(d => d.BranchName, s => s.Branch.BranchName)`, `.Map(d => d.ReportingToName, s => s.ReportingTo.DisplayName)`, `.Map(d => d.UserName, s => s.User.UserName)`, `.Map(d => d.HasUserAccount, s => s.UserId > 0)`, `.Map(d => d.EffectiveStatusCode, s => s.IsActive ? (s.StaffStatus ?? "ACTIVE") : "INACTIVE")`. |

### Backend — create

| Path | Notes |
|------|-------|
| `Base.Application/Business/ApplicationBusiness/Staffs/Queries/GetStaffSummary.cs` | Handler returns 4-card payload. Uses `CompanyScope`. |
| `Base.Application/Business/ApplicationBusiness/Staffs/Queries/GetStaffActivitySummary.cs` | Handler: count GlobalDonations, GlobalReceiptDonationCollectors, Events (SERVICE_PLACEHOLDER=0), User.LastLogin. |
| `Base.Application/Business/ApplicationBusiness/Staffs/Commands/TransferStaff.cs` | `TransferStaffCommand { StaffId, OrganizationalUnitId?, BranchId? }` → update both FKs + touch `ModifiedDate`. Requires `Permissions.Modify`. No audit-history table. |
| `Base.Application/Business/ApplicationBusiness/Staffs/Commands/UnlinkStaffUser.cs` | STUB — returns 501 or accepts the call but no-ops until `Staff.UserId` becomes nullable. Keep for API completeness. (OPTIONAL — can defer entirely; ISSUE-11.) |
| `Base.Application/Business/ApplicationBusiness/Staffs/Queries/GetUnassignedUsers.cs` *(optional)* | Returns `IEnumerable<UserResponseDto>` where UserId not in Staffs. Used by "Link to User Account" dropdown. Alternative: extend existing `users` query with `excludeAssignedStaff: bool` filter arg. **Prefer extending existing `users` query to avoid new endpoint.** |
| `PSS_2.0_Backend/.../Migrations/{yyyyMMddHHmmss}_ExpandStaffEntity.cs` | EF migration adding 20 new columns + 2 new FKs (OrganizationalUnitId, ReportingToStaffId) + unique filtered indexes per Company on (StaffEmpId, StaffEmail, StaffMobileNumber) — relax existing global unique if any. Backfill: `FirstName = SUBSTRING(StaffName, 1, POSITION(' ' IN StaffName))`, `LastName = SUBSTRING(StaffName, POSITION(' ' IN StaffName)+1)`, `StaffStatus = IsActive ? 'ACTIVE' : 'INACTIVE'`, `DisplayName = StaffName`. |

### Backend — optionally modify for cross-entity support

| Path | Action | Reason |
|------|--------|--------|
| `Base.API/EndPoints/Auth/Queries/UserQueries.cs` | MODIFY | Add optional `excludeAssignedStaff: Boolean` filter arg to `users` query (when true, filter `u.Staff == null`). Keeps Staff form's "Link to User Account" dropdown clean. |

### Frontend — modify

| Path | Action |
|------|--------|
| `src/domain/entities/application-service/StaffDto.ts` | MODIFY — extend all three DTOs with 20 new fields + projected fields. Add `StaffSummaryDto`, `StaffActivitySummaryDto`, `NewUserSubFormDto`, `TransferStaffDto`. |
| `src/infrastructure/gql-queries/application-queries/StaffQuery.ts` | MODIFY — extend `STAFFS_QUERY` projection (+ projected fields + filter vars), extend `STAFF_BY_ID_QUERY`, add `GET_STAFF_SUMMARY_QUERY`, add `GET_STAFF_ACTIVITY_SUMMARY_QUERY`. |
| `src/infrastructure/gql-mutations/application-mutations/StaffMutation.ts` | MODIFY — update `CREATE_STAFF_MUTATION` + `UPDATE_STAFF_MUTATION` arg lists, add `TRANSFER_STAFF_MUTATION`. |
| `src/application/configs/data-table-configs/application-service-entity-operations.ts` | (no change — STAFF entry already registered; verify `gridCode` = `"STAFFS"` to match MODULE_MENU_REFERENCE MenuCode; rename if needed from `STAFF` → `STAFFS`). ⚠ Current value is `"STAFF"`; MenuCode seed is `"STAFFS"` — keep both and alias, OR update code `STAFF` → `STAFFS`. See ISSUE-12. |
| `src/application/stores/hrms-stores/staff-store.ts` | MODIFY — extend with `detailDrawerOpen`, `detailStaffId`, `advancedFilters`, `newUserSubFormOpen`, drop wizard-tab-specific fields (still keep `saveFormCallback`, `isDirty`, `resetStore`). |
| `src/presentation/components/page-components/organization/staff/staff-components/staff-wizard/index.tsx` | MODIFY — becomes a thin router between FORM mode (view-page) and INDEX mode (index-page). Keep provider wrapping. |
| `src/presentation/components/page-components/organization/staff/staff-components/staff-wizard/index-page.tsx` | REWRITE — Variant B (ScreenHeader + widgets + advanced-filter-panel + FlowDataTableContainer showHeader=false). |
| `src/presentation/components/page-components/organization/staff/staff-components/staff-wizard/view-page.tsx` | REWRITE — replace StaffWizardProvider/StaffWizardWidget body with new `<StaffAccordionForm>` for new/edit and delegate `?mode=read` to drawer-open on INDEX (view-page only renders for new/edit; when mode=read, router sends user back to index with drawer open). |
| `src/presentation/pages/organization/staff/staff.tsx` | (no change if wrapper stays). Verify `useAccessCapability({ menuCode: "STAFFS" })` — rename from `"STAFF"` if needed to match seed. |

### Frontend — create

| Path | Notes |
|------|-------|
| `src/presentation/components/page-components/organization/staff/staff-components/staff-widgets.tsx` | 4 KPI cards driven by `GET_STAFF_SUMMARY_QUERY`. |
| `src/presentation/components/page-components/organization/staff/staff-components/staff-advanced-filter-panel.tsx` | Collapsible 5-col bar (Category/OrgUnit/Status/UserAccount selects + Clear button). |
| `src/presentation/components/page-components/organization/staff/staff-components/staff-detail-drawer.tsx` | 520px `<Sheet>` with profile header + Employment Details 2-col grid + Activity Summary 4-stat strip + Branch History list. Uses `STAFF_BY_ID_QUERY` + `GET_STAFF_ACTIVITY_SUMMARY_QUERY`. |
| `src/presentation/components/page-components/organization/staff/staff-components/staff-accordion-form.tsx` | 4 `<FormAccordionCard>` sections (per §⑥). React Hook Form + Zod. Reuses `FormInput`, `FormSearchableSelect`, `FormDatePicker`, new `FormSelectFromMasterData` if missing. Wires `saveFormCallback`. |
| `src/presentation/components/page-components/organization/staff/staff-components/transfer-staff-modal.tsx` | Small dialog — OrgUnit + Branch selects + Save. Calls `TRANSFER_STAFF_MUTATION`. |
| `src/presentation/components/page-components/organization/staff/staff-components/staff-avatar.tsx` | Reusable — shows user avatar with initials fallback; accepts `size: "sm"\|"md"\|"lg"`, `name`, `photoUrl`. |
| `src/presentation/components/page-components/organization/staff/staff-components/detail-primitives.tsx` | Small locals: `DetailSection`, `DetailGrid`, `DetailItem`, `ActivityStats`, `BranchHistoryList`, `LinkedAccountDisplay`, `InfoBox`. (Or spread inline in detail-drawer — one file with sub-components.) |
| `src/presentation/components/page-components/shared/form-accordion-card.tsx` *(optional — if no existing)* | Wraps `<Accordion>` primitive into card with icon header. First consumer: Staff. |
| `src/presentation/components/page-components/shared/form-select-from-masterdata.tsx` *(optional — if no existing)* | Wraps `FormSearchableSelect` + `MASTERDATAS_QUERY` + `advancedFilter: typeCode = X`. Register in shared. |
| `src/presentation/components/page-components/shared/tags-field.tsx` *(optional — if no existing)* | CSV-backed tag input with chips + `×`. |
| `src/presentation/components/data-table-components/renderers/staff-id-chip.tsx` | Mono chip — new renderer. Register in all 3 column-type registries (`advanced`, `basic`, `flow`) + `shared-cell-renderers` barrel. |
| `src/presentation/components/data-table-components/renderers/staff-avatar-name-cell.tsx` | Avatar + name link → opens drawer. Register in all 3 registries. (Similar to `contact-avatar-name` from Contact #18 — prefer reuse if applicable.) |
| `src/presentation/components/data-table-components/renderers/user-account-cell.tsx` | Conditional ✓ username OR ✗ No account + `[Create Account]` link renderer. Register in all 3 registries. |
| `src/presentation/components/data-table-components/renderers/link-cell.tsx` *(if not already exists)* | Simple anchor-text renderer — takes `linkTemplate`, opens target route. Used for Org Unit column. Register in all 3 registries. |

### Frontend — delete

| Path | Reason |
|------|--------|
| `.../staff/staff-components/data-table.tsx` | Old `StaffDataTable` (AdvancedDataTable-based) — superseded by FlowDataTable in index-page. |
| `.../staff/staff-components/staff-edit-form/` (entire folder) | Old accordion form — superseded by new accordion form in staff-wizard. |
| `.../staff/staff-components/staff-wizard/staff-wizard-context.tsx` | Wizard context no longer needed (no tabs). If Company Config tab preserved (per ISSUE-13), keep a minimal context. Prefer delete. |
| `.../staff/staff-components/staff-wizard/staff-wizard-widget.tsx` | 3-tab widget — replaced by accordion form. |
| `.../staff/staff-components/staff-wizard/staff-profile-tab.tsx` | Profile tab replaced by drawer header. |
| `.../staff/staff-components/staff-wizard/staff-parent-form.tsx` | Old Basic Info tab form — replaced by new accordion form. |
| `.../staff/staff-components/staff-wizard/staff-category-tab.tsx` | Redundant with category field in form. |

### Frontend — preserve (deferred alignment — ISSUE-13)

| Path | Reason |
|------|--------|
| `.../staff/staff-components/staff-wizard/staff-company-config-tab.tsx` | Multi-company role-assignment UI — NOT in mockup. KEEP and expose only via a secondary "Company Configuration" link inside the detail drawer's "More" menu (visible in edit mode when `isEdit && companyMultiTenant`). Full alignment deferred. |
| `.../staff/staff-components/staff-wizard/staff-role-access-viewer.tsx` | Support component for staff-company-config-tab — keep. |
| `.../staff/staff-components/staff-wizard/staff-profile-photo*.ts(x)` | Photo upload helpers — keep as SERVICE_PLACEHOLDER wiring when backend upload pipeline lands (ISSUE-3). |
| `src/domain/entities/application-service/StaffCompanyDto.ts` + related queries/mutations | Keep — used by Company Configuration tab. |

### DB seed

| Path | Notes |
|------|-------|
| `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/Staff-sqlscripts.sql` | NEW file. Menu upsert (`STAFFS`, OrderBy=1 under `STAFF` parent) + capabilities + BUSINESSADMIN/SUPERADMIN/ADMINISTRATOR grants + Grid FLOW row (gridCode=`STAFFS`) + 10 Fields rows + 10 GridFields rows (GridFormSchema=NULL per FLOW). **MasterData seeds**: TypeCode `GENDER` (4 rows: Male/Female/Other/PreferNotToSay), TypeCode `STAFFEMPLOYMENTTYPE` (5 rows: FULLTIME/PARTTIME/CONTRACT/VOLUNTEER/INTERN), TypeCode `STAFFSTATUS` (3 rows: ACTIVE/INACTIVE/ONLEAVE with ColorHex in DataSetting: green/red/amber). No sample Staff rows (avoid tenant data pollution). All upserts idempotent via `ON CONFLICT` / existence-guard. |

---

## ⑨ Approval Config

```yaml
MenuName: Staffs
MenuCode: STAFFS
ParentMenu: STAFF           # parent group is ORG_STAFF (MenuId 363) — but parent MENU CODE ref for seed is "STAFF"
Module: ORGANIZATION
MenuUrl: organization/staff/staff
OrderBy: 1                  # per MODULE_MENU_REFERENCE (StaffCategory is OrderBy=2)
GridType: FLOW
GridFormSchema: SKIP        # FLOW → code-driven form, no dynamic schema
Capabilities: [Create, Read, Modify, Delete, Toggle, Export, Print]
RoleGrants:
  - BUSINESSADMIN: all capabilities
  # Per build-directives: seed only BUSINESSADMIN (other roles default-denied; granted manually at customer onboarding)
```

**Seed idempotence**: use `WHERE NOT EXISTS` / `ON CONFLICT DO UPDATE` pattern (established in StaffCategory-sqlscripts.sql precedent).

**Renderer registry entries** (seed GridField `GridComponentName` values must match FE registrations):
- `staff-id-chip`, `staff-avatar-name`, `category-badge`, `link-cell`, `text-truncate`, `text-cell`, `user-account-cell`, `status-badge`, `row-actions`

---

## ⑩ BE→FE Contract

### GraphQL query/mutation names

| Name | Kind | Args | Return |
|------|------|------|--------|
| `staffs` | Query | `request: GridFeatureRequest`, `categoryId: Int?`, `organizationalUnitId: Int?`, `branchId: Int?`, `staffStatus: String?`, `hasUserAccount: Boolean?` | `PagedList<StaffResponseDto>` |
| `staffById` | Query | `staffId: Int!` | `IEnumerable<StaffResponseDto>` (take 1) |
| `staffByUserId` | Query | `(none — uses HTTP context)` | `StaffResponseDto?` |
| `staffSummary` | Query | (none) | `StaffSummaryDto` |
| `staffActivitySummary` | Query | `staffId: Int!` | `StaffActivitySummaryDto` |
| `createStaff` | Mutation | `staff: StaffRequestDto!`, `newUser: NewUserSubFormDto?` | `StaffResponseDto` |
| `updateStaff` | Mutation | `staff: StaffRequestDto!` | `StaffResponseDto` |
| `deleteStaff` | Mutation | `staffId: Int!` | `Boolean` |
| `activateDeactivateStaff` | Mutation | `staffId: Int!` | `Boolean` |
| `transferStaff` | Mutation | `staffId: Int!`, `organizationalUnitId: Int?`, `branchId: Int?` | `Boolean` |

### DTO field list (for FE TS — PascalCase → camelCase conversion per existing convention)

**`StaffResponseDto`** (all camelCase on FE):
```ts
interface StaffResponseDto {
  staffId: number;
  staffEmpId: string;           // STF-{NNNN}
  firstName: string;
  lastName: string;
  displayName: string;          // computed
  staffName: string;            // legacy (= displayName)
  gender?: string | null;
  dateOfBirth?: string | null;  // ISO date
  photoUrl?: string | null;
  personalEmail?: string | null;
  personalPhone?: string | null;
  staffCategoryId: number;
  staffEmail: string;           // work email
  staffMobileNumber: string;    // work phone
  organizationalUnitId?: number | null;
  jobTitle?: string | null;
  employmentType?: string | null;   // code: FULLTIME/PARTTIME/CONTRACT/VOLUNTEER/INTERN
  joinDate?: string | null;         // ISO
  endDate?: string | null;
  reportingToStaffId?: number | null;
  staffStatus?: string | null;      // code: ACTIVE/INACTIVE/ONLEAVE
  branchId?: number | null;
  userId: number;                   // 0 = no account (until nullable migration)
  companyId?: number | null;
  emergencyContactName?: string | null;
  emergencyContactPhone?: string | null;
  emergencyContactRelationship?: string | null;
  skills?: string | null;           // CSV
  languages?: string | null;        // CSV
  notes?: string | null;
  isActive: boolean;
  isDeleted: boolean;
  createdDate: string;
  createdBy?: string | null;
  modifiedDate?: string | null;
  modifiedBy?: string | null;
  // Projected (computed)
  categoryName: string;
  categoryCode?: string | null;
  categoryColorHex?: string | null;
  organizationalUnitName?: string | null;
  organizationalUnitCode?: string | null;
  branchName?: string | null;
  reportingToName?: string | null;
  userName?: string | null;
  userProfilePathUrl?: string | null;
  hasUserAccount: boolean;
  lastLogin?: string | null;
  employmentTypeLabel?: string | null;
  effectiveStatusCode: string;      // ACTIVE/INACTIVE/ONLEAVE (post IsActive override)
}
```

**`StaffSummaryDto`**:
```ts
interface StaffSummaryDto {
  totalCount: number;
  activeCount: number;
  inactiveCount: number;
  categoryCount: number;
  categoryBreakdown: Array<{ categoryCode: string; categoryName: string; count: number }>;
  totalBranches: number;
  branchesWithStaff: number;
  staffWithUser: number;
}
```

**`StaffActivitySummaryDto`**:
```ts
interface StaffActivitySummaryDto {
  donationsYtd: number;
  collections: number;
  events: number;                // SERVICE_PLACEHOLDER → always 0 until Event.OwnerStaffId lands
  lastLogin?: string | null;
}
```

**`NewUserSubFormDto`** (passed alongside CreateStaff when creating new user):
```ts
interface NewUserSubFormDto {
  username: string;
  roleId: number;
  password: string;
  sendWelcomeEmail: boolean;    // SERVICE_PLACEHOLDER
}
```

### GQL request variables pattern (FE sends)

For the list grid:
```ts
variables: {
  request: { /* GridFeatureRequest */ },
  categoryId: filterChip === "category" ? selectedCategoryId : null,
  organizationalUnitId: ...,
  branchId: ...,
  staffStatus: ...,
  hasUserAccount: ...,
}
```

---

## ⑪ Acceptance Criteria

### Functional

**INDEX (grid) — Variant B**:
- [ ] Page header shows "Staff Management" + subtitle + Add Staff / Import Staff / Export buttons.
- [ ] 4 KPI widgets render above grid with correct counts from `staffSummary`.
- [ ] Advanced filter panel collapses/expands; 4 selects (Category/OrgUnit/Status/UserAccount) + Clear button work; changes invoke `staffs` query with correct top-level args.
- [ ] Grid shows 10 columns in specified order with correct renderers.
- [ ] Row-click (outside Actions cell) opens DETAIL drawer at `?mode=read&id=X`.
- [ ] Row actions: View / Edit / More → each navigates/acts as spec.
- [ ] "Add Staff" → `?mode=new` → renders FORM LAYOUT.
- [ ] Import button → toast "Import pending" (SERVICE_PLACEHOLDER).
- [ ] Export button → downloads Excel via existing `ExportStaff`.

**FORM (mode=new | mode=edit) — full-page 4-accordion**:
- [ ] 4 sections render with correct icons, titles, default-open state.
- [ ] All fields map to DTO per §⑥.
- [ ] `Staff ID` auto-displays `STF-{next}` on create, readonly.
- [ ] Required fields (FirstName, LastName, OrgUnit, Category, JobTitle, JoinDate, WorkEmail) enforce Zod + BE validator.
- [ ] Reporting-To dropdown excludes self in edit mode.
- [ ] System Access section:
  - In create mode: offers Link existing user OR Create new user sub-form (collapsible).
  - In edit mode (with user account): shows "✓ {userName} (Role: {roleName}) [Unlink]" — Unlink button shows tooltip "Unlink pending" (SERVICE_PLACEHOLDER ISSUE-11).
  - In edit mode (no user account): shows same create-or-link UI.
- [ ] Skills + Languages tags input: add chip on Enter, remove on `×`, persist as CSV.
- [ ] Emergency Contact: 3-field row (name/phone/relationship) all optional.
- [ ] Footer buttons: Cancel (back to grid), Save & Add Another, Save. "Save & Add Another" resets form and keeps form open.
- [ ] Unsaved-changes dialog on Back/Cancel with dirty state.

**DETAIL (mode=read) — right drawer 520px**:
- [ ] Drawer opens from URL or row-click; shows correct staff.
- [ ] Profile header: avatar, displayName, jobTitle · branchName, Status + Category badges.
- [ ] Employment Details 2-col grid: 8 items per mockup (Staff ID / Employment Type / Join Date / Reporting To / Work Email / Work Phone / User Account / Last Login).
- [ ] Activity Summary 4-stat strip — counts from `staffActivitySummary` (events → 0 SERVICE_PLACEHOLDER).
- [ ] Branch History — renders stub items (SERVICE_PLACEHOLDER ISSUE-7).
- [ ] Edit button → switches to `?mode=edit&id=X`.
- [ ] Close via X / overlay / ESC navigates back to plain `?`.

**Transfer modal**:
- [ ] More menu "Transfer" opens modal.
- [ ] Submit invokes `transferStaff` mutation + refetches grid + closes + shows toast.

**Deactivate/Activate**:
- [ ] More menu toggle via `activateDeactivateStaff`, refetch, toast.

### Non-functional

- [ ] Variant B verified: page root wraps `AdvancedDataTableStoreProvider` + `FlowDataTableStoreProvider`; `<DataTableContainer showHeader={false} />`; `<ScreenHeader>` lifted to root.
- [ ] 5 UI-uniformity grep checks pass (0 matches each):
  - `className=".*text-\[#`
  - `className=".*bg-\[#`
  - `style={{` containing `color:` or `background`
  - `className=".*p-[0-9]+px`
  - `className=".*gap-[0-9]+px`
  Colors flow via tokens or role-data (`ColorHex` on `StaffCategory` / `STAFFSTATUS` MasterData → still allowed as DATA-driven badge colors).
- [ ] All @iconify Phosphor icons.
- [ ] Shaped skeletons on loading (widgets, grid rows, drawer sections).
- [ ] Empty state on zero staff.
- [ ] Mobile: drawer becomes full-screen sheet; accordions stack 1-col; grid horizontal scrolls.
- [ ] `dotnet build` in `Base.Application` + `Base.API` returns **0 errors**.
- [ ] `pnpm tsc --noEmit` returns **0 new errors** in touched files.
- [ ] EF migration applies cleanly + backfill runs (existing rows get split `StaffName` → `FirstName`/`LastName`, `StaffStatus = 'ACTIVE'` if `IsActive`).
- [ ] Seed SQL is idempotent — running twice doesn't duplicate.

---

## ⑫ Special Notes

### Pre-flagged ISSUEs

- **ISSUE-1 (HIGH — BE schema drift)** — Existing `Staff.UserId` is non-nullable `int`. Mockup + spec implies "no account yet" is valid state. Option A (chosen for MVP): treat `UserId == 0` as "no account" via `HasUserAccount` projected computed. Option B (future): migrate to `UserId int?` + drop cascade; deferred to future migration when Unlink feature lands (ISSUE-11).

- **ISSUE-2 (MED — BE Mapster copy-paste)** — `ApplicationMappings.cs` currently has `TypeAdapterConfig<Staff, StaffCategoryResponseDto>.NewConfig()` which looks wrong (should be `StaffResponseDto`). Needs explicit mapping for `Staff → StaffResponseDto` with all projected fields (§⑧ modify row).

- **ISSUE-3 (MED — SERVICE_PLACEHOLDER)** — Photo upload has no server pipeline. Keep UI (circle + "Upload photo"); wire to `toast.info("Photo upload pending")`. Existing `staff-profile-photo*.ts(x)` helpers may be preserved for future use.

- **ISSUE-4 (MED — SERVICE_PLACEHOLDER)** — Import Staff feature deferred; button toasts.

- **ISSUE-5 (MED — cross-screen)** — "Manage User Account" link assumes User Management screen #72 exists. Current #72 is marked `PARTIAL — BE User entity exists, NO dedicated FE management screen`. Link may land on a 404/stub. Keep link; document as follow-up.

- **ISSUE-6 (MED — data-model gap)** — No `StaffBranchHistory` audit table exists. Transfer command updates `BranchId`/`OrganizationalUnitId` in place; Branch History section in drawer shows a derived placeholder list (empty or single entry based on current state). Future work: add `StaffBranchHistory` entity with `StaffId, BranchId, OrganizationalUnitId, FromDate, ToDate, ChangedBy` to capture transitions.

- **ISSUE-7 (MED — SERVICE_PLACEHOLDER)** — Branch History list in drawer = static placeholder until ISSUE-6 lands.

- **ISSUE-8 (MED — cross-entity)** — `Event` entity does not have `OwnerStaffId` FK → "Events managed" KPI in Activity Summary returns `0`. Follow-up when Event #40 builds (already PROMPT_READY — may add OwnerStaffId there).

- **ISSUE-9 (MED — User entity)** — `User.LastLoginDate` field availability unclear. If absent, return `null` from `staffActivitySummary` and display "—". If present, return ISO string.

- **ISSUE-10 (LOW — SERVICE_PLACEHOLDER)** — "Send welcome email" toggle is persisted on the `NewUserSubFormDto` but not consumed by any email pipeline yet. Future: consume in CreateUserCommand when email infra lands.

- **ISSUE-11 (MED — SERVICE_PLACEHOLDER)** — "Unlink" button in edit mode disabled with tooltip; requires ISSUE-1 (UserId nullable) to actually work.

- **ISSUE-12 (LOW — naming)** — Entity operations registry has `gridCode: "STAFF"` but MODULE_MENU_REFERENCE seeds `MenuCode: "STAFFS"` (plural). MUST align — pick one (prefer `STAFFS` per reference) + update seed SQL + entity-operations + page config + `useAccessCapability` menuCode. Grep for all `"STAFF"` literal uses in `src/app/`, `src/presentation/pages/organization/staff/`, and `application-service-entity-operations.ts` and rename.

- **ISSUE-13 (MED — deferred alignment)** — Existing `staff-company-config-tab.tsx` is a 28 KB multi-company role-assignment feature NOT shown in mockup. KEEP the component in place but:
  - REMOVE it from the main form flow (don't render by default).
  - EXPOSE it optionally: from the detail drawer's More menu → "Manage Company Access" link that navigates to a sub-route (`?mode=edit&id=X&tab=companyconfig`) which temporarily renders the tab inline. Full UX redesign deferred to a future iteration.
  - Preserve associated DTOs and GQL files (`StaffCompanyDto.ts`, `StaffCompanyQuery.ts`, `StaffCompanyMutation.ts`, `staff-role-access-viewer.tsx`).

- **ISSUE-14 (LOW — BE self-FK naming)** — `ReportingTo` nav property on Staff (self-FK). EF needs explicit configuration to avoid ambiguous FK — use Fluent API via `OnModelCreating` (or attribute) in migration.

- **ISSUE-15 (LOW — validator scope)** — `StaffEmpId` / `StaffEmail` / `StaffMobileNumber` uniqueness is currently GLOBAL in existing validators. Narrow to per-Company via `.Where(s => s.CompanyId == companyId)`.

- **ISSUE-16 (LOW — legacy `StaffCategoryTab`)** — Existing `staff-category-tab.tsx` provided granular per-staff category editing via its own dropdown + UPDATE_STAFF_MUTATION. Redundant with `staffCategoryId` field in new accordion form — delete.

- **ISSUE-17 (LOW — seed folder typo `dyanmic`)** — Preserve existing typo `sql-scripts-dyanmic/` per repo-wide convention (RecurringDonor + ChequeDonation + InKindDonation + others). New seed file: `sql-scripts-dyanmic/Staff-sqlscripts.sql`.

- **ISSUE-18 (LOW — `useAccessCapability`)** — `StaffPageConfig` uses `useAccessCapability({ menuCode: "STAFF" })`. Must change to `"STAFFS"` (ISSUE-12).

### Out-of-scope for this build

- Staff Branch History audit table (ISSUE-6).
- Photo upload pipeline (ISSUE-3).
- Import Staff pipeline (ISSUE-4).
- User Unlink + UserId migration to nullable (ISSUE-1, ISSUE-11).
- Company Configuration full UX redesign (ISSUE-13).
- Welcome email pipeline (ISSUE-10).
- Email on transfer / status change (future notification triggers).

### Agent directives

- **Backend agent**: model=Opus. Work only in `Pss2.0_Backend`. Migration is P0 — write it correctly, include backfill statements for `FirstName/LastName` split and `StaffStatus` default. Generate Designer file is OK even if timestamp is placeholder (user regenerates locally — per ISSUE pattern from #43).
- **Frontend agent**: model=Opus. Work only in `Pss2.0_Frontend`. Verify renderer names used in Section ⑥ exist in FE registries BEFORE seed runs — hot-patch seed if names drift (precedent: ContactType #19, PlaceholderDefinition #26). Use `@iconify` Phosphor icons. Obey `feedback_component_reuse_create.md`: grep registries first; reuse if found; create if missing. Variant B is mandatory (precedent: Family #20, SMSTemplate #29).
- **Orchestrator**: may skip BA/SR/UX agent spawns — this prompt already contains deep Sections ①–⑥ analysis (SavedFilter/Family/RecurringDonor precedent). Dispatch BE+FE in parallel on Opus.
- **Testing agent**: validate FK references (OrganizationalUnit, ReportingTo self), GraphQL field name alignment BE↔FE (precedent SMSTemplate hot-patch), DB seed idempotence, and end-to-end CRUD + Transfer + Drawer open/close.

### Reference prompts to mirror

- Drawer pattern: `recurringdonationschedule.md` §⑥ "LAYOUT 2: DETAIL DRAWER".
- Accordion form with 4 sections: `contact.md` §⑥ (ISSUE-11 precedent for accordion rewrite — note our mockup is simpler, only 4 sections vs Contact's 8).
- Organization-module conventions (schema=`app`, group=`Application`, Mappings file): `staffcategory.md` §⑦.
- 4 KPI widgets + Variant B: `family.md` §⑥.

---

## ⑬ Build Log (append during /build-screen)

(Empty — to be populated by orchestrator during build session.)