# Backend Code Reference — ContactType (MASTER_GRID Simple Entity)

> **ContactType is the canonical reference for MASTER_GRID screens.**
> Substitute: `ContactType` → `{EntityName}`, `ContactTypes` → `{PluralName}`, `contactType` → `{camelCase}`, `CONTACTTYPE` → `{GRIDCODE}`, `corg` → `{schema}`, `ContactBusiness` → `{Group}Business`, `DecoratorContactModules` → `Decorator{Group}Modules`

---

## File 1 — Entity
`Base.Domain/Models/ContactModels/ContactType.cs`
```csharp
namespace Base.Domain.Models.ContactModels;

[Table("ContactTypes", Schema = "corg")]
public class ContactType : Entity
{
    public int ContactTypeId { get; set; }
    public string ContactTypeCode { get; set; } = default!;
    public string ContactTypeName { get; set; } = default!;
    public string? Description { get; set; }
    public bool IsSystem { get; set; }
    public int OrderBy { get; set; }
    public int? CompanyId { get; set; }
    public Company? Company { get; set; } = default!;
    public ICollection<ContactTypeAssignment>? ContactTypeAssignments { get; set; }
    //EntityIcollection
}
```
*`Entity` base provides IsActive, IsDeleted, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate — never redeclare these.*

---

## File 2 — EF Configuration
`Base.Infrastructure/Data/Configurations/ContactConfigurations/ContactTypeConfiguration.cs`
```csharp
namespace Base.Infrastructure.Data.Configurations.ContactConfigurations;

public class ContactTypeConfiguration : IEntityTypeConfiguration<ContactType>
{
    public void Configure(EntityTypeBuilder<ContactType> builder)
    {
        builder.HasKey(c => c.ContactTypeId);
        builder.Property(c => c.ContactTypeId).UseIdentityAlwaysColumn().ValueGeneratedOnAdd();

        builder.Property(c => c.ContactTypeCode).HasMaxLength(100).IsRequired();
        builder.Property(c => c.ContactTypeName).HasMaxLength(100).IsRequired();
        builder.Property(c => c.Description).HasMaxLength(1000);

        builder.HasIndex(o => new { o.ContactTypeName, o.CompanyId })
               .IsUnique().HasFilter("\"IsActive\" = true AND \"IsDeleted\" = false");
        builder.HasIndex(o => new { o.ContactTypeCode, o.CompanyId })
               .IsUnique().HasFilter("\"IsActive\" = true AND \"IsDeleted\" = false");

        builder.HasOne(c => c.Company)
               .WithMany(c => c.ContactTypes)
               .HasForeignKey(c => c.CompanyId)
               .OnDelete(DeleteBehavior.Restrict);
    }
}
```

---

## File 3 — Schemas / DTOs
`Base.Application/Schemas/ContactSchemas/ContactTypeSchemas.cs`
```csharp
namespace Base.Application.Schemas.ContactSchemas;

public class ContactTypeRequestDto
{
    public int? ContactTypeId { get; set; }
    public string ContactTypeCode { get; set; } = default!;
    public string ContactTypeName { get; set; } = default!;
    public string? Description { get; set; }
    public int? OrderBy { get; set; }
    public int? CompanyId { get; set; }
}

public class ContactTypeResponseDto : ContactTypeRequestDto
{
    public bool IsActive { get; set; }
    public CompanyRequestDto? Company { get; set; }
}

public class ContactTypeDto : ContactTypeResponseDto { }

public class ExportContactTypeDto
{
    public string ContactTypeName { get; set; } = default!;
    public string ContactTypeCode { get; set; } = default!;
    public string? Description { get; set; }
    public int? OrderBy { get; set; }
}
```
*PK in RequestDto is `int?` (nullable — not set on create). ResponseDto extends RequestDto + adds `IsActive` + FK navigation DTOs.*

---

