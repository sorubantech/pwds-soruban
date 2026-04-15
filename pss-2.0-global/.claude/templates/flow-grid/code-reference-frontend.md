# Frontend Code Reference — SavedFilter (FLOW Grid Entity)

> **SavedFilter is the canonical reference for FLOW screens.**
> Substitute: `SavedFilter` → `{EntityName}`, `SavedFilters` → `{PluralName}`, `savedFilter` → `{camelCase}`, `savedfilter` → `{entityLower}`, `SAVEDFILTER` → `{GRIDCODE}`, `notify` → `{group}`, `crm/communication` → `{group}/{feFolder}`

---

## Key Differences from MASTER_GRID (ContactType)

| Aspect | MASTER_GRID (ContactType) | FLOW (SavedFilter) |
|--------|---------------------------|---------------------|
| Grid component | `AdvancedDataTable` | `FlowDataTable` |
| Grid click behavior | Opens RJSF modal | Navigates to view page |
| Routing | No query params | `?mode=new\|edit\|read&id=N` |
| Page structure | 1 file (data-table) | 4 files (index, index-page, data-table, view-page) |
| Form rendering | RJSF (backend-driven) | React Hook Form + custom components |
| State management | Data table store only | Zustand store per entity |
| FE files to generate | 7 files + 6 wiring | 10+ files + 6 wiring + store |

---

## File Structure (FLOW Screen)

```
page-components/{group}/{feFolder}/savedfilter/
├── index.tsx          # Router: reads query params, renders Grid or ViewPage
├── index-page.tsx     # Grid wrapper (FlowDataTable)
├── data-table.tsx     # Grid config (optional — can be merged into index-page)
├── view-page.tsx      # View/Edit/Add form (React Hook Form or custom)
└── components/        # Optional: sub-components for complex view pages
    ├── index.ts
    ├── BasicInformation.tsx
    └── FilterConfiguration.tsx
```

---

## File 1 — DTO Types
`src/domain/entities/notify-service/SavedFilterDto.ts`
```typescript
import { OrganizationalUnitRequestDto } from "@/domain/entities";

export interface SavedFilterRequestDto {
  savedFilterId: number;
  organizationalUnitId: number;
  filterName: string;
  filterCode: string;
  description?: string;
  filterJson?: string;
  filterRecipientTypeId?: number;
  recipientTypeCode?: string;
}

export interface SavedFilterResponseDto extends SavedFilterRequestDto {
  isActive: boolean;
  organizationalUnit: OrganizationalUnitRequestDto;
}

export interface SavedFilterDto extends SavedFilterResponseDto {}
```

**FLOW DTO notes:**
- ResponseDto includes FK navigation DTOs as objects (not flat strings)
- `organizationalUnit: OrganizationalUnitRequestDto` — nested DTO for view page display
- For entities with children, add: `children?: ChildResponseDto[]`
- For entities with optional parent, add: `parent?: ParentRequestDto | null`

---

## File 2 — GraphQL Queries
`src/infrastructure/gql-queries/notify-queries/SavedFilterQuery.ts`
```typescript
import { gql } from "@apollo/client";

export const SAVEDFILTERS_QUERY = gql`
  query (
    $pageSize: Int!
    $pageIndex: Int!
    $sortDescending: Boolean
    $sortColumn: String
    $searchTerm: String
    $advancedFilter: QueryBuilderModelInput
  ) {
    result: savedFilters(
      request: {
        pageSize: $pageSize
        pageIndex: $pageIndex
        sortDescending: $sortDescending
        sortColumn: $sortColumn
        searchTerm: $searchTerm
        advancedFilter: $advancedFilter
      }
    ) {
      message
      pageIndex
      pageSize
      searchTerm
      status
      success
      totalCount
      filteredCount
      data {
        savedFilterId
        organizationalUnitId
        organizationalUnit { unitName }
        filterName
        filterCode
        description
        filterJson
        filterRecipientTypeId
        isActive
      }
    }
  }
