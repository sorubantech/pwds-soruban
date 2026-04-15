# Backend Code Reference — SavedFilter (FLOW Grid Entity)

> **SavedFilter is the canonical reference for FLOW screens.**
> Substitute: `SavedFilter` → `{EntityName}`, `SavedFilters` → `{PluralName}`, `savedFilter` → `{camelCase}`, `SAVEDFILTER` → `{GRIDCODE}`, `notify` → `{schema}`, `NotifyBusiness` → `{Group}Business`, `DecoratorNotifyModules` → `Decorator{Group}Modules`

---

## Key Differences from MASTER_GRID (ContactType)

| Aspect | MASTER_GRID (ContactType) | FLOW (SavedFilter) |
|--------|---------------------------|---------------------|
| GridTypeCode | `MASTER_GRID` | `FLOW` |
| Parent form | RJSF modal (GridFormSchema) | React Hook Form on view page |
| GridFormSchema | Generated in DB seed | NOT generated for parent (only for child grids if needed) |
| Grid click | Opens modal | Navigates to view page (`?mode=edit&id=N`) |
| Child entities | None | May have child grids (tabs/sections) |
| CompanyId handling | Tenant interceptor auto-stamps | Handler reads from HttpContext explicitly |
| GetById includes | Basic entity | FK navigations via `.Include()` for view page display |
| FE page structure | DataTable component only | DataTable + ViewPage + Store |

**Backend CRUD code is nearly identical.** The main differences are:
1. CompanyId set explicitly in CreateHandler via `httpContextAccessor.GetCurrentUserStaffCompanyId()`
2. GetAll/GetById queries include FK navigation properties via `.Include()`
3. DB seed uses `FLOW` GridType and skips parent GridFormSchema

---

## File 1 — Entity
`Base.Domain/Models/NotifyModels/SavedFilter.cs`
```csharp
namespace Base.Domain.Models.NotifyModels;

[Table("SavedFilters", Schema = "notify")]
public class SavedFilter : Entity
{
    public int SavedFilterId { get; set; }
    public int CompanyId { get; set; }
    public int OrganizationalUnitId { get; set; }
    public int FilterRecipientTypeId { get; set; }
    public string FilterName { get; set; } = default!;
    public string FilterCode { get; set; } = default!;
    public string? Description { get; set; }
    public string? FilterJson { get; set; }
    public string? AggregationFilterJson { get; set; }
    public int? RecordSourceTypeId { get; set; }

    // FK navigation properties
    public Company Company { get; set; } = default!;
    public OrganizationalUnit OrganizationalUnit { get; set; } = default!;
    public MasterData FilterRecipientType { get; set; } = default!;
    public MasterData? RecordSourceType { get; set; }

    // Child collections
    public ICollection<EmailSendJob> EmailSendJobs { get; set; } = default!;
    //EntityIcollection
}
```
*`Entity` base provides IsActive, IsDeleted, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate — never redeclare these.*

**FLOW-specific notes:**
- `CompanyId` is NOT in RequestDto — set by handler from HttpContext (tenant auto-assignment)
- FK navigation properties for entities displayed on the view page
- Optional FKs use nullable types (`int?` for RecordSourceTypeId)
- Required FKs use non-nullable (`int` for CompanyId, OrganizationalUnitId, FilterRecipientTypeId)

---

## File 2 — EF Configuration
`Base.Infrastructure/Data/Configurations/NotifyConfigurations/SavedFilterConfiguration.cs`
```csharp
namespace Base.Infrastructure.Data.Configurations.NotifyConfigurations;

public class SavedFilterConfigurations : IEntityTypeConfiguration<SavedFilter>
{
    public void Configure(EntityTypeBuilder<SavedFilter> builder)
    {
        builder.HasKey(c => c.SavedFilterId);
        builder.Property(c => c.SavedFilterId).UseIdentityAlwaysColumn().ValueGeneratedOnAdd();

        // FK relationships
        builder.HasOne(o => o.Company).WithMany(p => p.SavedFilters).HasForeignKey(o => o.CompanyId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(o => o.OrganizationalUnit).WithMany(p => p.SavedFilters).HasForeignKey(o => o.OrganizationalUnitId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(o => o.FilterRecipientType).WithMany(p => p.FilterRecipientTypes).HasForeignKey(o => o.FilterRecipientTypeId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(o => o.RecordSourceType).WithMany(p => p.SavedFilterRecordSourceTypes).HasForeignKey(o => o.RecordSourceTypeId)
            .OnDelete(DeleteBehavior.Restrict);

        // String constraints
        builder.Property(c => c.FilterName).HasMaxLength(100).IsRequired();
        builder.Property(c => c.FilterCode).HasMaxLength(100).IsRequired();
        builder.Property(c => c.Description).HasMaxLength(1000);
    }
}
```

