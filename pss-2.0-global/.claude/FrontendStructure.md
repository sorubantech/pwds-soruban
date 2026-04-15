# PSS 2.0 Frontend — Complete Technical Reference

**Stack**: Next.js 14 | React 18 | TypeScript 5.8 | Apollo Client | Zustand | Shadcn/Radix UI | Tailwind CSS | TanStack Table | RJSF

**Root Path**: `Pss2.0_Frontend/src/`

---

## 1. Architecture Layers

```
src/
├── app/                    → Next.js App Router (routes only, minimal logic)
├── presentation/           → UI layer (components, hooks, pages, providers)
├── application/            → Business logic (stores, configs, enums)
├── domain/                 → Data types (entities/DTOs, type definitions)
└── infrastructure/         → External integration (GraphQL queries/mutations, services)
```

---

## 2. Page Creation Path (Exact Steps)

### Step 1: Route File
**Path**: `src/app/[lang]/(core)/{group}/{feFolder}/{entityLower}/page.tsx`
```tsx
"use client";
import { EntityPageConfig } from "@/presentation/pages/{group}/{feFolder}";
export default function EntityPage() { return <EntityPageConfig />; }
```

### Step 2: Page Config (capability gate)
**Path**: `src/presentation/pages/{group}/{feFolder}/{entityLower}.tsx`
```tsx
"use client";
import { useAccessCapability } from "@/presentation/hooks/useCapablities";
import { LayoutLoader } from "@/presentation/components/custom-components/loader/layout-loader";
import { DefaultAccessDenied } from "@/presentation/components/custom-components/atoms/default-access-denied";
import { EntityDataTable } from "@/presentation/components/page-components/{group}/{feFolder}";

export function EntityPageConfig() {
  const { capabilities, isReady, isLoading } = useAccessCapability({ menuCode: "GRIDCODE" });
  if (isLoading || !isReady) return <LayoutLoader />;
  if (!capabilities.canRead) return <DefaultAccessDenied />;
  return <EntityDataTable />;
}
```

### Step 3: DataTable Component
**Path**: `src/presentation/components/page-components/{group}/{feFolder}/{entityLower}-data-table.tsx`
```tsx
"use client";
import { AdvancedDataTable } from "@/presentation/components/custom-components/data-tables/advanced";
import { TDataTableConfigs } from "@/domain/types/data-table-types/TDataTable";

export function EntityDataTable() {
  const gridCode = "GRIDCODE";
  const tablePropertyConfig: TDataTableConfigs = {
    enableSearch: true, enableSelectField: true, enableAdvanceFilter: true,
    enableSorting: true, enablePagination: true, enableSelectColumn: false,
    enableAdd: true, enableImport: true, enableExport: true,
    enablePrint: true, enableFullScreenMode: true, enableStickyHeader: true,
    enableTooltip: true, enableColumnResize: false,
  };
  return <AdvancedDataTable gridCode={gridCode} initialPageSize={10} initialPageIndex={0} tableConfig={tablePropertyConfig} />;
}
```

### Step 4: Component barrel export
**Path**: `src/presentation/components/page-components/{group}/{feFolder}/index.ts`
```typescript
export * from "./{entityLower}-data-table";
//entity-parent-component-export
```

---

## 3. Data Table System (6 Variants)

| Variant | Path | Use Case |
|---------|------|----------|
| **AdvancedDataTable** | `custom-components/data-tables/advanced/` | Primary — full-featured CRUD grid |
| **BasicDataTable** | `custom-components/data-tables/basic/` | Simplified grid (fewer features) |
| **DashboardWidgetDataTable** | `custom-components/data-tables/dashboard-widget/` | Dashboard widget embedded grids |
| **FlowDataTable** | `custom-components/data-tables/flow/` | Workflow/process displays |
| **QuickFilterDataTable** | `custom-components/data-tables/quickfilter/` | Quick filter interface |
| **ReportDataTable** | `custom-components/data-tables/report/` | Report-focused layout |

