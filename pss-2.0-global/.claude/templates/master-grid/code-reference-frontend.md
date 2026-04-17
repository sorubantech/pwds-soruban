# Frontend Code Reference — ContactType (MASTER_GRID Simple Entity)

> **ContactType is the canonical reference for MASTER_GRID screens.**
> Substitute: `ContactType` → `{EntityName}`, `ContactTypes` → `{PluralName}`, `contactType` → `{camelCase}`, `contacttype` → `{entityLower}`, `CONTACTTYPE` → `{GRIDCODE}`, `contact` → `{group}`, `crm/contact` → `{group}/{feFolder}`

---

## File 1 — DTO Types
`src/domain/entities/contact-service/ContactTypeDto.ts`
```typescript
export interface ContactTypeRequestDto {
  contactTypeId: number;
  contactTypeCode: string;
  contactTypeName: string;
  description: string;
  orderBy: number;
  // FK id fields: fkEntityId: number  (required) or fkEntityId?: number | null (optional)
}

export interface ContactTypeResponseDto extends ContactTypeRequestDto {
  isActive: boolean;
  // FK navigation DTOs: company?: CompanyRequestDto | null
}

export interface ContactTypeDto extends ContactTypeResponseDto {}
```
*`RequestDto` PK is plain `number` (not optional here — FE keeps it consistent). `ResponseDto` extends RequestDto + `isActive` + FK navigation objects.*

---

## File 2 — GraphQL Queries
`src/infrastructure/gql-queries/contact-queries/ContactTypeQuery.ts`
```typescript
import { gql } from "@apollo/client";

export const CONTACTTYPES_QUERY = gql`
query (
  $pageSize: Int!
  $pageIndex: Int!
  $sortDescending: Boolean
  $sortColumn: String
  $searchTerm: String
  $advancedFilter: QueryBuilderModelInput
) {
  result: contactTypes(
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
      contactTypeId
      contactTypeCode
      contactTypeName
      description
      orderBy
      isActive
    }
  }
}
`;

export const CONTACTTYPE_BY_ID_QUERY = gql`
  query ($contactTypeId: Int!) {
    result: contactTypeById(contactTypeId: $contactTypeId) {
      errorDetails
      message
      status
      success
      errorCode
      data {
        contactTypeId
        contactTypeCode
        contactTypeName
        description
        orderBy
      }
    }
  }
`;
```
*Query constants: plural `{ENTITY}S_QUERY` for GetAll, singular `{ENTITY}_BY_ID_QUERY` for GetById. Anonymous queries (no operation name). `result:` alias always. GetAll includes `isActive`; GetById does NOT.*

---

## File 3 — GraphQL Mutations
`src/infrastructure/gql-mutations/contact-mutations/ContactTypeMutation.ts`
```typescript
import { gql } from "@apollo/client";

export const CREATE_CONTACTTYPE_MUTATION = gql`
  mutation (
    $contactTypeId: Int
    $contactTypeCode: String!
    $contactTypeName: String!
    $description: String
    $orderBy: Int
  ) {
    result: createContactType(
      contactType: {
        contactTypeId: $contactTypeId
        contactTypeCode: $contactTypeCode
        contactTypeName: $contactTypeName
        description: $description
        orderBy: $orderBy
      }
    ) {
      errorCode
      errorDetails
      message
      status
      success
      data {
        contactTypeId
        contactTypeCode
        contactTypeName
        description
        orderBy
      }
    }
  }
`;

export const UPDATE_CONTACTTYPE_MUTATION = gql`
  mutation (
    $contactTypeId: Int!
    $contactTypeCode: String!
    $contactTypeName: String!
    $description: String
    $orderBy: Int
  ) {
    result: updateContactType(
      contactType: {
        contactTypeId: $contactTypeId
        contactTypeCode: $contactTypeCode
        contactTypeName: $contactTypeName
        description: $description
        orderBy: $orderBy
      }
    ) {
      errorCode
      errorDetails
      message
      status
      success
      data {
        contactTypeId
        contactTypeCode
        contactTypeName
        description
        orderBy
      }
    }
  }
`;

export const DELETE_CONTACTTYPE_MUTATION = gql`
  mutation ($contactTypeId: Int!) {
    result: deleteContactType(contactTypeId: $contactTypeId) {
      errorCode
      errorDetails
      message
      status
      success
      data {
        contactTypeId
      }
    }
  }