## File 4 — Create Command
`Base.Application/Business/ContactBusiness/ContactTypes/Commands/CreateContactType.cs`
```csharp
using Microsoft.AspNetCore.Http;

namespace Base.Application.Business.ContactBusiness.ContactTypes.Commands;

[CustomAuthorize(DecoratorContactModules.ContactType, Permissions.Create)]
public record CreateContactTypeCommand(ContactTypeRequestDto contactType) : ICommand<CreateContactTypeResult>;
public record CreateContactTypeResult(ContactTypeRequestDto contactType);

public class CreateContactTypeValidator : BaseCommandFluentValidator<CreateContactTypeCommand>
{
    private readonly IApplicationDbContext _dbContext;
    public CreateContactTypeValidator(IStringLocalizer<LocalizerMessages> localizer, IApplicationDbContext dbContext) : base(localizer)
    {
        _dbContext = dbContext;
        ValidatePropertyIsRequired(x => x.contactType.ContactTypeCode);
        ValidatePropertyIsRequired(x => x.contactType.ContactTypeName);
        ValidateStringLength(x => x.contactType.ContactTypeCode, 100);
        ValidateStringLength(x => x.contactType.ContactTypeName, 100);
        ValidateStringLength(x => x.contactType.Description, 1000);
        ValidateUniqueWhenCreate(x => x.contactType.ContactTypeCode, _dbContext.ContactTypes, c => c.ContactTypeCode);
    }
}

public class CreateContactTypeHandler(IApplicationDbContext dbContext, IHttpContextAccessor httpContextAccessor)
    : ICommandHandler<CreateContactTypeCommand, CreateContactTypeResult>
{
    public async Task<CreateContactTypeResult> Handle(CreateContactTypeCommand command, CancellationToken cancellationToken)
    {
        var contactType = command.contactType.Adapt<Domain.Models.ContactModels.ContactType>();
        try
        {
            dbContext.ContactTypes.Add(contactType);
            await dbContext.SaveChangesAsync(cancellationToken);
            var result = contactType.Adapt<ContactTypeRequestDto>();
            return new CreateContactTypeResult(result);
        }
        catch (DbUpdateException ex) { throw new InternalServerException("Database operation failed: " + ex.Message); }
        catch (Exception ex) { throw new InternalServerException("An unexpected error occurred: " + ex.Message); }
    }
}
```
*`IHttpContextAccessor` only needed when handler reads current user context (CompanyId, StaffId). Omit if not required.*

---

## File 5 — Update Command
`Base.Application/Business/ContactBusiness/ContactTypes/Commands/UpdateContactType.cs`
```csharp
[CustomAuthorize(DecoratorContactModules.ContactType, Permissions.Modify)]
public record UpdateContactTypeCommand(ContactTypeRequestDto contactType) : ICommand<UpdateContactTypeResult>;
public record UpdateContactTypeResult(ContactTypeRequestDto contactType);

public class UpdateContactTypeValidator : BaseCommandFluentValidator<UpdateContactTypeCommand>
{
    private readonly IApplicationDbContext _dbContext;
    public UpdateContactTypeValidator(IStringLocalizer<LocalizerMessages> localizer, IApplicationDbContext dbContext) : base(localizer)
    {
        _dbContext = dbContext;
        ValidatePropertyIsRequired(x => x.contactType.ContactTypeId);
        ValidatePropertyIsRequired(x => x.contactType.ContactTypeCode);
        ValidatePropertyIsRequired(x => x.contactType.ContactTypeName);
        ValidateStringLength(x => x.contactType.ContactTypeCode, 100);
        ValidateStringLength(x => x.contactType.ContactTypeName, 100);
        ValidateStringLength(x => x.contactType.Description, 1000);
        ValidateUniqueWhenUpdate<ContactType, string, int?>(
            x => x.contactType.ContactTypeCode, x => x.contactType.ContactTypeId,
            _dbContext.ContactTypes, c => c.ContactTypeCode, c => c.ContactTypeId);
        FindRecordByProperty<ContactType, int?>(x => x.contactType.ContactTypeId, _dbContext.ContactTypes, c => c.ContactTypeId);
    }
}

public class UpdateContactTypeHandler(IApplicationDbContext dbContext, IHttpContextAccessor httpContextAccessor)
    : ICommandHandler<UpdateContactTypeCommand, UpdateContactTypeResult>
{
    public async Task<UpdateContactTypeResult> Handle(UpdateContactTypeCommand command, CancellationToken cancellationToken)
    {
        var contactTypeId = command.contactType.ContactTypeId;
        var contactType = await dbContext.ContactTypes.FindAsync([contactTypeId], cancellationToken: cancellationToken);
        if (contactType is null) throw new NotFoundException($"This contactTypeId {contactTypeId} not found.");
        command.contactType.Adapt(contactType);   // Adapt ONTO existing entity (not to new)
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return new UpdateContactTypeResult(command.contactType);
        }
        catch (DbUpdateException ex) { throw new InternalServerException("Database operation failed: " + ex.Message); }
        catch (Exception ex) { throw new InternalServerException("An unexpected error occurred: " + ex.Message); }
    }
}
```
*Key difference from Create: `ValidateUniqueWhenUpdate` (not WhenCreate), `FindRecordByProperty` for PK existence, `Adapt onto existing entity` not `Adapt to new`.*