`;

export const SAVEDFILTER_BY_ID_QUERY = gql`
  query ($savedFilterId: Int!) {
    result: savedFilterById(savedFilterId: $savedFilterId) {
      errorDetails
      message
      status
      success
      errorCode
      data {
        savedFilterId
        organizationalUnitId
        filterName
        filterCode
        description
        filterJson
        aggregationFilterJson
        filterRecipientTypeId
      }
    }
  }
`;
```

**FLOW Query differences:**
- **GetAll**: Includes FK navigation objects for grid display (e.g., `organizationalUnit { unitName }`). Includes `isActive`.
- **GetById**: Returns ALL fields needed for the view page form. Does NOT include `isActive`. May include nested objects:
  - FK navigations: `contact { contactId displayName contactCode }`
  - Optional parent: `postalDonationBatch { postalDonationBatchId batchCode }`
  - Child collections: `postalDonationDistributions { distributionId allocatedAmount ... }`

**FLOW GetById pattern for entities with parent + children:**
```graphql
query GetEntityById($entityId: Int!) {
  result: entityById(entityId: $entityId) {
    data {
      entityId
      fieldA
      fieldB
      # FK navigations — NOT separate API calls
      contact { contactId displayName }
      currency { currencyId currencyName currencySymbol }
      # Optional parent — NOT separate API call
      parentEntity { parentEntityId parentCode parentDate }
      # Children — NOT separate API call
      childEntities { childEntityId allocatedAmount
        donationPurpose { donationPurposeName } }
    }
    success message
  }
}
```

---

## File 3 — GraphQL Mutations
`src/infrastructure/gql-mutations/notify-mutations/SavedFilterMutation.ts`
```typescript
import { gql } from "@apollo/client";

export const CREATE_SAVEDFILTER_MUTATION = gql`
  mutation (
    $savedFilterId: Int
    $organizationalUnitId: Int!
    $filterName: String!
    $filterCode: String!
    $description: String
    $filterJson: String
    $aggregationFilterJson: String
    $filterRecipientTypeId: Int!
  ) {
    result: createSavedFilter(
      savedFilter: {
        savedFilterId: $savedFilterId
        organizationalUnitId: $organizationalUnitId
        filterName: $filterName
        filterCode: $filterCode
        description: $description
        filterJson: $filterJson
        aggregationFilterJson: $aggregationFilterJson
        filterRecipientTypeId: $filterRecipientTypeId
      }
    ) {
      errorCode errorDetails message status success
      data {
        savedFilterId organizationalUnitId filterName filterCode
        description filterJson aggregationFilterJson filterRecipientTypeId
      }
    }
  }
`;

export const UPDATE_SAVEDFILTER_MUTATION = gql`
  mutation (
    $savedFilterId: Int
    $organizationalUnitId: Int!
    $filterName: String!
    $filterCode: String!
    $description: String
    $filterJson: String
    $aggregationFilterJson: String
    $filterRecipientTypeId: Int!
  ) {
    result: updateSavedFilter(
      savedFilter: {
        savedFilterId: $savedFilterId
        organizationalUnitId: $organizationalUnitId
        filterName: $filterName
        filterCode: $filterCode
        description: $description
        filterJson: $filterJson
        aggregationFilterJson: $aggregationFilterJson
        filterRecipientTypeId: $filterRecipientTypeId
      }
    ) {
      errorCode errorDetails message status success
      data {
        savedFilterId organizationalUnitId filterName filterCode
        description filterJson aggregationFilterJson filterRecipientTypeId
      }
    }
  }
`;

export const DELETE_SAVEDFILTER_MUTATION = gql`
  mutation ($savedFilterId: Int!) {
    result: deleteSavedFilter(savedFilterId: $savedFilterId) {
      errorCode errorDetails message status success
      data { savedFilterId }
    }
  }
