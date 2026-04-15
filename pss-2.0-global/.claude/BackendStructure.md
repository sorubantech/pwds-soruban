# PSS 2.0 Backend — Complete Technical Reference

**Stack**: .NET 8 | Clean Architecture | CQRS (MediatR) | GraphQL (HotChocolate) | PostgreSQL (EF Core) | Mapster | FluentValidation

**Root Path**: `Pss2.0_Backend/PeopleServe/Services/Base/`

---

## 1. Project Structure

```
Base.Domain/          → Entity models, abstractions, events, exceptions
Base.Application/     → CQRS handlers, validators, DTOs, mappings, services
Base.Infrastructure/  → EF Core, DbContexts, configurations, interceptors, repositories
Base.API/             → GraphQL endpoints, DI, middleware, filters
Base.Support/         → Email, import, search engine services
```

---

## 2. Base Entity Class

All entities inherit from `Entity`:
```csharp
public abstract class Entity : IEntity
{
    public int? CreatedBy { get; set; }
    public DateTime? CreatedDate { get; set; } = DateTime.Now;
    public int? ModifiedBy { get; set; }
    public DateTime? ModifiedDate { get; set; }
    public bool? IsActive { get; set; } = true;
    public bool? IsDeleted { get; set; } = false;
}
```
**NEVER include these audit columns in entity definitions** — they are inherited.

---

## 3. CQRS Pattern

### Command (Write)
```csharp
[CustomAuthorize(DecoratorGroupModules.Entity, Permissions.Create)]
public record CreateEntityCommand(EntityRequestDto entity) : ICommand<CreateEntityResult>;
public record CreateEntityResult(EntityRequestDto entity);
```

### Query (Read)
```csharp
[CustomAuthorize(DecoratorGroupModules.Entity, Permissions.Read)]
public record GetEntitiesQuery(GridFeatureRequest gridFilterRequest) : IQuery<GetEntitiesResult>;
public record GetEntitiesResult(GridFeatureResult<EntityResponseDto> entities);
```

### Pipeline Behaviors (execution order)
1. `TenantIsolationBehavior` — Validates tenant context
2. `AuthorizationBehavior` — Checks [CustomAuthorize] permissions
3. `TenantAccessBehavior` — Enforces [TenantScope]
4. `CommandValidationBehavior` — FluentValidation for commands
5. `QueryValidationBehavior` — FluentValidation for queries
6. `LoggingBehavior` — Performance logging (warns >3 sec)

---

## 4. Validation Framework

### BaseCommandFluentValidator Methods

| Method | Purpose | When to Use |
|--------|---------|-------------|
| `ValidatePropertyIsRequired(x => x.dto.Field)` | Non-null/non-empty | Required fields |
| `ValidateStringLength(x => x.dto.Field, maxLen)` | Max string length | All strings with MaxLen |
| `ValidateUniqueWhenCreate(x => x.dto.Field, dbSet, selector)` | Unique on create | UniqueKey fields |
| `ValidateUniqueWhenUpdate(x => x.dto.Field, x => x.dto.Id, dbSet, selector, keySelector)` | Unique excluding self | UniqueKey in Update |
| `ValidateUniqueByMultipleFields(...)` | Composite unique | Multi-field uniqueness |
| `ValidateFilteredCompositeUniqueness(...)` | Scoped unique | Unique per company/parent |
| `ValidateForeignKeyRecord(x => x.dto.FKId, dbSet, selector)` | Optional FK exists | Nullable FK fields |
| `FindRecordByProperty(x => x.dto.Id, dbSet, selector)` | Required FK / exists | Update PK check |
| `FindInActiveRecordByProperty(x => x.dto.Id, dbSet, selector)` | Active record exists | Delete/Toggle commands |
| `ValidateStringIsInAllowedValues(x => x.dto.Field, values)` | Enum validation | Restricted string values |
| Custom `RuleFor().When()` | Conditional validation | Cross-field rules |
| Custom `RuleFor().EmailAddress()` | Email format | Email fields |
| Custom `RuleFor().Must(lambda)` | Business rules | Custom logic |

### BaseQueryFluentValidator Methods

| Method | Purpose |
|--------|---------|
| `ValidateGridFeatures(x => x.gridFilterRequest, validSortColumns)` | Pagination/sort/filter |
| `ValidateGridFeatures(..., aggregateFields, collectionMapping)` | 360° aggregate filters |