### AdvancedDataTable Architecture
```
AdvancedDataTable
├── AdvancedDataTableStoreProvider (Zustand store per instance)
│   └── AdvancedDataTableInner
│       ├── useInitializeDataTableColumns() → GRID_BY_CODE_QUERY → columns + formSchemas
│       ├── useInitializeDataTableDatas() → entity getAll query → data
│       └── DataTableContainer
│           ├── DataTableGeneralToolbar (search, filters, add, import, export, print)
│           ├── TanStack React Table (dynamic columns, sorting, pagination)
│           │   ├── Column Types: default, status (badge), component, action
│           │   └── Component Column Types: approval-flow, date-preview, html-preview, meeting-status, student-detail, verification-status
│           └── DataTableFooterToolbar (pagination, row density)
```

### TDataTableConfigs (Feature Flags)
```typescript
{
  enableSearch: boolean,           // Search bar
  enableSelectField: boolean,      // Column selector
  enableAdvanceFilter: boolean,    // Advanced filter builder
  enableQuickFilter: boolean,      // Quick filter chips
  enableSorting: boolean,          // Column sorting
  enablePagination: boolean,       // Pagination footer
  enableSelectColumn: boolean,     // Row checkboxes
  enableActions?: TActionOptions,  // { enableView, enableEdit, enableDelete, enableToggle }
  enableAdd: boolean,              // Add button
  enableImport: boolean,           // Import button
  enableExport: boolean,           // Export button
  enablePrint: boolean,            // Print button
  enableFullScreenMode: boolean,   // Fullscreen toggle
  enableStickyHeader: boolean,     // Sticky column headers
  enableTooltip: boolean,          // Cell tooltips
  enableColumnResize: boolean,     // Column resize handles
  enableRowDensity: boolean,       // Row density toggle (sm/md/lg)
}
```

---

## 4. Form System (RJSF — Backend-Driven)

Forms are **NOT coded manually**. The backend sends JSON Schema + uiSchema via `GridFormSchema`, and RJSF renders them dynamically.

### 23 Form Widgets Available
| Widget | Use Case |
|--------|----------|
| `text` (default) | Short strings (maxLen ≤ 500) |
| `textarea` | Long text (maxLen > 500) |
| `email` | Email addresses |
| `url` | URL fields |
| `checkbox` | Single boolean |
| `checkboxes` | Multiple boolean options |
| `radio` | Radio button group |
| `select` | Standard dropdown |
| `api-select` / `api-selectv2` / `api-selectv3` | API-driven dropdowns (FK fields) |
| `api-multi-select` | Multi-select from API |
| `date-picker` | Date input |
| `date-range-picker` | Date range |
| `time-picker` | Time input |
| `time-duration` | Duration input (HH:MM:SS) |
| `range` | Range slider |
| `rich-text-editor` | WYSIWYG (Tiptap) |
| `label` | Static display text |
| `auto-generate-text` | Auto-generated values |

### Form Hook
```typescript
useGridForm<FData>({
  gql: { QUERY?: DocumentNode, MUTATE: DocumentNode },
  schema: RJSFSchema,
  uiSchema: UiSchema,
  handleMutationWithToast: (promise) => Promise<any>
})
// Returns: formData, setFormData, fetching, submitting, queryRow, mutate
```

---

## 5. State Management (Zustand)

### Store Pattern
```typescript
// Interface: src/application/stores/{feature}-stores/{store}-istore.ts
// Implementation: src/application/stores/{feature}-stores/{store}-store.ts

// Factory pattern for data tables (per-instance):
createAdvancedDataTableStore() → store with context provider
// Accessed via: useAdvancedDataTableStoreFromContext(selector)
```

### Key Stores
| Store | Path | Purpose |
|-------|------|---------|
| globalStore | `common-stores/global-store.ts` | Module, user, company |
| themeStore | `common-stores/layout-store.ts` | Theme, layout, navbar |
| sidebarStore | `common-stores/sidebar-store.ts` | Sidebar state |
| userStore | `auth-stores/user-store.ts` | User info (persisted) |
| menuStore | `auth-stores/menu-store.ts` | Menu tree |
| modalStore | `common-stores/` | Active modals |