`;

export const ACTIVATE_DEACTIVATE_SAVEDFILTER_MUTATION = gql`
  mutation ($savedFilterId: Int!) {
    result: activateDeactivateSavedFilter(savedFilterId: $savedFilterId) {
      errorCode errorDetails message status success
      data { savedFilterId }
    }
  }
`;
```
*Mutation pattern is identical to MASTER_GRID. Create: PK is `Int` (no `!`). Update: PK is `Int` (same). Delete/Toggle: PK is `Int!`.*

---

## File 4 — Page Config
`src/presentation/pages/crm/communication/savedfilter.tsx`
```tsx
import { DefaultAccessDenied } from "@/presentation/components/custom-components/atoms/access-denied";
import { LayoutLoader } from "@/presentation/components/layout-components";
import SavedFilterPage from "@/presentation/components/page-components/crm/communication/savedfilter";
import useAccessCapability from "@/presentation/hooks/useInitialRendering/useCapability";

export function SavedFilterPageConfig() {
  const { capabilities, isReady, isLoading, error } = useAccessCapability({ menuCode: "SAVEDFILTER" });

  if (isLoading || !isReady) {
    return <LayoutLoader />;
  }

  if (!capabilities.canRead) {
    return <DefaultAccessDenied />;
  }

  return <SavedFilterPage />;
}
```
*FLOW difference: Renders `SavedFilterPage` (the router/dispatcher) instead of a DataTable directly.*

---

## File 5 — Index Component (Router/Dispatcher) — FLOW-SPECIFIC
`src/presentation/components/page-components/crm/communication/savedfilter/index.tsx`
```tsx
"use client";

import { useFlowDataTableStore, useGlobalStore } from "@/application/stores";
import { useSavedFilterStore } from "@/application/stores/saved-filter-stores/saved-filter-store";
import { useSearchParams } from "next/navigation";
import { useEffect, useRef } from "react";
import { SavedFilterIndexPage } from "./index-page";
import { SavedFilterViewPage } from "./view-page";

export default function SavedFilterPage() {
    const searchParams = useSearchParams();
    const { crudMode, setCrudMode, setRecordId, recordId } = useFlowDataTableStore();
    const { setIsMenuRendering, setModuleLoading } = useGlobalStore();
    const { resetStore } = useSavedFilterStore();

    // Track previous recordId to detect navigation between different records
    const prevRecordIdRef = useRef<number | null>(null);

    useEffect(() => {
        const mode = searchParams.get("mode");
        const id = searchParams.get("id");
        const newRecordId = id ? parseInt(id, 10) : 0;

        // Reset store when navigating to a different record
        const isNavigatingToDifferentRecord =
            prevRecordIdRef.current !== null &&
            prevRecordIdRef.current !== newRecordId &&
            newRecordId !== 0;

        if (isNavigatingToDifferentRecord) {
            resetStore();
        }

        prevRecordIdRef.current = newRecordId;

        if (mode === "new") {
            setCrudMode("add");
            setRecordId(0);
            setIsMenuRendering(false);
            setModuleLoading(false);
        } else if (mode === "edit" && id) {
            setCrudMode("edit");
            setRecordId(newRecordId);
            setIsMenuRendering(false);
            setModuleLoading(false);
        } else if (mode === "read" && id) {
            setCrudMode("read");
            setRecordId(newRecordId);
            setIsMenuRendering(false);
            setModuleLoading(false);
        } else {
            // No query params - show index grid
            if (crudMode !== "index") {
                resetStore();
            }
            setCrudMode("index");
            setIsMenuRendering(false);
            setModuleLoading(false);
            prevRecordIdRef.current = null;
        }
    }, [searchParams, setCrudMode, setRecordId, setIsMenuRendering, setModuleLoading, resetStore, crudMode]);

    const isFormView = crudMode === "add" || crudMode === "edit" || crudMode === "read";
    const viewKey = `${crudMode}-${recordId}`;

    return (
        <div>
            {isFormView ? <SavedFilterViewPage key={viewKey} /> : <SavedFilterIndexPage />}
        </div>
    );
}
```