---

## 5. DTO Pattern

```csharp
// Input DTO: all mutable fields
public class EntityRequestDto {
    public int EntityId { get; set; }
    public string EntityName { get; set; }
    public int? FKId { get; set; }
}

// Response DTO: adds IsActive + FK display names
public class EntityResponseDto : EntityRequestDto {
    public bool IsActive { get; set; }
    public string? FKEntityName { get; set; }  // navigation display
}

// Extended DTO
public class EntityDto : EntityResponseDto { }
```

---

## 6. Entity Configuration (EF Core)

```csharp
// Primary Key + Auto-increment
builder.HasKey(c => c.EntityId);
builder.Property(c => c.EntityId).UseIdentityAlwaysColumn().ValueGeneratedOnAdd();

// Required string
builder.Property(c => c.Name).HasMaxLength(100).IsRequired();

// Optional string
builder.Property(c => c.Description).HasMaxLength(500);

// FK Relationship
builder.HasOne(o => o.Country)
    .WithMany(p => p.Companies)
    .HasForeignKey(o => o.CountryId)
    .OnDelete(DeleteBehavior.Restrict);

// Unique index
builder.HasIndex(o => o.EntityCode).IsUnique();

// Composite unique
builder.HasIndex(o => new { o.CompanyId, o.Code, o.IsActive }).IsUnique();
```

---

## 7. Handler Patterns

### Create Handler
```csharp
public class CreateEntityHandler(IApplicationDbContext dbContext, IPublishEndpoint publishEndpoint)
    : ICommandHandler<CreateEntityCommand, CreateEntityResult>
{
    public async Task<CreateEntityResult> Handle(CreateEntityCommand command, CancellationToken ct)
    {
        var entity = command.dto.Adapt<Domain.Models.GroupModels.Entity>();
        try {
            dbContext.Entities.Add(entity);
            await dbContext.SaveChangesAsync(ct);
            return new CreateEntityResult(entity.Adapt<EntityRequestDto>());
        }
        catch (DbUpdateException ex) { throw new InternalServerException("Database operation failed: " + ex.Message); }
        catch (Exception ex) { throw new InternalServerException("An unexpected error occurred: " + ex.Message); }
    }
}
```

### Update Handler
```csharp
var entity = await dbContext.Entities.FindAsync([command.dto.EntityId], cancellationToken: ct);
if (entity is null) throw new NotFoundException($"EntityId {command.dto.EntityId} not found.");
command.dto.Adapt(entity);  // map onto existing
await dbContext.SaveChangesAsync(ct);
```

### Delete Handler (Soft Delete)
```csharp
entity.IsDeleted = true;
dbContext.Entities.Update(entity);
await dbContext.SaveChangesAsync(ct);
```

### Toggle Handler
```csharp
entity.IsActive = !entity.IsActive;
dbContext.Entities.Update(entity);
await dbContext.SaveChangesAsync(ct);
return new ToggleResult(entity.IsActive ?? false);
```

### GetAll Handler
```csharp
var baseQuery = dbContext.Entities
    .Where(x => x.IsDeleted == false)
    .OrderByDescending(x => x.CreatedDate)
    .AsQueryable();

var filteredQuery = baseQuery;
if (!string.IsNullOrEmpty(searchTerm))
{
    filteredQuery = filteredQuery.Where(c =>
        (!string.IsNullOrEmpty(c.EntityName) && c.EntityName.ToLower().Contains(searchTerm))
        // Add FK navigation search: || c.FKEntity.FKName.ToLower().Contains(searchTerm)
    );
}

var gridResult = await CommonExtension.ApplyGridFeatures<Entity, EntityResponseDto>(
    baseQuery, filteredQuery, query.gridFilterRequest, ct);
```

### GetById Handler
```csharp
var entity = await CommonExtension.ApplyEntityQuery<Entity, EntityResponseDto>(
    dbContext.Entities.AsNoTracking(),
    o => o.EntityId.Equals(query.entityId) && o.IsDeleted == false, ct);
```

---

## 8. GraphQL Endpoints