---

## File 6 — Delete Command
`Base.Application/Business/ContactBusiness/ContactTypes/Commands/DeleteContactType.cs`
```csharp
[CustomAuthorize(DecoratorContactModules.ContactType, Permissions.Delete)]
public record DeleteContactTypeCommand(int contactTypeId) : ICommand<DeleteContactTypeResult>;
public record DeleteContactTypeResult(bool isSuccess);

public class DeleteContactTypeValidator : BaseCommandFluentValidator<DeleteContactTypeCommand>
{
    private readonly IApplicationDbContext _dbContext;
    public DeleteContactTypeValidator(IStringLocalizer<LocalizerMessages> localizer, IApplicationDbContext dbContext) : base(localizer)
    {
        _dbContext = dbContext;
        ValidatePropertyIsRequired(x => x.contactTypeId);
        FindInActiveRecordByProperty<Domain.Models.ContactModels.ContactType, int?>(x => x.contactTypeId, _dbContext.ContactTypes, c => c.ContactTypeId);
        ValidateNotReferencedInAnyCollection<ContactType, int>(x => x.contactTypeId, dbContext, e => e.ContactTypeId, e => e.ContactTypeName);
    }
}

public class DeleteContactTypeHandler(IApplicationDbContext dbContext)
    : ICommandHandler<DeleteContactTypeCommand, DeleteContactTypeResult>
{
    public async Task<DeleteContactTypeResult> Handle(DeleteContactTypeCommand command, CancellationToken cancellationToken)
    {
        var contactType = await dbContext.ContactTypes.FindAsync([command.contactTypeId], cancellationToken: cancellationToken);
        if (contactType == null) throw new NotFoundException($"This contactTypeId {command.contactTypeId} not found.");
        contactType.IsDeleted = true;
        try
        {
            dbContext.ContactTypes.Update(contactType);
            await dbContext.SaveChangesAsync(cancellationToken);
            return new DeleteContactTypeResult(true);
        }
        catch (DbUpdateException ex) { throw new InternalServerException("Database operation failed: " + ex.Message); }
        catch (Exception ex) { throw new InternalServerException("An unexpected error occurred: " + ex.Message); }
    }
}
```

---