**FLOW routing pattern:**
| URL Query Params | crudMode | What Renders |
|------------------|----------|-------------|
| *(none)* | `"index"` | Grid (IndexPage) |
| `?mode=new` | `"add"` | Empty form (ViewPage) |
| `?mode=edit&id=5` | `"edit"` | Pre-populated editable form |
| `?mode=read&id=5` | `"read"` | Pre-populated read-only form |

**Key patterns:**
- `useFlowDataTableStore()` — shared store for CRUD mode and record ID
- `useSearchParams()` — reads query params for routing
- `resetStore()` — clears entity store when navigating between records or back to grid
- `key={viewKey}` — forces re-mount when navigating between different records
- `setIsMenuRendering(false)` / `setModuleLoading(false)` — clears global loading states

---

## File 6 — Index Page (Grid) — FLOW-SPECIFIC
`src/presentation/components/page-components/crm/communication/savedfilter/index-page.tsx`
```tsx
"use client";

import { TDataTableConfigs } from "@/domain/types";
import { FlowDataTable } from "@/presentation/components/custom-components";

export function SavedFilterIndexPage() {
  const initialPageIndex = 0;
  const initialPageSize = 10;
  const gridCode = "SAVEDFILTER";
  const tablePropertyConfig: TDataTableConfigs = {
    enableAdvanceFilter: true,
    enablePagination: true,
    enableAdd: true,
    enableImport: false,
    enableExport: true,
    enablePrint: true,
    enableActions: {
      enableView: false,
      enableEdit: true,
      enableDelete: true,
      enableToggle: true,
    },
  };

  return (
    <FlowDataTable
      gridCode={gridCode}
      initialPageSize={initialPageSize}
      initialPageIndex={initialPageIndex}
      tableConfig={tablePropertyConfig}
    />
  );
}
```

**FLOW grid differences from MASTER_GRID:**
- Uses `FlowDataTable` (NOT `AdvancedDataTable`)
- `enableActions` controls row-level action buttons (view, edit, delete, toggle)
- Grid row click navigates to `?mode=read&id=N` (read view)
- Edit button navigates to `?mode=edit&id=N`
- Add button navigates to `?mode=new`

---

## File 7 — View Page (Form) — FLOW-SPECIFIC
`src/presentation/components/page-components/crm/communication/savedfilter/view-page.tsx`

The view page is the core FLOW differentiator. It renders a full form with read/edit/add modes.

**Essential patterns every FLOW view page must implement:**

### 7a. Page Header
```tsx
import { FlowFormPageHeader } from "@/presentation/components/custom-components/page-header";

<FlowFormPageHeader
    title={displayName}
    gridName={gridInfo?.gridName}
    moduleName={moduleName ?? ""}
    moduleHref={moduleHref}
    menuName={menuName || undefined}
    crudMode={crudMode as "add" | "edit" | "read"}
    onBack={handleBackButton}
    onSave={handleSave}
    onEdit={handleSwitchToEdit}
    isSaving={isSaving}
    canSave={canSave}
    canEdit={canEdit}
    hasUnsavedChanges={isDirty}
/>
```

### 7b. Mode Handling
```tsx
const { crudMode, setCrudMode, recordId, capability } = useFlowDataTableStore();
const { formData, loadInitialData, validateForm, isDirty, resetStore, updateFormField } = useEntityStore();

const isEditMode = crudMode === "edit";
const isReadMode = crudMode === "read";
const isViewingExistingRecord = isEditMode || isReadMode;

const canSave = !isSaving && isDirty;
const canEdit = capability?.canUpdate ?? false;
```