### Mutations
```csharp
[ExtendObjectType(OperationTypeNames.Mutation)]
public class EntityMutations : IMutations
{
    // CreateEntity → mediator.Send(CreateCommand) → BaseApiResponse.PostSuccess/PostError
    // UpdateEntity → mediator.Send(UpdateCommand) → BaseApiResponse.PutSuccess/PutError
    // ActivateDeactivateEntity → mediator.Send(ToggleCommand) → ActivateDeactivateSuccess
    // DeleteEntity → mediator.Send(DeleteCommand) → DeleteSuccess/DeleteError
}
```

### Queries
```csharp
[ExtendObjectType(OperationTypeNames.Query)]
public class EntityQueries : IQueries
{
    // GetEntities([AsParameters] GridFeatureRequest) → PaginatedApiResponse
    // GetEntityById(int entityId) → BaseApiResponse
}
```

---

## 9. Response Models

```csharp
BaseApiResponse<T>: Status, Success, Data, ErrorCode, ErrorDetails, Message
PaginatedApiResponse<T>: extends above + PageIndex, PageSize, TotalCount, FilteredCount

// Helpers:
BaseApiResponse<T>.PostSuccess(data)        // 201
BaseApiResponse<T>.PutSuccess(data)         // 200
BaseApiResponse<T>.DeleteSuccess()          // 200
BaseApiResponse<T>.ActivateDeactivateSuccess(message)
BaseApiResponse<T>.Error(message)           // 400
ApiResponseHelper.ReturnPaginatedApiResponse(gridResult)
ApiResponseHelper.ReturnObjectApiResponse(entity)
```

---

## 10. Authorization System

### Decorator Properties
```csharp
// Each module group has a static class:
public static class DecoratorApplicationModules {
    public const string Company = "COMPANY", Branch = "BRANCH", Staff = "STAFF" ...
}
public static class DecoratorAuthModules { ... }
public static class DecoratorSharedModules { ... }
// etc.

// Permissions:
public static class Permissions {
    public const string Read = "READ", Create = "CREATE", Modify = "MODIFY",
        Delete = "DELETE", Toggle = "TOGGLE", Import = "IMPORT", Export = "EXPORT",
        Download = "DOWNLOAD", Dropdown = "DROPDOWN";
}
```

### Usage on Commands/Queries
```csharp
[CustomAuthorize(DecoratorGroupModules.EntityName, Permissions.Create)]
```

---

## 11. Multi-Tenancy

### Attributes
- `[TenantScope(TenantScopeType.Current)]` — Current company only
- `[TenantScope(TenantScopeType.Dynamic)]` — Dynamic resolution
- `[TenantScope(TenantScopeType.Global)]` — No tenant filter (reference data)
- `[RequiresTenant]` — Tenant context required
- `[AutoScope]` — Implements IAutoScope

### In Handlers
```csharp
int companyId = _httpContextAccessor.GetCurrentUserStaffCompanyId();
baseQuery = scopeHelper.ApplyCompanyScope(baseQuery, command.CompanyScope, command.RestrictedCompanyIds);
```

### Interceptors
- **AuditableEntityInterceptor**: Sets CreatedBy/Date, ModifiedBy/Date, case formatting
- **TenantSaveChangesInterceptor**: Auto-stamps CompanyId on inserts, blocks changes on existing
- **DispatchDomainEventsInterceptor**: Publishes domain events after SaveChanges

---

## 12. Mapping (Mapster)

```csharp
// Standard bidirectional (in {Group}Mappings.cs):
TypeAdapterConfig<Entity, EntityRequestDto>.NewConfig();
TypeAdapterConfig<EntityRequestDto, Entity>.NewConfig();
TypeAdapterConfig<Entity, EntityResponseDto>.NewConfig();
TypeAdapterConfig<EntityResponseDto, Entity>.NewConfig();
TypeAdapterConfig<Entity, EntityDto>.NewConfig();

// Custom mapping for FK display names:
TypeAdapterConfig<Entity, EntityResponseDto>.NewConfig()
    .Map(dest => dest.CountryName, src => src.Country != null ? src.Country.CountryName : null);
```

---

## 13. Module DbContext Architecture