## File 7 — Toggle Command
`Base.Application/Business/ContactBusiness/ContactTypes/Commands/ToggleContactType.cs`
```csharp
[CustomAuthorize(DecoratorContactModules.ContactType, Permissions.Toggle)]
public record ToggleContactTypeStatusCommand(int contactTypeId) : ICommand<ToggleContactTypeStatusResult>;
public record ToggleContactTypeStatusResult(bool isSuccess);

public class ToggleContactTypeStatusValidator : BaseCommandFluentValidator<ToggleContactTypeStatusCommand>
{
    private readonly IApplicationDbContext _dbContext;
    public ToggleContactTypeStatusValidator(IStringLocalizer<LocalizerMessages> localizer, IApplicationDbContext dbContext) : base(localizer)
    {
        _dbContext = dbContext;
        ValidatePropertyIsRequired(x => x.contactTypeId);
        FindInActiveRecordByProperty<Domain.Models.ContactModels.ContactType, int?>(x => x.contactTypeId, _dbContext.ContactTypes, c => c.ContactTypeId);
    }
}

public class ToggleContactTypeStatusHandler(IApplicationDbContext dbContext)
    : ICommandHandler<ToggleContactTypeStatusCommand, ToggleContactTypeStatusResult>
{
    public async Task<ToggleContactTypeStatusResult> Handle(ToggleContactTypeStatusCommand command, CancellationToken cancellationToken)
    {
        var contactType = await dbContext.ContactTypes.FindAsync([command.contactTypeId], cancellationToken: cancellationToken);
        if (contactType == null) throw new NotFoundException($"ContactTypeId {command.contactTypeId} not found.");
        contactType.IsActive = !contactType.IsActive;
        try
        {
            dbContext.ContactTypes.Update(contactType);
            await dbContext.SaveChangesAsync(cancellationToken);
            return new ToggleContactTypeStatusResult(contactType.IsActive ?? false);
        }
        catch (DbUpdateException ex) { throw new InternalServerException($"Database operation failed: {ex.Message}"); }
        catch (Exception ex) { throw new InternalServerException($"An unexpected error occurred: {ex.Message}"); }
    }
}
```
*Returns `contactType.IsActive ?? false` — the new IsActive state after toggle.*

---

## File 8 — GetAll Query
`Base.Application/Business/ContactBusiness/ContactTypes/Queries/GetContactType.cs`
```csharp
[CustomAuthorize(DecoratorContactModules.ContactType, Permissions.Read)]
public record GetContactTypesQuery(GridFeatureRequest gridFilterRequest) : IQuery<GetContactTypesResult>;
public record GetContactTypesResult(GridFeatureResult<ContactTypeResponseDto> contactTypes);

public class GetContactTypesValidator : BaseQueryFluentValidator<GetContactTypesQuery>
{
    private static readonly HashSet<string> ValidSortColumns = PropertyNameHelper.GetPropertyNames<ContactTypeResponseDto>();
    public GetContactTypesValidator(IStringLocalizer<LocalizerMessages> localizer) : base(localizer)
    {
        ValidateGridFeatures(x => x.gridFilterRequest, ValidSortColumns);
    }
}

public class GetContactTypeHandler(IApplicationDbContext dbContext)
    : IQueryHandler<GetContactTypesQuery, GetContactTypesResult>
{
    public async Task<GetContactTypesResult> Handle(GetContactTypesQuery query, CancellationToken cancellationToken)
    {
        var searchTerm = query.gridFilterRequest.searchTerm?.ToLower();

        var baseQuery = dbContext.ContactTypes
            .AsNoTracking()
            .Where(x => x.IsDeleted == false)
            .OrderByDescending(x => x.CreatedDate)
            .AsQueryable();

        var contactTypesQuery = baseQuery;

        if (!string.IsNullOrEmpty(searchTerm))
        {
            contactTypesQuery = contactTypesQuery.Where(c =>
                (!string.IsNullOrEmpty(c.ContactTypeCode) && c.ContactTypeCode.ToLower().Contains(searchTerm)) ||
                (!string.IsNullOrEmpty(c.ContactTypeName) && c.ContactTypeName.ToLower().Contains(searchTerm)) ||
                (!string.IsNullOrEmpty(c.Description) && c.Description.ToLower().Contains(searchTerm))
            );
        }

        var gridResult = await CommonExtension.ApplyGridFeatures<
            Base.Domain.Models.ContactModels.ContactType, ContactTypeResponseDto>(
            baseQuery, contactTypesQuery, query.gridFilterRequest, cancellationToken);

        return new GetContactTypesResult(gridResult);
    }
}
```
*`baseQuery` (unfiltered) and `contactTypesQuery` (search-filtered) are SEPARATE — both passed to `ApplyGridFeatures`.*