### 7c. Data Loading (Edit/Read Mode)
```tsx
useEffect(() => {
    const loadEditData = async () => {
        if (!isViewingExistingRecord || !recordId) return;

        try {
            setIsLoadingData(true);
            const operationConfig = DataTableOperationConfigs.find(
                (config) => config.gridCode === "SAVEDFILTER"
            );

            const { data } = await client.query<TApiSingleResponse<any>>({
                query: operationConfig.operation.getById.query,
                variables: { savedFilterId: recordId },
                fetchPolicy: "network-only",
            });

            if (data?.result?.success && data.result.data) {
                // Use loadInitialData (NOT setFormData) to avoid triggering isDirty
                loadInitialData({
                    savedFilterId: data.result.data.savedFilterId,
                    filterName: data.result.data.filterName,
                    filterCode: data.result.data.filterCode,
                    description: data.result.data.description || "",
                    organizationalUnitId: data.result.data.organizationalUnitId,
                    // ... map all fields
                });
            }
        } finally {
            setIsLoadingData(false);
        }
    };

    loadEditData();
}, [isViewingExistingRecord, recordId, client, loadInitialData]);
```

### 7d. Save Handler
```tsx
const handleSave = async () => {
    if (!validateForm()) {
        toast.error("Please fill in all required fields correctly");
        return;
    }

    try {
        setIsSaving(true);
        const operationConfig = DataTableOperationConfigs.find((config) => config.gridCode === "SAVEDFILTER");
        const mutation = crudMode === "edit"
            ? operationConfig.operation.update?.mutation
            : operationConfig.operation.create?.mutation;

        const { data } = await client.mutate({
            mutation,
            variables: {
                savedFilterId: formData.savedFilterId || 0,
                filterName: formData.filterName,
                filterCode: formData.filterCode,
                description: formData.description || "",
                organizationalUnitId: formData.organizationalUnitId,
                filterRecipientTypeId: formData.filterRecipientTypeId,
                filterJson: formData.filterJson || "",
                aggregationFilterJson: formData.aggregationFilterJson || "",
            },
        });

        if (data?.result?.success) {
            toast.success(`Record ${crudMode === "edit" ? "updated" : "created"} successfully`);
            resetStore();
            router.push(pathname);  // Navigate back to grid
        } else {
            toast.error(data?.result?.message || "Operation failed");
        }
    } catch (error: any) {
        toast.error(error.message || "Failed to save");
    } finally {
        setIsSaving(false);
    }
};
```

### 7e. Back Navigation with Unsaved Changes Dialog
```tsx
const handleBackButton = () => {
    if (isReadMode) {
        performBackNavigation();
        return;
    }
    if (!shouldWarnUnsaved) {
        performBackNavigation();
        return;
    }
    // Show confirmation dialog
    setPendingNavigation({ type: "custom", callback: performBackNavigation });
    setShowConfirmDialog(true);
};

const performBackNavigation = useCallback(() => {
    resetStore();
    router.push(pathname);  // Back to grid (no query params)
}, [resetStore, router, pathname]);
```

### 7f. Switch to Edit Mode
```tsx
const handleSwitchToEdit = () => {
    setCrudMode("edit");
    router.push(`${pathname}?mode=edit&id=${recordId}`);
};
```

### 7g. Unsaved Changes Confirmation Dialog
```tsx
<AlertDialog open={showConfirmDialog} onOpenChange={(open) => !open && handleCancelNavigation()}>
    <AlertDialogContent className="max-w-md">
        <AlertDialogHeader>
            <AlertDialogTitle>Unsaved Changes</AlertDialogTitle>
        </AlertDialogHeader>
        <AlertDialogDescription>
            You have unsaved changes that will be lost if you leave this page.
        </AlertDialogDescription>
        <AlertDialogFooter>
            <AlertDialogCancel onClick={handleCancelNavigation}>Stay on Page</AlertDialogCancel>
            <AlertDialogAction color="destructive" onClick={handleConfirmNavigation}>
                Discard Changes
            </AlertDialogAction>
        </AlertDialogFooter>
    </AlertDialogContent>
</AlertDialog>
```