---

## File 3 — Schemas / DTOs
`Base.Application/Schemas/NotifySchemas/SavedFilterSchemas.cs`
```csharp
namespace Base.Application.Schemas.NotifySchemas;

public class SavedFilterRequestDto
{
    public int? SavedFilterId { get; set; }
    public int OrganizationalUnitId { get; set; }
    public string FilterName { get; set; } = default!;
    public string FilterCode { get; set; } = default!;
    public string? Description { get; set; }
    public string? FilterJson { get; set; }
    public string? AggregationFilterJson { get; set; }
    public int FilterRecipientTypeId { get; set; }
}

public class SavedFilterResponseDto : SavedFilterRequestDto
{
    public bool IsActive { get; set; }
    public OrganizationalUnitRequestDto? OrganizationalUnit { get; set; }
}

public class SavedFilterDto : SavedFilterResponseDto { }
```

**FLOW-specific DTO notes:**
- `CompanyId` excluded from RequestDto — auto-stamped by handler via tenant context
- ResponseDto includes **FK navigation DTOs** (not flat strings) for view page display
  - `OrganizationalUnit` is included as a full DTO object, not just `OrganizationalUnitName` string
- For FLOW screens, ResponseDto typically nests FK DTOs as objects for richer view page display
- PK in RequestDto is `int?` (nullable — not set on create)

**FLOW ResponseDto pattern — FK as navigation DTO vs flat string:**
```csharp
// MASTER_GRID pattern: flat FK display name
public class ContactTypeResponseDto : ContactTypeRequestDto
{
    public bool IsActive { get; set; }
    public CompanyRequestDto? Company { get; set; }     // navigation DTO
}

// FLOW pattern: navigation DTOs for view page display
public class SavedFilterResponseDto : SavedFilterRequestDto
{
    public bool IsActive { get; set; }
    public OrganizationalUnitRequestDto? OrganizationalUnit { get; set; }  // navigation DTO
}
```
*Both patterns use navigation DTOs. The key difference is FLOW screens consume more nested data on the view page.*

---

## File 4 — Create Command
`Base.Application/Business/NotifyBusiness/SavedFilters/Commands/CreateSavedFilter.cs`
```csharp
namespace Base.Application.Business.NotifyBusiness.SavedFilters.Commands;

[CustomAuthorize(DecoratorNotifyModules.SavedFilter, Permissions.Create)]
public record CreateSavedFilterCommand(SavedFilterRequestDto savedFilter) : ICommand<CreateSavedFilterResult>;
public record CreateSavedFilterResult(SavedFilterRequestDto savedFilter);

public class CreateSavedFilterValidator : BaseCommandFluentValidator<CreateSavedFilterCommand>
{
    private readonly IApplicationDbContext _dbContext;
    public CreateSavedFilterValidator(IStringLocalizer<LocalizerMessages> localizer, IApplicationDbContext dbContext) : base(localizer)
    {
        _dbContext = dbContext;

        ValidateForeignKeyRecord<OrganizationalUnit, int?>(x => x.savedFilter.OrganizationalUnitId, _dbContext.OrganizationalUnits, c => c.OrganizationalUnitId);
        ValidatePropertyIsRequired(x => x.savedFilter.OrganizationalUnitId);
        ValidatePropertyIsRequired(x => x.savedFilter.FilterName);
        ValidatePropertyIsRequired(x => x.savedFilter.FilterCode);
        ValidateStringLength(x => x.savedFilter.FilterName, 100);
        ValidateStringLength(x => x.savedFilter.FilterCode, 100);
        ValidateStringLength(x => x.savedFilter.Description, 1000);
    }
}

public class CreateSavedFilterHandler(IApplicationDbContext dbContext, IHttpContextAccessor httpContextAccessor)
    : ICommandHandler<CreateSavedFilterCommand, CreateSavedFilterResult>
{
    public async Task<CreateSavedFilterResult> Handle(CreateSavedFilterCommand command, CancellationToken cancellationToken)
    {
        var savedFilter = command.savedFilter.Adapt<Domain.Models.NotifyModels.SavedFilter>();

        // FLOW-specific: Set CompanyId from tenant context (not in RequestDto)
        savedFilter.CompanyId = httpContextAccessor.GetCurrentUserStaffCompanyId();

        try
        {
            dbContext.SavedFilters.Add(savedFilter);
            await dbContext.SaveChangesAsync(cancellationToken);
            var result = savedFilter.Adapt<SavedFilterRequestDto>();
            return new CreateSavedFilterResult(result);
        }
        catch (DbUpdateException ex) { throw new InternalServerException("Database operation failed: " + ex.Message); }
        catch (Exception ex) { throw new InternalServerException("An unexpected error occurred: " + ex.Message); }
    }
}
```
*FLOW difference: `httpContextAccessor.GetCurrentUserStaffCompanyId()` sets CompanyId explicitly because CompanyId is not in the RequestDto.*