---

## File 9 — GetById Query
`Base.Application/Business/ContactBusiness/ContactTypes/Queries/GetContactTypeById.cs`
```csharp
[CustomAuthorize(DecoratorContactModules.ContactType, Permissions.Read)]
public record GetContactTypeByIdQuery(int contactTypeId) : IQuery<GetContactTypeByIdResult>;
public record GetContactTypeByIdResult(IEnumerable<ContactTypeResponseDto> contactType);

public class GetContactTypeByIdValidator : BaseQueryFluentValidator<GetContactTypeByIdQuery>
{
    private readonly IApplicationDbContext _dbContext;
    public GetContactTypeByIdValidator(IStringLocalizer<LocalizerMessages> localizer, IApplicationDbContext dbContext) : base(localizer)
    {
        _dbContext = dbContext;
        ValidatePropertyIsRequired(x => x.contactTypeId);
        FindRecordByProperty<Base.Domain.Models.ContactModels.ContactType, int>(x => x.contactTypeId, _dbContext.ContactTypes, c => c.ContactTypeId);
    }
}

public class GetContactTypeByIdHandler(IApplicationDbContext dbContext)
    : IQueryHandler<GetContactTypeByIdQuery, GetContactTypeByIdResult>
{
    public async Task<GetContactTypeByIdResult> Handle(GetContactTypeByIdQuery query, CancellationToken cancellationToken)
    {
        var contactType = await CommonExtension.ApplyEntityQuery<ContactType, ContactTypeResponseDto>(
            dbContext.ContactTypes.AsNoTracking(),
            o => o.ContactTypeId.Equals(query.contactTypeId) && o.IsDeleted == false,
            cancellationToken);
        return new GetContactTypeByIdResult(contactType);
    }
}
```
*Uses `ApplyEntityQuery` (not `ApplyGridFeatures`). Result wraps `IEnumerable<ResponseDto>` — not a single object. GQL layer calls `.First()`.*

---