### 7h. Form Fields with Read/Edit Mode Support
```tsx
<fieldset disabled={isReadMode} className={cn(
    isReadMode && "[&_*:disabled]:!bg-transparent [&_*:disabled]:!opacity-100"
)}>
    <FormInput
        name="filterName"
        label="Filter Name"
        value={formData.filterName || ""}
        onChangeCallback={(value) => updateFormField("filterName", value as string)}
        placeholder="Enter filter name"
        required
    />
    <FormSelect
        name="organizationalUnitId"
        label="Program"
        value={formData.organizationalUnitId?.toString() || ""}
        options={programOptions}
        placeholder="Select program"
        loading={orgUnitsLoading}
        onChange={(value) => updateFormField("organizationalUnitId", value ? parseInt(value as string) : null)}
        required
    />
    <FormTextarea
        name="description"
        label="Description"
        value={formData.description || ""}
        onChangeCallback={(value) => updateFormField("description", value)}
        placeholder="Enter description (optional)"
    />
</fieldset>
```

**Read mode pattern:** Wrap form sections in `<fieldset disabled={isReadMode}>` with CSS override to keep disabled fields readable.

### 7i. Link Navigation Interception (for unsaved changes)
```tsx
useEffect(() => {
    if (!shouldWarnUnsaved) return;

    const handleClick = (e: MouseEvent) => {
        const anchor = (e.target as HTMLElement).closest('a');
        if (!anchor || !anchor.href) return;

        try {
            const url = new URL(anchor.href);
            if (url.origin !== window.location.origin) return;
            if (url.pathname === window.location.pathname) return;

            e.preventDefault();
            e.stopPropagation();
            e.stopImmediatePropagation();
            setPendingNavigation({ type: "link", href: anchor.href });
            setShowConfirmDialog(true);
        } catch { return; }
    };

    document.addEventListener('click', handleClick, { capture: true, passive: false });
    return () => document.removeEventListener('click', handleClick, { capture: true } as EventListenerOptions);
}, [shouldWarnUnsaved]);
```

---

## File 8 — Zustand Store — FLOW-SPECIFIC
`src/application/stores/saved-filter-stores/saved-filter-store.ts`
```typescript
import { create } from "zustand";

export interface SavedFilterFormData {
  savedFilterId: number | null;
  filterCode: string;
  filterName: string;
  description: string;
  organizationalUnitId: number | null;
  filterRecipientTypeId: number | null;
  recipientTypeCode: string | null;
  filterJson: string;
  aggregationFilterJson: string;
  // ... additional domain-specific fields
}

export interface ISavedFilterStore {
  // Form Data
  formData: Partial<SavedFilterFormData>;
  setFormData: (data: Partial<SavedFilterFormData>) => void;
  loadInitialData: (data: Partial<SavedFilterFormData>) => void;
  updateFormField: <K extends keyof SavedFilterFormData>(field: K, value: SavedFilterFormData[K]) => void;
  resetFormData: () => void;

  // Validation
  validationErrors: Record<string, string>;
  setValidationErrors: (errors: Record<string, string>) => void;
  clearValidationErrors: () => void;
  validateForm: () => boolean;

  // Form Dirty State
  isDirty: boolean;
  setIsDirty: (dirty: boolean) => void;
  initialFormData: Partial<SavedFilterFormData>;

  // Save Function Callback
  saveFormCallback: (() => Promise<void>) | null;
  setSaveFormCallback: (callback: (() => Promise<void>) | null) => void;

  // Reset entire store
  resetStore: () => void;
}

const initialFormData: Partial<SavedFilterFormData> = {
  savedFilterId: null,
  filterCode: "",
  filterName: "",
  description: "",
  organizationalUnitId: null,
  filterRecipientTypeId: null,
  recipientTypeCode: null,
  filterJson: "",
  aggregationFilterJson: "",
};

export const useSavedFilterStore = create<ISavedFilterStore>((set, get) => ({
  formData: { ...initialFormData },
  initialFormData: { ...initialFormData },

  setFormData: (data) =>
    set((state) => ({
      formData: { ...state.formData, ...data },
      isDirty: true,
    })),

  // CRITICAL: loadInitialData does NOT set isDirty — used for loading existing records
  loadInitialData: (data) =>
    set((state) => ({
      formData: { ...state.formData, ...data },
      initialFormData: { ...state.formData, ...data },
      isDirty: false,
    })),

  updateFormField: (field, value) =>
    set((state) => ({
      formData: { ...state.formData, [field]: value },
      isDirty: true,
    })),

  resetFormData: () =>
    set({ formData: { ...initialFormData }, isDirty: false }),

  // Validation
  validationErrors: {},
  setValidationErrors: (errors) => set({ validationErrors: errors }),
  clearValidationErrors: () => set({ validationErrors: {} }),

  validateForm: () => {
    const { formData } = get();
    const errors: Record<string, string> = {};

    // Required field checks — AI generates based on entity's non-nullable fields
    if (!formData.filterCode?.trim()) errors.filterCode = "Filter code is required";
    if (!formData.filterName?.trim()) errors.filterName = "Filter name is required";
    if (!formData.organizationalUnitId) errors.organizationalUnitId = "Program is required";
    if (!formData.filterRecipientTypeId) errors.filterRecipientTypeId = "Recipient type is required";

    set({ validationErrors: errors });
    return Object.keys(errors).length === 0;
  },

  // Form State
  isDirty: false,
  setIsDirty: (dirty) => set({ isDirty: dirty }),

  // Save Callback
  saveFormCallback: null,
  setSaveFormCallback: (callback) => set({ saveFormCallback: callback }),

  // Reset
  resetStore: () =>
    set({
      formData: { ...initialFormData },
      initialFormData: { ...initialFormData },
      validationErrors: {},
      isDirty: false,
      saveFormCallback: null,
    }),
}));
```