---

## File 5 — Update Command
`Base.Application/Business/NotifyBusiness/SavedFilters/Commands/UpdateSavedFilter.cs`
```csharp
[CustomAuthorize(DecoratorNotifyModules.SavedFilter, Permissions.Modify)]
public record UpdateSavedFilterCommand(SavedFilterRequestDto savedFilter) : ICommand<UpdateSavedFilterResult>;
public record UpdateSavedFilterResult(SavedFilterRequestDto savedFilter);

public class UpdateSavedFilterValidator : BaseCommandFluentValidator<UpdateSavedFilterCommand>
{
    private readonly IApplicationDbContext _dbContext;
    public UpdateSavedFilterValidator(IStringLocalizer<LocalizerMessages> localizer, IApplicationDbContext dbContext) : base(localizer)
    {
        _dbContext = dbContext;

        ValidateForeignKeyRecord<OrganizationalUnit, int?>(x => x.savedFilter.OrganizationalUnitId, _dbContext.OrganizationalUnits, c => c.OrganizationalUnitId);
        ValidatePropertyIsRequired(x => x.savedFilter.OrganizationalUnitId);
        ValidatePropertyIsRequired(x => x.savedFilter.FilterName);
        ValidatePropertyIsRequired(x => x.savedFilter.FilterCode);
        ValidateStringLength(x => x.savedFilter.FilterName, 100);
        ValidateStringLength(x => x.savedFilter.FilterCode, 100);
        ValidateStringLength(x => x.savedFilter.Description, 1000);

        FindRecordByProperty<SavedFilter, int?>(x => x.savedFilter.SavedFilterId, _dbContext.SavedFilters, c => c.SavedFilterId);
    }
}

public class UpdateSavedFilterHandler(IApplicationDbContext dbContext)
    : ICommandHandler<UpdateSavedFilterCommand, UpdateSavedFilterResult>
{
    public async Task<UpdateSavedFilterResult> Handle(UpdateSavedFilterCommand command, CancellationToken cancellationToken)
    {
        var savedFilterId = command.savedFilter.SavedFilterId;
        var savedFilter = await dbContext.SavedFilters.FindAsync([savedFilterId], cancellationToken: cancellationToken);

        if (savedFilter is null)
            throw new NotFoundException($"This savedFilterId {savedFilterId} not found.");

        command.savedFilter.Adapt(savedFilter);   // Adapt ONTO existing entity

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return new UpdateSavedFilterResult(command.savedFilter);
        }
        catch (DbUpdateException ex) { throw new InternalServerException("Database operation failed: " + ex.Message); }
        catch (Exception ex) { throw new InternalServerException("An unexpected error occurred: " + ex.Message); }
    }
}
```

---