| Module | Interface | Implementation | Schema |
|--------|-----------|----------------|--------|
| Application | IApplicationDbContext | ApplicationDbContext | app |
| Auth | IAuthDbContext | AuthDbContext | auth |
| Setting | ISettingDbContext | SettingDbContext | sett |
| Shared | ISharedDbContext | SharedDbContext | com |
| Notify | INotifyDbContext | NotifyDbContext | notify |
| Report | IReportDbContext | ReportDbContext | rep |
| Contact | IContactDbContext | ContactDbContext | corg |
| Donation | IDonationDbContext | DonationDbContext | fund |
| Audit | IAuditDbContext | AuditDbContext | audit |
| Import | IImportDbContext | ImportDbContext | import |
| Public | IPublicDbContext | PublicDbContext | public |

**IApplicationDbContext** inherits all module interfaces. All handlers inject `IApplicationDbContext`.

---

## 14. Backend Services & Features

### Hangfire (Background Jobs)
- **Queues**: "default" (general), "emails" (SendGrid)
- **Workers**: 5 concurrent
- **Used for**: Import validation, import execution, bulk email sending
- **Pattern**: `BackgroundJob.Enqueue(() => service.ExecuteAsync(id))`

### Email Service (SendGrid)
- **Factory pattern**: EmailProviderFactory (extensible)
- **Bulk pipeline**: DataFetch → PlaceholderRender → ParallelSend
- **Webhook tracking**: Delivery, open, click, bounce, spam events
- **Per-company config**: CompanyEmailProvider + CompanyEmailConfiguration

### File Storage (Azure Blob)
- **Factory**: IFileStorageServiceFactory (Internal or AzureBlob)
- **Pattern**: Separate command for file ops + IFileStorageServiceRequest + IHttpContextAccessor
- **Company-scoped paths**: Files stored under company directory

### SignalR (Real-Time)
- **Hub**: ImportProgressHub at `/hubs/import-progress`
- **Events**: ValidationStarted, ValidationProgress, ImportProgress, ImportCompleted, ImportFailed
- **Groups**: `import-{sessionId}` for session-specific updates

### Elasticsearch (Search)
- **Interface**: ISearchService, ISearchRepository
- **Models**: SearchRequest, SearchResponse, GroupedSearchResponse

### PowerBI (Reports)
- **Service**: IPowerBIEmbedService
- **Features**: Token generation, embed config, user mapping, access logging

### Import Pipeline
- **3 stages**: Upload/Parse → Validate (Hangfire) → Execute (Hangfire)
- **Progress**: SignalR real-time updates
- **Batch processing**: 1000 rows validation, 500 rows import per commit
- **Stored procedures**: Bulk validation and data processing

---

## 15. Exception Types

```csharp
BadRequestException(message)          // 400
NotFoundException(message)            // 404 — "EntityId {id} not found"
ForbiddenAccessException              // 403
InternalServerException(message)      // 500
ValidationException(failures)         // 400 — FluentValidation
```

---

## 16. Grid Feature System

### Request
```csharp
GridFeatureRequest(
    int pageIndex = 0, int pageSize = 10,
    string? searchTerm = "", string? sortColumn = null, bool? sortDescending = false,
    QueryBuilderModel? advancedFilter = null,
    QueryBuilderModel? aggregationFilter = null  // 360° filtering
)
```

### Advanced Filtering (QueryBuilderModel)
```csharp
QueryBuilderModel { string Combinator ("and"/"or"), List<Rule> Rules }
Rule { string Field, string Operator, string Value, string DataType,
       bool Is360DegreeRule, bool IsAggregate, string AggregationType,
       string CollectionPath, List<Rule> ContextFilters }
```

### 360° Aggregation
Filter parent entities by child collection aggregates:
- `SUM`, `COUNT`, `AVG`, `MAX`, `MIN`, `DISTINCT_COUNT`
- Example: Contacts where SUM(Donations.Amount) > 10000

---

## 17. Wiring Checklist (Per New Entity)

### Existing Module (4 updates)
1. **IApplicationDbContext**: `DbSet<Entity> Entities { get; }` before `//IDbContextLines`
2. **{Group}DbContext**: `public DbSet<Entity> Entities => Set<Entity>();`
3. **DecoratorProperties**: `, EntityName = "ENTITYNAME"` before `//DecoratorProperties{Group}Lines`
4. **{Group}Mappings**: 5 TypeAdapterConfig pairs

