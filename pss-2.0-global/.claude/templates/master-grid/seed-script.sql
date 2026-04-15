-- ============================================================
-- ##EntityName## - DB Seed Script (MASTER_GRID)
-- Generated for: ##EntityDisplayName##
-- GridCode: ##GRIDCODE##
-- GridType: MASTER_GRID
-- Module: ##MODULECODE##
-- Parent Menu: ##PARENTMENUCODE##
-- Menu URL: ##MenuUrl##
-- ============================================================

-- ============================================================
-- STEP 1: auth.Menus (navigation entry)
-- ============================================================
INSERT INTO auth."Menus"(
    "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description",
    "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "IsLeastMenu")
VALUES (
    '##EntityDisplayName##', '##MENUCODE##',
    (SELECT "MenuId" FROM auth."Menus" WHERE "MenuCode" = '##PARENTMENUCODE##'),
    null,
    (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = '##MODULECODE##'),
    '##MenuUrl##', null, 1, 2, now(), null, null, true, false, true
);
-- MenuUrl format: {moduleLower}/{feFolder}/{entityLower}

-- ============================================================
-- STEP 2: auth.MenuCapabilities
-- AI pre-selects based on screen type. User confirms via CONFIG block.
-- ISMENURENDER is ALWAYS included.
-- ============================================================
INSERT INTO auth."MenuCapabilities"(
    "MenuId", "CapabilityId", "CreatedBy", "CreatedDate",
    "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES
    ##RepeatForEachCapability:##
    ((SELECT "MenuId" FROM auth."Menus" WHERE "MenuCode" = '##MENUCODE##'), (SELECT "CapabilityId" FROM auth."Capabilities" WHERE "CapabilityCode" = '##CAPABILITYCODE##'), 2, now(), null, null, true, false);

-- ============================================================
-- STEP 3: auth.RoleCapabilities
-- AI pre-selects per role. User confirms via CONFIG block.
-- ============================================================
INSERT INTO auth."RoleCapabilities"(
    "RoleId", "MenuId", "CapabilityId", "HasAccess", "CreatedBy", "CreatedDate",
    "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES
    ##RepeatForEachRoleCapabilityCombination:##
    -- ##ROLECODE##: ##CAPABILITIES##
    ((SELECT "RoleId" FROM auth."Roles" WHERE "RoleCode" = '##ROLECODE##'), (SELECT "MenuId" FROM auth."Menus" WHERE "MenuCode" = '##MENUCODE##'), (SELECT "CapabilityId" FROM auth."Capabilities" WHERE "CapabilityCode" = '##CAPABILITYCODE##'), true, 2, now(), null, null, true, false);

-- ============================================================
-- STEP 4: sett.Grids (grid registration)
-- MASTER_GRID: GridFormSchema generated in STEP 7
-- ============================================================
INSERT INTO sett."Grids"(
    "GridName", "GridCode", "Description", "GridTypeId", "ModuleId",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "GridFormSchema")
VALUES (
    '##GridName##', '##GRIDCODE##', null,
    (SELECT "GridTypeId" FROM sett."GridTypes" WHERE "GridTypeCode" = 'MASTER_GRID'),
    (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = '##MODULECODE##'),
    2, now(), null, null, true, false, null
);

-- ============================================================
-- STEP 5: sett.Fields (entity's OWN fields only)
-- Do NOT insert FK target fields — they already exist (e.g., COUNTRYNAME).
-- IsSystem = true for all AI-generated fields.
-- ============================================================
INSERT INTO sett."Fields"(
    "FieldName", "FieldCode", "FieldKey", "DataTypeId",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "IsSystem")
VALUES
    ##RepeatForOwnFieldsOnly:##
    ('##Field Display Name##', '##FIELDCODE##', '##fieldKey##', (SELECT "DataTypeId" FROM sett."DataTypes" WHERE "DataTypeCode" = '##DATATYPECODE##'), 2, now(), null, null, true, false, true);

-- ============================================================
-- STEP 6: sett.GridFields (map fields to grid)
-- PK field: IsVisible=false, IsPrimary=true
-- Own fields: IsVisible=true
-- FK fields: Use EXISTING FieldCode (e.g., COUNTRYNAME), set ParentObject + ValueSource
-- IsActive (last): Use existing ISACTIVE field with static ValueSource
-- ============================================================
INSERT INTO sett."GridFields"(
    "GridId", "FieldId", "IsVisible", "IsPredefined", "OrderBy", "IsPrimary",
    "FieldDataQuery", "FieldConfiguration", "CssClass", "GridComponentName",
    "ParentObject", "Width",
    "AggregationType", "DefaultOperator", "FilterOperator", "FilterTooltip",
    "IsAggregate", "IsFilterable", "ValueSource",
    "ValueSourceParams", "AggregateConfig", "UseSummaryTable", "CompanyId", "IsSystem",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES
    ##RepeatForEachGridField:##
    ((SELECT "GridId" FROM sett."Grids" WHERE "GridCode" = '##GRIDCODE##'),
     (SELECT "FieldId" FROM sett."Fields" WHERE "FieldCode" = '##FIELDCODE##'),
     ##IsVisible##, ##IsPredefined##, ##OrderBy##, ##IsPrimary##,
     null, null, null, null,
     ##ParentObject##, null,
     null, null, null, null,
     null, null, ##ValueSource##,
     null, null, null, null, true,
     2, now(), null, null, true, false);

-- ============================================================
-- STEP 7: GridFormSchema (MASTER_GRID ONLY)
-- JSON schema + uiSchema for RJSF modal form.
-- See rjsf-formfields.md for widget patterns.
-- ============================================================
UPDATE sett."Grids"
SET "GridFormSchema" = '##GridFormSchemaJSON##'
WHERE "GridId" = (SELECT "GridId" FROM sett."Grids" WHERE "GridCode" = '##GRIDCODE##');