## File 6 — Delete Command
`Base.Application/Business/NotifyBusiness/SavedFilters/Commands/DeleteSavedFilter.cs`
```csharp
[CustomAuthorize(DecoratorNotifyModules.SavedFilter, Permissions.Delete)]
public record DeleteSavedFilterCommand(int savedFilterId) : ICommand<DeleteSavedFilterResult>;
public record DeleteSavedFilterResult(bool isSuccess);

public class DeleteSavedFilterValidator : BaseCommandFluentValidator<DeleteSavedFilterCommand>
{
    private readonly IApplicationDbContext _dbContext;
    public DeleteSavedFilterValidator(IStringLocalizer<LocalizerMessages> localizer, IApplicationDbContext dbContext) : base(localizer)
    {
        _dbContext = dbContext;
        ValidatePropertyIsRequired(x => x.savedFilterId);
        FindInActiveRecordByProperty<Domain.Models.NotifyModels.SavedFilter, int?>(x => x.savedFilterId, _dbContext.SavedFilters, c => c.SavedFilterId);
        ValidateNotReferencedInAnyCollection<SavedFilter, int>(
            x => x.savedFilterId, _dbContext, e => e.SavedFilterId, e => e.FilterName);
    }
}

public class DeleteSavedFilterHandler(IApplicationDbContext dbContext)
    : ICommandHandler<DeleteSavedFilterCommand, DeleteSavedFilterResult>
{
    public async Task<DeleteSavedFilterResult> Handle(DeleteSavedFilterCommand command, CancellationToken cancellationToken)
    {
        var savedFilter = await dbContext.SavedFilters.FindAsync([command.savedFilterId], cancellationToken: cancellationToken);
        if (savedFilter == null) throw new NotFoundException($"This savedFilterId {command.savedFilterId} not found.");
        savedFilter.IsDeleted = true;
        try
        {
            dbContext.SavedFilters.Update(savedFilter);
            await dbContext.SaveChangesAsync(cancellationToken);
            return new DeleteSavedFilterResult(true);
        }
        catch (DbUpdateException ex) { throw new InternalServerException("Database operation failed: " + ex.Message); }
        catch (Exception ex) { throw new InternalServerException("An unexpected error occurred: " + ex.Message); }
    }
}
```

---

## File 7 — Toggle Command
`Base.Application/Business/NotifyBusiness/SavedFilters/Commands/ToggleSavedFilter.cs`
```csharp
[CustomAuthorize(DecoratorNotifyModules.SavedFilter, Permissions.Toggle)]
public record ToggleSavedFilterStatusCommand(int savedFilterId) : ICommand<ToggleSavedFilterStatusResult>;
public record ToggleSavedFilterStatusResult(bool isSuccess);

public class ToggleSavedFilterStatusValidator : BaseCommandFluentValidator<ToggleSavedFilterStatusCommand>
{
    private readonly IApplicationDbContext _dbContext;
    public ToggleSavedFilterStatusValidator(IStringLocalizer<LocalizerMessages> localizer, IApplicationDbContext dbContext) : base(localizer)
    {
        _dbContext = dbContext;
        ValidatePropertyIsRequired(x => x.savedFilterId);
        FindInActiveRecordByProperty<Domain.Models.NotifyModels.SavedFilter, int?>(x => x.savedFilterId, _dbContext.SavedFilters, c => c.SavedFilterId);
    }
}

public class ToggleSavedFilterStatusHandler(IApplicationDbContext dbContext)
    : ICommandHandler<ToggleSavedFilterStatusCommand, ToggleSavedFilterStatusResult>
{
    public async Task<ToggleSavedFilterStatusResult> Handle(ToggleSavedFilterStatusCommand command, CancellationToken cancellationToken)
    {
        var savedFilter = await dbContext.SavedFilters.FindAsync([command.savedFilterId], cancellationToken: cancellationToken);
        if (savedFilter == null) throw new NotFoundException($"SavedFilterId {command.savedFilterId} not found.");
        savedFilter.IsActive = !savedFilter.IsActive;
        try
        {
            dbContext.SavedFilters.Update(savedFilter);
            await dbContext.SaveChangesAsync(cancellationToken);
            return new ToggleSavedFilterStatusResult(savedFilter.IsActive ?? false);
        }
        catch (DbUpdateException ex) { throw new InternalServerException($"Database operation failed: {ex.Message}"); }
        catch (Exception ex) { throw new InternalServerException($"An unexpected error occurred: {ex.Message}"); }
    }
}
```

---