`;

export const ACTIVATE_DEACTIVATE_CONTACTTYPE_MUTATION = gql`
  mutation ($contactTypeId: Int!) {
    result: activateDeactivateContactType(contactTypeId: $contactTypeId) {
      errorCode
      errorDetails
      message
      status
      success
      data {
        contactTypeId
      }
    }
  }
`;
```
*Mutation constants: `CREATE_`, `UPDATE_`, `DELETE_`, `ACTIVATE_DEACTIVATE_` prefix + `{ENTITY}_MUTATION`. Create: PK is `Int` (no `!`). Update: PK is `Int!`. Response always includes `errorCode errorDetails message status success data { pkId }`.*

---

## File 4 — Page Config
`src/presentation/pages/crm/contact/contacttype.tsx`
```tsx
import { DefaultAccessDenied } from "@/presentation/components/custom-components/atoms/access-denied";
import { LayoutLoader } from "@/presentation/components/layout-components";
import { ContactTypeDataTable } from "@/presentation/components/page-components/crm/contact/contacttype";
import useAccessCapability from "@/presentation/hooks/useInitialRendering/useCapability";

export function ContactTypePageConfig() {
  const { capabilities, isReady, isLoading, error } = useAccessCapability({ menuCode: "CONTACTTYPE" });

  if (isLoading || !isReady) {
    return <LayoutLoader />;
  }

  if (!capabilities.canRead) {
    return <DefaultAccessDenied />;
  }

  return <ContactTypeDataTable />;
}
```
*`menuCode` must match the `MenuCode` in DB seed exactly. Import `DefaultAccessDenied` from `atoms/access-denied` (not `default-access-denied`).*

---

## File 5 — DataTable Component
`src/presentation/components/page-components/crm/contact/contacttype/data-table.tsx`
```tsx
"use client";
import { TDataTableConfigs } from "@/domain/types";
import { AdvancedDataTable } from "@/presentation/components/custom-components";

export function ContactTypeDataTable() {
  const initialPageIndex = 0;
  const initialPageSize = 10;
  const gridCode = "CONTACTTYPE";
  const tablePropertyConfig: TDataTableConfigs = {
    enableAdvanceFilter: true,
    enablePagination: true,
    enableAdd: true,
    enableImport: true,
    enableExport: true,
    enablePrint: true,
  };

  return (
    <AdvancedDataTable
      gridCode={gridCode}
      initialPageSize={initialPageSize}
      initialPageIndex={initialPageIndex}
      tableConfig={tablePropertyConfig}
    />
  );
}
```
*`gridCode` must match `GridCode` in DB seed exactly (ALLCAPS). Feature flags come from UX Architect's design.*

### File 5 — Variant B: Grid with Widgets/Summary Cards above

Use this when the mockup shows summary cards, KPI widgets, or any custom content ABOVE the data grid.
In this variant, the header+breadcrumbs are rendered **outside** the grid using `<ScreenHeader>`, 
and the grid is rendered with `showHeader={false}` to avoid duplicate headers.

**Architecture:**
```
┌─────────────────────────────────────────┐
│  ScreenHeader (title, breadcrumbs)      │ ← Rendered by the page component
├─────────────────────────────────────────┤
│  Summary Widgets / KPI Cards            │ ← Custom widget component
├─────────────────────────────────────────┤
│  DataTableContainer showHeader={false}  │ ← Grid without its own header
└─────────────────────────────────────────┘
```