### Creating a New Store
```typescript
import { create } from "zustand";
import { persist } from "zustand/middleware";

interface IEntityStore {
  data: EntityDto[];
  loading: boolean;
  setData: (data: EntityDto[]) => void;
}

export const useEntityStore = create<IEntityStore>()(
  persist(
    (set) => ({
      data: [],
      loading: false,
      setData: (data) => set({ data }),
    }),
    { name: "entity-store" }  // localStorage key
  )
);
```

---

## 6. GraphQL Integration (Apollo Client)

### Query Pattern
```typescript
import { gql } from "@apollo/client";

export const ENTITIES_QUERY = gql`
  query GetEntities($pageSize: Int, $pageIndex: Int, $sortDescending: Boolean,
    $sortColumn: String, $searchTerm: String, $advancedFilter: QueryBuilderModelInput) {
    result: entities(request: {
      pageSize: $pageSize, pageIndex: $pageIndex, sortDescending: $sortDescending,
      sortColumn: $sortColumn, searchTerm: $searchTerm, advancedFilter: $advancedFilter
    }) {
      data { entityId, entityName, fkId, isActive }
      totalCount, filteredCount, pageIndex, pageSize
    }
  }
`;

export const ENTITY_BY_ID_QUERY = gql`
  query GetEntityById($entityId: Int!) {
    result: entityById(entityId: $entityId) {
      data { entityId, entityName, fkId }
      success, message
    }
  }
`;
```

### Mutation Pattern
```typescript
export const CREATE_ENTITY_MUTATION = gql`
  mutation CreateEntity($entityId: Int, $entityName: String!, $fkId: Int!) {
    result: createEntity(entity: { entityId: $entityId, entityName: $entityName, fkId: $fkId }) {
      data { entityId, entityName, fkId }
      success, message
    }
  }
`;
// Similar: UPDATE_, DELETE_, ACTIVATE_DEACTIVATE_
```

### GraphQL Type Mapping
| C# Type | GQL (required) | GQL (optional) |
|---------|---------------|----------------|
| int | Int! | Int |
| string | String! | String |
| bool | Boolean! | Boolean |
| DateTime | DateTime! | DateTime |
| decimal | Decimal! | Decimal |

### Apollo Client Config
- **Fetch policy**: `network-only` (default)
- **Error handling**: Token expiration → toast, maintenance mode → redirect
- **Auth**: Bearer token from NextAuth session injected in headers
- **Cache**: apollo3-cache-persist to localStorage

### Generic Hooks
```typescript
useGenericQuery<TData>({ query, variables, skip, lazy, fetchPolicy, onCompleted, onError })
// Returns: data, loading, error, refetch, isPaginated, items, totalCount, record

useGenericMutation<TData, TVariables>({ mutation, onCompleted, onError, showToast })
// Returns: execute, loading, error, success, data, message, reset
```

---

## 7. Entity Operations Config

**Path**: `src/application/configs/data-table-configs/{group}-service-entity-operations.ts`

```typescript
import * as Queries from "@/infrastructure/gql-queries/{group}-queries";
import * as Mutations from "@/infrastructure/gql-mutations/{group}-mutations";
import * as Dtos from "@/domain/entities/{group}-service";

export const GroupServiceEntityOperations: TDataTableOperationConfigs[] = [
  {
    gridCode: "ENTITYCODE",
    operation: {
      getAll: { query: Queries.ENTITIES_QUERY, dto: {} as Dtos.EntityDto },
      getById: { query: Queries.ENTITY_BY_ID_QUERY, dto: {} as Dtos.EntityDto },
      create: { mutation: Mutations.CREATE_ENTITY_MUTATION, dto: {} as Dtos.EntityRequestDto },
      update: { mutation: Mutations.UPDATE_ENTITY_MUTATION, dto: {} as Dtos.EntityRequestDto },
      delete: { mutation: Mutations.DELETE_ENTITY_MUTATION, dto: {} as Dtos.EntityRequestDto },
      toggle: { mutation: Mutations.ACTIVATE_DEACTIVATE_ENTITY_MUTATION, dto: {} as Dtos.EntityRequestDto },
    },
  },
  //EntityOperationsLines
];
```

**Master config combines all services**: `src/application/configs/data-table-configs/index.ts`

---

## 8. DTO Types (TypeScript)