**Store pattern rules:**
- `loadInitialData` — sets form data WITHOUT marking dirty (for loading existing records)
- `setFormData` / `updateFormField` — sets form data AND marks dirty (for user edits)
- `validateForm` — checks all required fields, returns boolean
- `resetStore` — clears everything when navigating away
- Always start with `initialFormData` object for all fields with default values

---

## File 9 — Route Page
`src/app/[lang]/crm/communication/savedfilter/page.tsx`
```tsx
"use client";
import { SavedFilterPageConfig } from "@/presentation/pages/crm";

export default function SavedFilter() {
    return <SavedFilterPageConfig />;
}
```
*Identical pattern to MASTER_GRID. Route folder is `savedfilter` (entity name lowercase).*

---

## Wiring Updates (6 locations — same as MASTER_GRID)

### 1. DTO Barrel Export
**File**: `src/domain/entities/notify-service/index.ts`
```typescript
export * from "./SavedFilterDto";
```

### 2. Mutation Barrel Export
**File**: `src/infrastructure/gql-mutations/notify-mutations/index.ts`
```typescript
export * from "./SavedFilterMutation";
//EntityMutationExport
```

### 3. Query Barrel Export
**File**: `src/infrastructure/gql-queries/notify-queries/index.ts`
```typescript
export * from "./SavedFilterQuery";
//EntityQueryExport
```

### 4. PageConfig Barrel Export
**File**: `src/presentation/pages/crm/communication/index.ts`
```typescript
export * from "./savedfilter";
//EntityPageConfigExport
```

### 5. Component Barrel Export
**File**: `src/presentation/components/page-components/crm/communication/savedfilter/index.ts`
*For FLOW: The default export IS the router component itself, so the barrel is the index.tsx file.*