## File 8 — GetAll Query
`Base.Application/Business/NotifyBusiness/SavedFilters/Queries/GetSavedFilter.cs`
```csharp
[CustomAuthorize(DecoratorNotifyModules.SavedFilter, Permissions.Read)]
public record GetSavedFiltersQuery(GridFeatureRequest gridFilterRequest) : IQuery<GetSavedFiltersResult>;
public record GetSavedFiltersResult(GridFeatureResult<SavedFilterResponseDto> savedFilters);

public class GetSavedFiltersValidator : BaseQueryFluentValidator<GetSavedFiltersQuery>
{
    private static readonly HashSet<string> ValidSortColumns = PropertyNameHelper.GetPropertyNames<SavedFilterResponseDto>();
    public GetSavedFiltersValidator(IStringLocalizer<LocalizerMessages> localizer) : base(localizer)
    {
        ValidateGridFeatures(x => x.gridFilterRequest, ValidSortColumns);
    }
}

public class GetSavedFilterHandler(IApplicationDbContext dbContext)
    : IQueryHandler<GetSavedFiltersQuery, GetSavedFiltersResult>
{
    public async Task<GetSavedFiltersResult> Handle(GetSavedFiltersQuery query, CancellationToken cancellationToken)
    {
        var searchTerm = query.gridFilterRequest.searchTerm?.ToLower();

        // FLOW-specific: Include FK navigation properties for grid display + search
        var baseQuery = dbContext.SavedFilters
            .Where(x => x.IsDeleted == false)
            .Include(x => x.Company)
            .Include(x => x.OrganizationalUnit)
            .OrderByDescending(x => x.CreatedDate)
            .AsQueryable();

        var savedFiltersQuery = baseQuery;

        if (!string.IsNullOrEmpty(searchTerm))
        {
            savedFiltersQuery = savedFiltersQuery.Where(c =>
                (!string.IsNullOrEmpty(c.FilterName) && c.FilterName.ToLower().Contains(searchTerm)) ||
                (!string.IsNullOrEmpty(c.FilterCode) && c.FilterCode.ToLower().Contains(searchTerm)) ||
                (!string.IsNullOrEmpty(c.Description) && c.Description.ToLower().Contains(searchTerm)) ||
                (!string.IsNullOrEmpty(c.FilterJson) && c.FilterJson.ToLower().Contains(searchTerm))
            );
        }

        var gridResult = await CommonExtension.ApplyGridFeatures<
            Base.Domain.Models.NotifyModels.SavedFilter, SavedFilterResponseDto>(
            baseQuery, savedFiltersQuery, query.gridFilterRequest, cancellationToken);

        return new GetSavedFiltersResult(gridResult);
    }
}
```
*FLOW difference: `.Include()` for FK navigation properties needed for grid display and search. MASTER_GRID may or may not include depending on whether FK names are shown in grid.*

---

## File 9 — GetById Query
`Base.Application/Business/NotifyBusiness/SavedFilters/Queries/GetSavedFilterById.cs`
```csharp
[CustomAuthorize(DecoratorNotifyModules.SavedFilter, Permissions.Read)]
public record GetSavedFilterByIdQuery(int savedFilterId) : IQuery<GetSavedFilterByIdResult>;
public record GetSavedFilterByIdResult(IEnumerable<SavedFilterResponseDto> savedFilter);

public class GetSavedFilterByIdValidator : BaseQueryFluentValidator<GetSavedFilterByIdQuery>
{
    private readonly IApplicationDbContext _dbContext;
    public GetSavedFilterByIdValidator(IStringLocalizer<LocalizerMessages> localizer, IApplicationDbContext dbContext) : base(localizer)
    {
        _dbContext = dbContext;
        ValidatePropertyIsRequired(x => x.savedFilterId);
        FindRecordByProperty<Base.Domain.Models.NotifyModels.SavedFilter, int>(x => x.savedFilterId, _dbContext.SavedFilters, c => c.SavedFilterId);
    }
}

public class GetSavedFilterByIdHandler(IApplicationDbContext dbContext)
    : IQueryHandler<GetSavedFilterByIdQuery, GetSavedFilterByIdResult>
{
    public async Task<GetSavedFilterByIdResult> Handle(GetSavedFilterByIdQuery query, CancellationToken cancellationToken)
    {
        // FLOW-specific: Include FK navigations for view page display
        var savedFilter = await CommonExtension.ApplyEntityQuery<SavedFilter, SavedFilterResponseDto>(
            dbContext.SavedFilters.AsNoTracking()
                .Include(x => x.Company)
                .Include(x => x.OrganizationalUnit),
            o => o.SavedFilterId.Equals(query.savedFilterId) && o.IsDeleted == false,
            cancellationToken);

        return new GetSavedFilterByIdResult(savedFilter);
    }
}
```
*FLOW difference: `.Include()` chains load FK navigation data for the view page in a SINGLE query. Add `.Include()` for: FK navigations, optional parent, child collections.*

