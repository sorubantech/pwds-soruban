# Screen #179 PlanEmailProviderSetting — Migration Handoff (USER-OWNED)

Paste the `Sql()` calls below into the `Up()` / `Down()` of the two EF Core migrations you generate
for `PlatformEmailAccountAssignment` and `TenantEmailDomainRequest` (`dotnet ef migrations add`).
These are the **partial** unique indexes that cannot be expressed in Fluent `IEntityTypeConfiguration`
with a WHERE clause in this codebase's EF Core version — they are added as raw PostgreSQL via
`migrationBuilder.Sql()` immediately after the corresponding `CreateTable` call.

Do not run `dotnet ef migrations add` or edit `ModelSnapshot` from an agent session — this file is
the handoff artifact for the human running that step.

---

## Migration 1 — `PlatformEmailAccountAssignments`

One live assignment per tenant, and one live assignment per plan (soft-deleted rows don't count).

### Up()

```csharp
migrationBuilder.Sql(@"
    CREATE UNIQUE INDEX ""IX_PlatformEmailAccountAssignments_CompanyId_Filtered""
    ON ops.""PlatformEmailAccountAssignments"" (""CompanyId"")
    WHERE ""CompanyId"" IS NOT NULL AND ""IsDeleted"" = false;
");

migrationBuilder.Sql(@"
    CREATE UNIQUE INDEX ""IX_PlatformEmailAccountAssignments_PlanId_Filtered""
    ON ops.""PlatformEmailAccountAssignments"" (""PlanId"")
    WHERE ""PlanId"" IS NOT NULL AND ""IsDeleted"" = false;
");
```

### Down()

```csharp
migrationBuilder.Sql(@"DROP INDEX IF EXISTS ops.""IX_PlatformEmailAccountAssignments_CompanyId_Filtered"";");
migrationBuilder.Sql(@"DROP INDEX IF EXISTS ops.""IX_PlatformEmailAccountAssignments_PlanId_Filtered"";");
```

---

## Migration 2 — `TenantEmailDomainRequests`

One live request per `(CompanyId, RequestType, lower(RequestedDomain))` while the request is still
open (`PENDING` or `DNSISSUED`) — prevents a tenant flooding the queue with duplicate domain requests.
Uses `lower(...)` for case-insensitive domain comparison; `RequestedDomain` can be NULL for
`FROMEMAIL`-type requests, and NULL never conflicts with NULL in a unique index, which is the
intended behaviour here (the dedup rule only applies to DOMAIN requests).

### Up()

```csharp
migrationBuilder.Sql(@"
    CREATE UNIQUE INDEX ""IX_TenantEmailDomainRequests_Company_Type_Domain_Open""
    ON ops.""TenantEmailDomainRequests"" (""CompanyId"", ""RequestType"", lower(""RequestedDomain""))
    WHERE ""Status"" IN ('PENDING','DNSISSUED') AND ""IsDeleted"" = false;
");
```

### Down()

```csharp
migrationBuilder.Sql(@"DROP INDEX IF EXISTS ops.""IX_TenantEmailDomainRequests_Company_Type_Domain_Open"";");
```

---

## Notes

- Both entities implement `IControlPlaneEntity` (`Base.Domain/Models/SharedModels/IControlPlaneEntity.cs`)
  so `ApplicationDbContext.ApplyTenantFilters` skips them despite carrying a `CompanyId` column —
  verify the generated migration's `Up()` does NOT include any query-filter-related SQL for these
  tables (there shouldn't be any; query filters are a runtime EF concept, not a schema object, but
  double-check the migration diff is clean of anything referencing `CurrentTenantId` for these tables).
- The `HasCheckConstraint` calls in `PlatformEmailAccountAssignmentConfiguration` (XOR CompanyId/PlanId)
  and `TenantEmailDomainRequestConfiguration` (RequestType / Status enums) are already Fluent-config
  and will be picked up automatically by `dotnet ef migrations add` — no manual `Sql()` needed for those.