## File 10 — GraphQL Mutations
`Base.API/EndPoints/Contact/Mutations/ContactTypeMutations.cs`
```csharp
using Base.Application.Business.ContactBusiness.ContactTypes.Commands;

namespace Base.API.EndPoints.Contact.Mutations;

[ExtendObjectType(OperationTypeNames.Mutation)]
public class ContactTypeMutations : IMutations
{
    public async Task<BaseApiResponse<ContactTypeRequestDto>> CreateContactType(
        [Service] IMediator mediator, [Service] ITopicEventSender topicEventSender,
        CancellationToken cancellationToken, ContactTypeRequestDto contactType)
    {
        try
        {
            var result = await mediator.Send(new CreateContactTypeCommand(contactType), cancellationToken);
            if (result.contactType?.ContactTypeId <= 0) return BaseApiResponse<ContactTypeRequestDto>.PostError();
            return BaseApiResponse<ContactTypeRequestDto>.PostSuccess(result.contactType);
        }
        catch (Exception ex) { return BaseApiResponse<ContactTypeRequestDto>.Error(ex.Message); }
    }

    public async Task<BaseApiResponse<ContactTypeRequestDto>> UpdateContactType(
        [Service] IMediator mediator, [Service] ITopicEventSender topicEventSender,
        CancellationToken cancellationToken, ContactTypeRequestDto contactType)
    {
        try
        {
            var result = await mediator.Send(new UpdateContactTypeCommand(contactType), cancellationToken);
            if (result.contactType?.ContactTypeId <= 0) return BaseApiResponse<ContactTypeRequestDto>.PutError();
            return BaseApiResponse<ContactTypeRequestDto>.PutSuccess(result.contactType);
        }
        catch (Exception ex) { return BaseApiResponse<ContactTypeRequestDto>.Error(ex.Message); }
    }

    public async Task<BaseApiResponse<ContactTypeRequestDto>> ActivateDeactivateContactType(
        [Service] IMediator mediator, [Service] ITopicEventSender topicEventSender,
        CancellationToken cancellationToken, int contactTypeId)
    {
        try
        {
            var result = await mediator.Send(new ToggleContactTypeStatusCommand(contactTypeId), cancellationToken);
            return result.isSuccess
                ? BaseApiResponse<ContactTypeRequestDto>.ActivateDeactivateSuccess(ResponseMessage.ActiveSuccess)
                : BaseApiResponse<ContactTypeRequestDto>.ActivateDeactivateSuccess(ResponseMessage.DeactiveSuccess);
        }
        catch (Exception ex) { return BaseApiResponse<ContactTypeRequestDto>.Error(ex.Message); }
    }

    public async Task<BaseApiResponse<ContactTypeRequestDto>> DeleteContactType(
        [Service] IMediator mediator, [Service] ITopicEventSender topicEventSender,
        CancellationToken cancellationToken, int contactTypeId)
    {
        try
        {
            var result = await mediator.Send(new DeleteContactTypeCommand(contactTypeId), cancellationToken);
            return result.isSuccess
                ? BaseApiResponse<ContactTypeRequestDto>.DeleteSuccess()
                : BaseApiResponse<ContactTypeRequestDto>.DeleteError();
        }
        catch (Exception ex) { return BaseApiResponse<ContactTypeRequestDto>.Error(ex.Message); }
    }
}
```
*Create/Update: `PostSuccess`/`PutSuccess` with result DTO. ActivateDeactivate: `ActivateDeactivateSuccess` with message string. Delete: `DeleteSuccess()` — no data.*

---

## File 11 — GraphQL Queries
`Base.API/EndPoints/Contact/Queries/ContactTypeQueries.cs`
```csharp
using Base.Application.Business.ContactBusiness.ContactTypes.Queries;

namespace Base.API.EndPoints.Contact.Queries;

[ExtendObjectType(OperationTypeNames.Query)]
public class ContactTypeQueries : IQueries
{
    public async Task<PaginatedApiResponse<IEnumerable<ContactTypeResponseDto>>> GetContactTypes(
        [Service] IMediator mediator,
        [AsParameters] GridFeatureRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var result = await mediator.Send(new GetContactTypesQuery(request), cancellationToken);
            if (result.contactTypes == null || !result.contactTypes.Data.Any())
                return ApiResponseHelper.ReturnPaginatedApiResponseError<ContactTypeResponseDto>();
            return ApiResponseHelper.ReturnPaginatedApiResponse(result.contactTypes);
        }
        catch (Exception ex) { return PaginatedApiResponse<IEnumerable<ContactTypeResponseDto>>.Error(ex.Message); }
    }

    public async Task<BaseApiResponse<ContactTypeResponseDto>> GetContactTypeById(
        [Service] IMediator mediator, int contactTypeId, CancellationToken cancellationToken)
    {
        try
        {
            var result = await mediator.Send(new GetContactTypeByIdQuery(contactTypeId), cancellationToken);
            if (result.contactType == null || !result.contactType.Any())
                return ApiResponseHelper.ReturnObjectApiResponseError<ContactTypeResponseDto>();
            return ApiResponseHelper.ReturnObjectApiResponse(result.contactType.First());
        }
        catch (Exception ex) { return BaseApiResponse<ContactTypeResponseDto>.Error(ex.Message); }
    }
}
```
*GetAll: `PaginatedApiResponse<IEnumerable<ResponseDto>>` with `[AsParameters]`. GetById: `BaseApiResponse<ResponseDto>`, calls `.First()` on IEnumerable result.*
