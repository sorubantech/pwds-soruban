-- ============================================================
-- ##EntityName## - DB Seed Script (FLOW)
-- Generated for: ##EntityDisplayName##
-- GridCode: ##GRIDCODE##
-- GridType: FLOW
-- Module: ##MODULECODE##
-- Parent Menu: ##PARENTMENUCODE##
-- Menu URL: ##MenuUrl##
-- ============================================================
-- NOTE: FLOW grids do NOT generate GridFormSchema for the parent entity.
-- Parent form uses React Hook Form on the view page.
-- Child grids (if MASTER_GRID type) may have their own GridFormSchema.
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
    (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = '##DONATION##'),
    '##MenuUrl##', null, 1, 2, now(), null, null, true, false, true
);

-- ============================================================
-- STEP 2: auth.MenuCapabilities
-- FLOW screens typically: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, PRINT, ISMENURENDER
-- ============================================================
INSERT INTO auth."MenuCapabilities"(
    "MenuId", "CapabilityId", "CreatedBy", "CreatedDate",
    "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES
    ##RepeatForEachCapability:##
    ((SELECT "MenuId" FROM auth."Menus" WHERE "MenuCode" = '##MENUCODE##'), (SELECT "CapabilityId" FROM auth."Capabilities" WHERE "CapabilityCode" = '##CAPABILITYCODE##'), 2, now(), null, null, true, false);

-- ============================================================
-- STEP 3: auth.RoleCapabilities
-- ============================================================
INSERT INTO auth."RoleCapabilities"(
    "RoleId", "MenuId", "CapabilityId", "HasAccess", "CreatedBy", "CreatedDate",
    "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES
    ##RepeatForEachRoleCapabilityCombination:##
    ((SELECT "RoleId" FROM auth."Roles" WHERE "RoleCode" = '##ROLECODE##'), (SELECT "MenuId" FROM auth."Menus" WHERE "MenuCode" = '##MENUCODE##'), (SELECT "CapabilityId" FROM auth."Capabilities" WHERE "CapabilityCode" = '##CAPABILITYCODE##'), true, 2, now(), null, null, true, false);

-- ============================================================
-- STEP 4: sett.Grids (PARENT grid — FLOW type, NO GridFormSchema)
-- ============================================================
INSERT INTO sett."Grids"(
    "GridName", "GridCode", "Description", "GridTypeId", "ModuleId",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "GridFormSchema")
VALUES (
    '##GridName##', '##GRIDCODE##', null,
    (SELECT "GridTypeId" FROM sett."GridTypes" WHERE "GridTypeCode" = 'FLOW'),
    (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = '##MODULECODE##'),
    2, now(), null, null, true, false, null
);

-- ============================================================
-- STEP 4b: sett.Grids (CHILD grid — if child has RJSF form)
-- Only generate if child entity uses MASTER_GRID-style inline add/edit
-- ============================================================
##IF_CHILD_GRID_NEEDED:##
INSERT INTO sett."Grids"(
    "GridName", "GridCode", "Description", "GridTypeId", "ModuleId",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "GridFormSchema")
VALUES (
    '##ChildGridName##', '##CHILDGRIDCODE##', null,
    (SELECT "GridTypeId" FROM sett."GridTypes" WHERE "GridTypeCode" = 'MASTER_GRID'),
    (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = '##MODULECODE##'),
    2, now(), null, null, true, false, null
);

-- ============================================================
-- STEP 5: sett.Fields (entity's OWN fields only — same rules as MASTER_GRID)
-- Do NOT insert FK target fields — they already exist.
-- IsSystem = true for all AI-generated fields.
-- ============================================================
INSERT INTO sett."Fields"(
    "FieldName", "FieldCode", "FieldKey", "DataTypeId",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "IsSystem")
VALUES
    ##RepeatForOwnFieldsOnly_Parent:##
    ('##Field Display Name##', '##FIELDCODE##', '##fieldKey##', (SELECT "DataTypeId" FROM sett."DataTypes" WHERE "DataTypeCode" = '##DATATYPECODE##'), 2, now(), null, null, true, false, true);

-- Child entity fields (if child grid exists)
##IF_CHILD_GRID_NEEDED:##
INSERT INTO sett."Fields"(
    "FieldName", "FieldCode", "FieldKey", "DataTypeId",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "IsSystem")
VALUES
    ##RepeatForOwnFieldsOnly_Child:##
    ('##Field Display Name##', '##FIELDCODE##', '##fieldKey##', (SELECT "DataTypeId" FROM sett."DataTypes" WHERE "DataTypeCode" = '##DATATYPECODE##'), 2, now(), null, null, true, false, true);

-- ============================================================
-- STEP 6: sett.GridFields (PARENT grid fields)
-- Same rules: PK hidden, FK reuse existing NAME field + ParentObject
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
    ##RepeatForEachGridField_Parent:##
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
-- STEP 6b: sett.GridFields (CHILD grid fields — if child grid exists)
-- ============================================================
##IF_CHILD_GRID_NEEDED:##
INSERT INTO sett."GridFields"(
    "GridId", "FieldId", "IsVisible", "IsPredefined", "OrderBy", "IsPrimary",
    "FieldDataQuery", "FieldConfiguration", "CssClass", "GridComponentName",
    "ParentObject", "Width",
    "AggregationType", "DefaultOperator", "FilterOperator", "FilterTooltip",
    "IsAggregate", "IsFilterable", "ValueSource",
    "ValueSourceParams", "AggregateConfig", "UseSummaryTable", "CompanyId", "IsSystem",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES
    ##RepeatForEachGridField_Child:##
    ((SELECT "GridId" FROM sett."Grids" WHERE "GridCode" = '##CHILDGRIDCODE##'),
     (SELECT "FieldId" FROM sett."Fields" WHERE "FieldCode" = '##FIELDCODE##'),
     ##IsVisible##, ##IsPredefined##, ##OrderBy##, ##IsPrimary##,
     null, null, null, null,
     ##ParentObject##, null,
     null, null, null, null,
     null, null, ##ValueSource##,
     null, null, null, null, true,
     2, now(), null, null, true, false);

-- ============================================================
-- STEP 7: GridFormSchema (CHILD grid ONLY — if child uses RJSF)
-- Parent FLOW grid: NO GridFormSchema (uses React Hook Form)
-- Child grid: Generate if child has inline add/edit modal
-- ============================================================
##IF_CHILD_GRID_NEEDS_FORMSCHEMA:##
UPDATE sett."Grids"
SET "GridFormSchema" = '##ChildGridFormSchemaJSON##'
WHERE "GridId" = (SELECT "GridId" FROM sett."Grids" WHERE "GridCode" = '##CHILDGRIDCODE##');