**FLOW GetById include rules:**
| Scenario | Include? | Example |
|----------|----------|---------|
| FK navigation (Company, Currency) | YES | `.Include(x => x.Company)` |
| Optional parent (Batch) | YES | `.Include(x => x.PostalDonationBatch)` |
| Child collection (Distributions) | YES | `.Include(x => x.PostalDonationDistributions)` |
| Dropdown lookups (for form selects) | NO | Separate cached queries from FE |

---

## File 10 — GraphQL Mutations
`Base.API/EndPoints/Notify/Mutations/SavedFilterMutations.cs`
```csharp
using Base.Application.Business.NotifyBusiness.SavedFilters.Commands;

namespace Base.API.EndPoints.Notify.Mutations;

[ExtendObjectType(OperationTypeNames.Mutation)]
public class SavedFilterMutations : IMutations
{
    public async Task<BaseApiResponse<SavedFilterRequestDto>> CreateSavedFilter(
        [Service] IMediator mediator, [Service] ITopicEventSender topicEventSender,
        CancellationToken cancellationToken, SavedFilterRequestDto savedFilter)
    {
        try
        {
            var result = await mediator.Send(new CreateSavedFilterCommand(savedFilter), cancellationToken);
            if (result.savedFilter?.SavedFilterId <= 0) return BaseApiResponse<SavedFilterRequestDto>.PostError();
            return BaseApiResponse<SavedFilterRequestDto>.PostSuccess(result.savedFilter);
        }
        catch (Exception ex) { return BaseApiResponse<SavedFilterRequestDto>.Error(ex.Message); }
    }

    public async Task<BaseApiResponse<SavedFilterRequestDto>> UpdateSavedFilter(
        [Service] IMediator mediator, [Service] ITopicEventSender topicEventSender,
        CancellationToken cancellationToken, SavedFilterRequestDto savedFilter)
    {
        try
        {
            var result = await mediator.Send(new UpdateSavedFilterCommand(savedFilter), cancellationToken);
            if (result.savedFilter?.SavedFilterId <= 0) return BaseApiResponse<SavedFilterRequestDto>.PutError();
            return BaseApiResponse<SavedFilterRequestDto>.PutSuccess(result.savedFilter);
        }
        catch (Exception ex) { return BaseApiResponse<SavedFilterRequestDto>.Error(ex.Message); }
    }

    public async Task<BaseApiResponse<SavedFilterRequestDto>> ActivateDeactivateSavedFilter(
        [Service] IMediator mediator, [Service] ITopicEventSender topicEventSender,
        CancellationToken cancellationToken, int savedFilterId)
    {
        try
        {
            var result = await mediator.Send(new ToggleSavedFilterStatusCommand(savedFilterId), cancellationToken);
            return result.isSuccess
                ? BaseApiResponse<SavedFilterRequestDto>.ActivateDeactivateSuccess(ResponseMessage.ActiveSuccess)
                : BaseApiResponse<SavedFilterRequestDto>.ActivateDeactivateSuccess(ResponseMessage.DeactiveSuccess);
        }
        catch (Exception ex) { return BaseApiResponse<SavedFilterRequestDto>.Error(ex.Message); }
    }

    public async Task<BaseApiResponse<SavedFilterRequestDto>> DeleteSavedFilter(
        [Service] IMediator mediator, [Service] ITopicEventSender topicEventSender,
        CancellationToken cancellationToken, int savedFilterId)
    {
        try
        {
            var result = await mediator.Send(new DeleteSavedFilterCommand(savedFilterId), cancellationToken);
            return result.isSuccess
                ? BaseApiResponse<SavedFilterRequestDto>.DeleteSuccess()
                : BaseApiResponse<SavedFilterRequestDto>.DeleteError();
        }
        catch (Exception ex) { return BaseApiResponse<SavedFilterRequestDto>.Error(ex.Message); }
    }
}
```
*Identical pattern to MASTER_GRID mutations. No FLOW-specific differences in GraphQL endpoint layer.*

---