```typescript
export interface EntityRequestDto {
  entityId?: number | null;     // Optional on create
  entityName: string;           // Required string
  fkId: number;                 // Required FK
  optionalField?: string | null; // Optional
}

export interface EntityResponseDto extends EntityRequestDto {
  isActive: boolean;
  fkEntityName?: string | null;  // FK display name
}

export interface EntityDto extends EntityResponseDto {}
```

### Type Mapping (C# → TypeScript)
| C# | TypeScript |
|----|-----------|
| int | number |
| int? | number \| null |
| string (required) | string |
| string (optional) | string \| null |
| bool | boolean |
| DateTime | string (ISO) |
| decimal | number |

---

## 9. Response Types

```typescript
TApiBaseResponse { status, success, errorCode, errorDetails, message }
TSingleResponse<T> extends TApiBaseResponse { data?: T }
TCollectionResponse<T> extends TApiBaseResponse { data?: T[] }
TPaginatedApiBaseResponse<T> extends TCollectionResponse { pageIndex, pageSize, totalCount, filteredCount }

// Wrapped:
TApiSingleResponse<T> { result: TSingleResponse<T> }
TPaginatedApiResponse<T> { result: TPaginatedApiBaseResponse<T> }
```

---

## 10. Capabilities & Access Control

```typescript
useAccessCapability({ menuCode: "GRIDCODE" }) → {
  capabilities: { canRead, canCreate, canModify, canDelete, canImport, canExport, canToggle },
  isReady: boolean,
  isLoading: boolean
}
```

---

## 11. Reusable Components Catalog

### Common Atoms (43 components)
`src/presentation/components/common-components/atoms/`
Accordion, Alert, Avatar, Badge, Breadcrumbs, Button, Card, Checkbox, Collapsible, Command, Dialog, Drawer, DropdownMenu, HoverCard, InputGroup, Kbd, Label, Listbox, Menubar, NavigationMenu, Popover, Progress, Rating, Resizable, ScrollArea, Select, Separator, Sheet, Skeleton, Steps, Switch, Table, Tabs, Textarea, Timeline, Toast/Toaster/Sonner, Toggle, ToggleGroup, Tooltip, Tree

### Custom Atoms
`src/presentation/components/custom-components/atoms/`
access-denied, animate-svg, empty-state, gradient-loader, searchable-select, skeleton, spinner

### Layout Components
`src/presentation/components/layout-components/`
sidebar (classic/popover/mobile/module), header, footer, breadcrumb, customizer (theme/layout/radius/RTL), loaders (layout/menu/module/common)

### Modals
`src/presentation/components/modals/`
base-modal (sm/md/lg/xl/full), contact-create-modal, keyboard-shortcuts-modal, profile-modal

### Advanced Query Builder
`src/presentation/components/custom-components/advance-query-builder/`
Filter components: dynamic-filter, field-selectors, operator-selectors, value-editors, filter-360, filter-management

### When Creating New Components
**Path**: `src/presentation/components/custom-components/{component-name}/`
- Create `index.tsx` with the component
- Export from parent barrel file
- Use Shadcn/Radix primitives for accessibility
- Follow Tailwind CSS conventions
- Support dark mode with `dark:` prefix
- Use `cn()` utility for conditional classes (`import { cn } from "@/lib/utils"`)

---

## 12. Hooks Catalog (31 hooks)

| Hook | Purpose |
|------|---------|
| `useAuth` | Authentication state, login, logout |
| `useAccessCapability` | Permission checking per menuCode |
| `useGenericQuery` | Wrapper for Apollo useQuery/useLazyQuery |
| `useGenericMutation` | Wrapper for Apollo useMutation |
| `useDebounce` | Debounce values (300ms for search) |
| `useMediaQuery` | Responsive breakpoints |
| `useMounted` | Hydration safety |
| `useNotification` | Notification fetch/count/toggle |
| `useThemeCustomizer` | Theme application |
| `useInitialRendering` | Menu, capabilities, user info setup |
| `useBreadcrumb` | Breadcrumb generation |
| `useCustomFields` | Custom field CRUD operations |
| `usePowerBI` | PowerBI embed integration |
| `useDynamicFilter` | Dynamic filtering |
| `use360DegreeFilter` | 360° aggregate filtering |
| `useValueSource` | Dynamic value sources for filters |
| `useImportSignalR` | Real-time import progress |
| `useImportSessionManager` | Import session state |