### 6. Entity Operations Config
**File**: `src/application/configs/data-table-configs/notify-service-entity-operations.ts`
```typescript
{
  gridCode: "SAVEDFILTER",
  operation: {
    getAll: {
      query: Queries.SAVEDFILTERS_QUERY,
      dto: {} as Dtos.SavedFilterDto,
    },
    getById: {
      query: Queries.SAVEDFILTER_BY_ID_QUERY,
      dto: {} as Dtos.SavedFilterDto,
    },
    create: {
      mutation: Mutations.CREATE_SAVEDFILTER_MUTATION,
      dto: {} as Dtos.SavedFilterRequestDto,
    },
    update: {
      mutation: Mutations.UPDATE_SAVEDFILTER_MUTATION,
      dto: {} as Dtos.SavedFilterRequestDto,
    },
    delete: {
      mutation: Mutations.DELETE_SAVEDFILTER_MUTATION,
      dto: {} as Dtos.SavedFilterRequestDto,
    },
    toggle: {
      mutation: Mutations.ACTIVATE_DEACTIVATE_SAVEDFILTER_MUTATION,
      dto: {} as Dtos.SavedFilterRequestDto,
    },
  },
},
```

---

## FLOW View Page — AI Self-Decision Patterns

### Form Field Widget Selection (same as UX Architect field widget table)

| Field Pattern | Component | Props |
|--------------|-----------|-------|
| `*Name`, `*Code`, `*No` | `FormInput` | `type="text"` |
| `*Description`, `*Remarks`, `*Note` | `FormTextarea` | `rows={2-4}` |
| `*Email` | `FormInput` | `type="email"` |
| `*Phone*`, `*Mobile*` | `FormInput` | `type="tel"` |
| `*Amount`, `*Rate`, `*Price` | `FormInput` | `type="number" step="0.01"` |
| `*Date` | Date picker | Custom component |
| `is*`, `has*` | `Checkbox` / `Switch` | |
| FK to small entity | `FormSelect` with options from `useQuery` | `loading`, `placeholder` |
| FK to large entity (Contact, Staff) | `ApiSelectV3` | `minSearchCharacter: 3` |

### Form Section Grouping

AI groups fields into collapsible sections using `TabHeader`:
```tsx
<div className="border border-border rounded-lg overflow-hidden">
    <TabHeader
        icon="icon-name"
        title="Section Title"
        description="Section description"
        variant="primary"
    />
    <div className="px-3 sm:px-4 lg:px-6 pb-4 sm:pb-6 pt-3 sm:pt-4 space-y-3 sm:space-y-4">
        {/* Form fields here */}
    </div>
</div>
```

### Child Section Pattern (for entities with children)

Child sections unlock only after the parent is saved:
```tsx
{formData.entityId && formData.entityId > 0 && (
    <div className="border border-border rounded-lg overflow-hidden">
        <TabHeader icon="list" title="Child Items" variant="secondary" />
        <div className="p-4">
            {/* Child grid or card list here */}
            {/* Uses RJSF modal for add/edit if simple child */}
            {/* After child CRUD: refetch parent GetById query */}
        </div>
    </div>
)}
```

### Dropdown Data Loading Pattern
```tsx
const { data: optionsData, loading: optionsLoading } = useQuery(ENTITIES_QUERY, {
    variables: {
        pageSize: 100,        // or -1 for all
        pageIndex: 0,
        sortDescending: false,
        sortColumn: "entityName",
    },
});

const options: SelectOption[] = useMemo(() => {
    return (optionsData?.result?.data || []).map((item: any) => ({
        value: item.entityId,
        label: item.entityName,
    }));
}, [optionsData]);
```

---

## FLOW vs MASTER_GRID — File Count Comparison

| Component | MASTER_GRID | FLOW |
|-----------|-------------|------|
| DTO | 1 | 1 |
| GQL Queries | 1 | 1 |
| GQL Mutations | 1 | 1 |
| Page Config | 1 | 1 |
| Data Table | 1 | 1 (index-page) |
| Router/Index | - | 1 (index.tsx) |
| View Page | - | 1 (view-page.tsx) |
| Zustand Store | - | 1 |
| Route Page | 1 | 1 |
| Sub-components | - | 0-N (optional) |
| **Total** | **6 + route** | **8 + route + optional sub-components** |
| Wiring Updates | 6 | 6 |