## File 11 — GraphQL Queries
`Base.API/EndPoints/Notify/Queries/SavedFilterQueries.cs`
```csharp
using Base.Application.Business.NotifyBusiness.SavedFilters.Queries;

namespace Base.API.EndPoints.Notify.Queries;

[ExtendObjectType(OperationTypeNames.Query)]
public class SavedFilterQueries : IQueries
{
    public async Task<PaginatedApiResponse<IEnumerable<SavedFilterResponseDto>>> GetSavedFilters(
        [Service] IMediator mediator, [AsParameters] GridFeatureRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var result = await mediator.Send(new GetSavedFiltersQuery(request), cancellationToken);
            if (result.savedFilters == null || !result.savedFilters.Data.Any())
                return ApiResponseHelper.ReturnPaginatedApiResponseError<SavedFilterResponseDto>();
            return ApiResponseHelper.ReturnPaginatedApiResponse(result.savedFilters);
        }
        catch (Exception ex) { return PaginatedApiResponse<IEnumerable<SavedFilterResponseDto>>.Error(ex.Message); }
    }

    public async Task<BaseApiResponse<SavedFilterResponseDto>> GetSavedFilterById(
        [Service] IMediator mediator, int savedFilterId, CancellationToken cancellationToken)
    {
        try
        {
            var result = await mediator.Send(new GetSavedFilterByIdQuery(savedFilterId), cancellationToken);
            if (result.savedFilter == null || !result.savedFilter.Any())
                return ApiResponseHelper.ReturnObjectApiResponseError<SavedFilterResponseDto>();
            return ApiResponseHelper.ReturnObjectApiResponse(result.savedFilter.First());
        }
        catch (Exception ex) { return BaseApiResponse<SavedFilterResponseDto>.Error(ex.Message); }
    }
}
```
*Identical pattern to MASTER_GRID queries. No FLOW-specific differences in GraphQL endpoint layer.*

---

## File 12 — Export Query (FLOW screens typically include export)
`Base.Application/Business/NotifyBusiness/SavedFilters/Queries/ExportSavedFilter.cs`

FLOW screens typically include an Export query that:
1. Fetches all data via the existing GetAll query (with `pageSize = int.MaxValue`)
2. Reads grid column configuration from `sett.GridFields` (user-specific or default)
3. Uses `IExcelExportService` to generate dynamic Excel based on visible columns
4. Supports `ParentObject` for nested FK property resolution

```csharp
[CustomAuthorize(DecoratorNotifyModules.SavedFilter, Permissions.Export)]
public record ExportSavedFilterQuery(GridFeatureRequest GridFeatureRequest) : IQuery<ExportSavedFilterResult>;
public record ExportSavedFilterResult(byte[] FileContent, string FileName, string ContentType, bool Success = true, string? ErrorMessage = null);

// Handler pattern:
// 1. Fetch all data via existing GetAll query (pageSize=MaxValue)
// 2. Get visible column config from UserGridFields (fallback to GridFields)
// 3. Map each row's properties dynamically using reflection + ParentObject path
// 4. Generate Excel via IExcelExportService
```
*Export is identical for both MASTER_GRID and FLOW. Follow the same pattern — substitute entity name and grid code.*

---

## FLOW-Specific Wiring (same locations as MASTER_GRID)

### A. IApplicationDbContext
Add `DbSet<SavedFilter> SavedFilters { get; }` before `//IDbContextLines`

### B. Module DbContext (NotifyDbContext)
Add `public DbSet<SavedFilter> SavedFilters => Set<SavedFilter>();`

### C. DecoratorProperties
Add `SavedFilter = "SAVEDFILTER"` to `DecoratorNotifyModules` before marker

### D. Mappings (NotifyMappings)
Add 5 TypeAdapterConfig pairs:
```csharp
TypeAdapterConfig<SavedFilter, SavedFilterRequestDto>.NewConfig();
TypeAdapterConfig<SavedFilterRequestDto, SavedFilter>.NewConfig();
TypeAdapterConfig<SavedFilter, SavedFilterResponseDto>.NewConfig();
TypeAdapterConfig<SavedFilterResponseDto, SavedFilter>.NewConfig();
TypeAdapterConfig<SavedFilter, SavedFilterDto>.NewConfig();
```

---

## FLOW DB Seed Differences

The DB seed for FLOW screens follows the same 7-step process as MASTER_GRID with these key differences:

| Step | MASTER_GRID | FLOW |
|------|-------------|------|
| Step 4: sett.Grids | `GridTypeCode = 'MASTER_GRID'` | `GridTypeCode = 'FLOW'` |
| Step 7: GridFormSchema | GENERATED for parent entity | **SKIPPED** for parent (React Hook Form on view page handles the form). Generated only for child grids if child uses RJSF inline add/edit modal. |

Use the template at `.claude/templates/flow-grid/seed-script.sql` for FLOW seed scripts.