---

## 13. Design System Rules

### Tailwind CSS Conventions
- Use utility classes, not custom CSS
- Responsive: `sm:`, `md:`, `lg:`, `xl:`, `2xl:`
- Dark mode: `dark:` prefix
- Conditional classes: `cn("base-class", condition && "active-class")`

### Theme System
- CSS variables: `--primary`, `--secondary`, `--success`, `--warning`, `--destructive`, `--info`
- Shade scale: 50-950 per color
- Layout variants: default, semibox, horizontal
- Navbar: sticky, floating
- Footer: sticky, floating
- Border radius: configurable

### Typography
- Font: Plus Jakarta Sans (primary), system mono
- Consistent heading sizes via Tailwind `text-*` classes

### i18n
- Locales: `en`, `ar`, `bn`
- RTL support for Arabic via DirectionProvider
- All routes: `/[lang]/...`

---

## 14. Data Flow Lifecycle

```
1. Route → PageConfig component
2. useAccessCapability({ menuCode }) → permission gate
3. DataTable renders → Zustand store created per instance
4. useInitializeDataTableColumns() → GRID_BY_CODE_QUERY → columns, formSchemas
5. useInitializeDataTableDatas() → entity getAll query → populate data
6. DataTableContainer → TanStack table with dynamic columns
7. User actions:
   - Search: 300ms debounce → re-query
   - Sort/Filter/Page: immediate re-query
   - Add/Edit: RJSF modal → mutation → refresh
   - Delete: confirm → delete mutation → refresh
   - Toggle: toggle mutation → refresh
```

---

## 15. Wiring Checklist (Per New Entity — 6 updates)

1. **DTO barrel**: `domain/entities/{group}-service/index.ts` → add export
2. **Mutation barrel**: `gql-mutations/{group}-mutations/index.ts` → add before `//EntityMutationExport`
3. **Query barrel**: `gql-queries/{group}-queries/index.ts` → add before `//EntityQueryExport`
4. **PageConfig barrel**: `presentation/pages/{group}/{feFolder}/index.ts` → add before `//EntityPageConfigExport`
5. **Component barrel**: `page-components/{group}/{feFolder}/index.ts` → add before `//entity-parent-component-export`
6. **Operations config**: `data-table-configs/{group}-service-entity-operations.ts` → add entity block

---

## 16. File Path Reference

| File Type | Path Template |
|-----------|--------------|
| DTO | `domain/entities/{group}-service/{Entity}Dto.ts` |
| Query | `infrastructure/gql-queries/{group}-queries/{Entity}Queries.ts` |
| Mutation | `infrastructure/gql-mutations/{group}-mutations/{Entity}Mutations.ts` |
| PageConfig | `presentation/pages/{group}/{feFolder}/{entityLower}.tsx` |
| DataTable | `presentation/components/page-components/{group}/{feFolder}/{entityLower}-data-table.tsx` |
| Barrel | `presentation/components/page-components/{group}/{feFolder}/index.ts` |
| Route | `app/[lang]/(core)/{group}/{feFolder}/{entityLower}/page.tsx` |
| Store | `application/stores/{feature}-stores/{entity}-store.ts` |
| Operations | `application/configs/data-table-configs/{group}-service-entity-operations.ts` |

---

## 17. Error Pages
`src/presentation/error-page/`: 401, 403, 404, 419, 429, 500, 503, ComingSoon, Construction

---

## 18. Provider Hierarchy

```
Root Layout (fonts, globals)
  → [lang] Layout
    → AuthProvider (NextAuth SessionProvider, 5min refetch)
      → ApolloWrapper (GraphQL client, error handling)
        → Providers (Theme, Toast)
          → DirectionProvider (RTL/LTR)
            → MaintenanceProvider
              → (core) Layout
                → RouteGuard (auth required)
                  → RoleCapabilityProvider
                    → DashboardLayoutProvider
                      → [Page Components]
```