### New Module (additional)
5. Create `I{Group}DbContext.cs` in Base.Application/Data/Persistence/
6. Create `{Group}DbContext.cs` in Base.Infrastructure/Data/Persistence/
7. Create `{Group}Mappings.cs` in Base.Application/Mappings/
8. Add `I{Group}DbContext` to IApplicationDbContext inheritance
9. Register `{Group}Mappings.ConfigureMappings()` in DependencyInjection.cs
10. Update GlobalUsing.cs (3 files: API, Application, Infrastructure)

---

## 18. File Path Reference

| File Type | Path Template |
|-----------|--------------|
| Entity | `Base.Domain/Models/{Group}Models/{Entity}.cs` |
| Configuration | `Base.Infrastructure/Data/Configurations/{Group}Configurations/{Entity}Configurations.cs` |
| DTOs/Schemas | `Base.Application/Schemas/{Group}Schemas/{Entity}Schemas.cs` |
| Create Command | `Base.Application/Business/{Group}Business/{Plural}/Commands/Create{Entity}.cs` |
| Update Command | `Base.Application/Business/{Group}Business/{Plural}/Commands/Update{Entity}.cs` |
| Delete Command | `Base.Application/Business/{Group}Business/{Plural}/Commands/Delete{Entity}.cs` |
| Toggle Command | `Base.Application/Business/{Group}Business/{Plural}/Commands/Toggle{Entity}.cs` |
| GetAll Query | `Base.Application/Business/{Group}Business/{Plural}/Queries/Get{Plural}.cs` |
| GetById Query | `Base.Application/Business/{Group}Business/{Plural}/Queries/Get{Entity}ById.cs` |
| Mutations | `Base.API/EndPoints/{Group}/Mutations/{Entity}Mutations.cs` |
| Queries | `Base.API/EndPoints/{Group}/Queries/{Entity}Queries.cs` |
| DB Seed | `sql-scripts-dyanmic/{Entity}-sqlscripts.sql` |

---

## 19. DB Seed Script (mandatory for new screens)

**Path:** `sql-scripts-dyanmic/{Entity}-sqlscripts.sql`
**Templates:** `.claude/templates/menucreation.sql` + `.claude/templates/menucreation-details.md`

Every new screen needs these SQL inserts:

| Step | Table | Purpose | Always? |
|------|-------|---------|---------|
| 1 | auth.Menus | Navigation menu entry | Yes |
| 2 | auth.MenuCapabilities | Link menu to capability codes (READ, CREATE, MODIFY, etc.) | Yes |
| 3 | auth.RoleCapabilities | Grant capabilities per role (SUPERADMIN, BUSINESSADMIN, etc.) | Yes |
| 4 | sett.Grids | Grid registration (GridCode, GridTypeId=1) | Yes |
| 5 | sett.Fields | One row per field (FieldCode=UPPER, FieldKey=camelCase) | Yes |
| 6 | sett.GridFields | Map fields to grid with full config (visibility, order, ParentObject for FKs) | Yes |
| 7 | sett.Grids GridFormSchema | JSON Schema + uiSchema for RJSF form | Master tables only |

**7 Roles:** SUPERADMIN, BUSINESSADMIN, ADMINISTRATOR, STAFF, STAFFDATAENTRY, STAFFCORRESPONDANCE, SYSTEMROLE
**17 Capabilities:** DELETE, EXPORT, IMPORT, CREATE, READ, TOGGLE, MODIFY, LAYOUTBUILDER, ROLECAPABILITYEDITOR, DROPDOWN, ROLEWIDGETEDITOR, ROLEREPORTEDITOR, ISMENURENDER, PRINT, AUTOREFRESH, MANUALREFRESH, ROLEHTMLREPORTEDITOR
**DataType codes:** integer→INT | string→STRING | boolean→BOOL | timestamp→DATETIME | decimal→DECIMAL

**GridFields.ParentObject**: Set to FK navigation property name (e.g., 'company', 'currency') for FK fields — grid displays the entity name instead of raw ID.

**AI self-decisions:** Visibility, predefined, order based on business importance. Role-capability mapping based on screen type.

---

## 20. SQL Type Mapping

| PostgreSQL | C# | Required | Optional |
|------------|-----|----------|----------|
| integer | int | int | int? |
| character varying(n) | string | string | string? |
| text | string | string | string? |
| boolean | bool | bool | bool? |
| timestamp with time zone | DateTime | DateTime | DateTime? |
| numeric/decimal | decimal | decimal | decimal? |