```tsx
"use client";

import { useGlobalStore } from "@/application/stores";
import { IBreadcrumbItem } from "@/application/stores/component-stores/breadcrumb-store";
import { TDataTableConfigs } from "@/domain/types";
import {
  AdvancedDataTableProvider,
  DataTableContainer,
  useInitializeAdvancedDataTableColumns,
  useInitializeAdvancedDataTableData,
} from "@/presentation/components/custom-components";
import { ScreenHeader } from "@/presentation/components/custom-components/page-header";
import { useAdvancedDataTableStoreFromContext } from "@/presentation/components/custom-components/data-tables/advanced/datatable-context";
import { cn } from "@/presentation/utils";
import { usePathname } from "next/navigation";
import * as React from "react";
import { EntitySummaryWidgets } from "./entity-summary";

const tablePropertyConfig: TDataTableConfigs = {
  enableAdvanceFilter: true,
  enablePagination: true,
  enableAdd: true,
  enableImport: true,
  enableExport: true,
  enablePrint: true,
  enableFullScreenMode: true,
};

export function EntityDataTable() {
  return (
    <AdvancedDataTableProvider
      gridCode="ENTITYUPPER"
      initialPageSize={10}
      initialPageIndex={0}
      tableConfig={tablePropertyConfig}
    >
      <EntityDataTableContent />
    </AdvancedDataTableProvider>
  );
}

function EntityDataTableContent() {
  const { error: columnsError } = useInitializeAdvancedDataTableColumns();
  const { error: dataError } = useInitializeAdvancedDataTableData();

  const gridInfo = useAdvancedDataTableStoreFromContext(state => state.gridInfo);
  const loading = useAdvancedDataTableStoreFromContext(state => state.loading);
  const fullScreenMode = useAdvancedDataTableStoreFromContext(state => state.fullScreenMode);
  const setFullScreenMode = useAdvancedDataTableStoreFromContext(state => state.setFullScreenMode);
  const tableConfig = useAdvancedDataTableStoreFromContext(state => state.tableConfig);

  const moduleName = useGlobalStore(state => state.moduleName);
  const moduleUrl = useGlobalStore(state => state.moduleUrl);
  const menuName = useGlobalStore(state => state.menuName);

  const pathname = usePathname();
  const lang = pathname.split("/")[1] || "en";
  const moduleHref = moduleUrl
    ? `/${lang}${moduleUrl.startsWith("/") ? moduleUrl : `/${moduleUrl}`}`
    : undefined;

  const breadcrumbs: IBreadcrumbItem[] = [
    { id: "home", label: "Home", href: `/${lang}/masterdashboard`, icon: "solar:home-line-duotone", tooltip: "Go to master dashboard" },
    ...(moduleName ? [{ id: "module", label: moduleName, href: moduleHref, tooltip: `Go to ${moduleName} dashboard` }] : []),
    ...(menuName ? [{ id: "menu", label: menuName, tooltip: `Stay on ${menuName} Screen` }] : []),
  ];

  React.useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape" && fullScreenMode) setFullScreenMode(false);
    };
    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [fullScreenMode, setFullScreenMode]);

  return (
    <div className={cn(
      "flex flex-col w-full max-w-full h-full transition-all duration-300 ease-in-out overflow-x-hidden",
      fullScreenMode && "fixed inset-0 z-[100] bg-background overflow-hidden p-2 sm:p-4"
    )}>
      {/* Screen Header - separated from grid */}
      <ScreenHeader
        title={gridInfo?.gridName}
        description={gridInfo?.description}
        breadcrumbs={breadcrumbs}
        loading={loading}
        enableFullScreenMode={tableConfig?.enableFullScreenMode}
        fullScreenMode={fullScreenMode}
        onFullScreenToggle={() => setFullScreenMode(!fullScreenMode)}
        headerActions={null}
      />

      {/* Summary Widgets - between header and grid */}
      <div className="mb-3">
        <EntitySummaryWidgets />
      </div>

      {/* Grid without its own header */}
      <DataTableContainer showHeader={false} />
    </div>
  );
}
```

**When to use which variant:**
| Mockup has... | Use | showHeader |
|---------------|-----|------------|
| Grid only (no widgets above) | Variant A: `<AdvancedDataTable>` | `true` (default, handled internally) |
| Grid + widgets/cards above | Variant B: `<ScreenHeader>` + widgets + `<DataTableContainer showHeader={false}>` | `false` |

---

## File 6 — Component Barrel
`src/presentation/components/page-components/crm/contact/contacttype/index.ts`
```typescript
export { ContactTypeDataTable } from "./data-table";
```

---

## File 7 — Route Page
`src/app/[lang]/crm/contact/contacttype/page.tsx`
```tsx
"use client";
import { ContactTypePageConfig } from "@/presentation/pages/crm";

export default function ContactType() {
  return <ContactTypePageConfig />;
}
```
*Route folder is `contacttype` (entity name lowercase, no hyphens). Import PageConfig from the `{group}` barrel (e.g., `@/presentation/pages/crm`).*
