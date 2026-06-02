-- =============================================================================
-- Screen #121 — App Layout / Theme Customizer settings seed.
--
-- Seeds:
--   1. sett.SettingGroups  : THEMECUSTOMIZER (group 1)
--   2. sett.OrganizationSettings : 9 ThemeCustomizer params
--
-- Notes:
--   * SettingGroupId and OrganizationSettingId are GENERATED ALWAYS AS IDENTITY
--     (see EF config in OrganizationSettingConfiguration.cs / SettingGroupConfiguration.cs),
--     so we do NOT inject literal IDs.
--   * CanUserOverride = TRUE on all 9 rows so the FE ThemeCustomizer can save
--     per-user overrides via sett.UserSettings.
--   * Audit fields: CreatedBy=1 (SYSTEM/admin), CreatedDate=NOW(),
--     IsActive=true, IsDeleted=false.
--   * Each INSERT is guarded by WHERE NOT EXISTS so the script is re-runnable.
--   * No row is inserted into sett.UserSettings — per-user rows are created
--     at runtime via CreateUserSetting mutation when a user saves overrides.
-- =============================================================================

BEGIN;

-- 1. SettingGroup -------------------------------------------------------------
INSERT INTO sett."SettingGroups"
  ("SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI",
   "OrderBy", "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
SELECT 'Theme Customizer', 'THEMECUSTOMIZER', 'Components', true,
       1, 1, NOW() AT TIME ZONE 'UTC', true, false
WHERE NOT EXISTS (
  SELECT 1 FROM sett."SettingGroups"
   WHERE "SettingGroupCode" = 'THEMECUSTOMIZER' AND "IsActive" = true
);

-- Resolve the (now-existing) SettingGroupId for the inserts below.
DO $$
DECLARE
  v_group_id INT;
BEGIN
  SELECT "SettingGroupId" INTO v_group_id
    FROM sett."SettingGroups"
   WHERE "SettingGroupCode" = 'THEMECUSTOMIZER' AND "IsActive" = true
   LIMIT 1;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'THEMECUSTOMIZER SettingGroup not found after upsert';
  END IF;

  -- 2. OrganizationSettings (9 rows) ------------------------------------------

  -- 2.1  SIDEBARIMAGE
  INSERT INTO sett."OrganizationSettings"
    ("SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue",
     "ParamDataType", "Description", "AllValues", "CanUserOverride",
     "CurrentValue", "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
  SELECT v_group_id, 'Sidebar Image', 'SIDEBARIMAGE', 'none',
         'SingleSelectImage', 'Choose a image of sidebar',
         '[ { "id": "7215391d-1203-4adb-8049-4741f733148a", "file": "/images/all-img/img-2.jpeg", "isActive": true }, { "id": "121d0981-9f70-4671-8a9a-3d83427a3682", "file": "/images/all-img/img-1.jpeg", "isActive": true } ]',
         true, NULL, 1, NOW() AT TIME ZONE 'UTC', true, false
  WHERE NOT EXISTS (
    SELECT 1 FROM sett."OrganizationSettings"
     WHERE "SettingGroupId" = v_group_id AND "ParamCode" = 'SIDEBARIMAGE'
  );

  -- 2.2  COLORSCHEME
  INSERT INTO sett."OrganizationSettings"
    ("SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue",
     "ParamDataType", "Description", "AllValues", "CanUserOverride",
     "CurrentValue", "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
  SELECT v_group_id, 'Color Scheme', 'COLORSCHEME', 'light',
         'SingleSelectButton', 'Choose light or dark scheme',
         '[ { "id": "af77c100-cf71-43f8-b551-f265ae9c8780", "key": "light", "label": "Light", "icon": "heroicons:sun", "isActive": true }, { "id": "6bee633a-122a-4e65-ac9c-37956357b527", "key": "dark", "label": "Dark", "icon": "heroicons:moon", "isActive": true } ]',
         true, NULL, 1, NOW() AT TIME ZONE 'UTC', true, false
  WHERE NOT EXISTS (
    SELECT 1 FROM sett."OrganizationSettings"
     WHERE "SettingGroupId" = v_group_id AND "ParamCode" = 'COLORSCHEME'
  );

  -- 2.3  NAVBARTYPE
  INSERT INTO sett."OrganizationSettings"
    ("SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue",
     "ParamDataType", "Description", "AllValues", "CanUserOverride",
     "CurrentValue", "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
  SELECT v_group_id, 'Navbar Type', 'NAVBARTYPE', 'sticky',
         'SingleSelectRadio', 'Choose your navbar type',
         '[ { "id": "280d9537-c070-43fe-8212-040597f7caff", "key": "sticky", "label": "Sticky", "isActive": true }, { "id": "2aa7e937-c38c-4805-935b-3103b0f47a78", "key": "static", "label": "Static", "isActive": true }, { "id": "d64c3600-bd80-41db-8294-f2fc19304284", "key": "floating", "label": "Floating", "isActive": true }, { "id": "53fc4078-9df7-4f5b-861f-d5e0a304f05c", "key": "hidden", "label": "Hidden", "isActive": true } ]',
         true, NULL, 1, NOW() AT TIME ZONE 'UTC', true, false
  WHERE NOT EXISTS (
    SELECT 1 FROM sett."OrganizationSettings"
     WHERE "SettingGroupId" = v_group_id AND "ParamCode" = 'NAVBARTYPE'
  );

  -- 2.4  ROUNDED
  INSERT INTO sett."OrganizationSettings"
    ("SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue",
     "ParamDataType", "Description", "AllValues", "CanUserOverride",
     "CurrentValue", "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
  SELECT v_group_id, 'Rounded', 'ROUNDED', '0.5',
         'SingleSelectButton', 'Choose the radius',
         '[ { "id": "06543f42-317a-40c4-87a5-685dedbe440b", "key": "0", "label": "0", "isActive": true }, { "id": "434f35d0-e120-4e10-bab7-0b8e387fe365", "key": "0.3", "label": "0.3", "isActive": true }, { "id": "81732857-b9c0-4c9b-96a4-2438dad00374", "key": "0.5", "label": "0.5", "isActive": true }, { "id": "59307d2f-d6de-4cdc-8cee-bc9211a9d282", "key": "0.75", "label": "0.75", "isActive": true }, { "id": "109c44fc-14ed-4c44-b0b6-cf177f1e0dff", "key": "1.0", "label": "1.0", "isActive": true } ]',
         true, NULL, 1, NOW() AT TIME ZONE 'UTC', true, false
  WHERE NOT EXISTS (
    SELECT 1 FROM sett."OrganizationSettings"
     WHERE "SettingGroupId" = v_group_id AND "ParamCode" = 'ROUNDED'
  );

  -- 2.5  FOOTERTYPE
  INSERT INTO sett."OrganizationSettings"
    ("SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue",
     "ParamDataType", "Description", "AllValues", "CanUserOverride",
     "CurrentValue", "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
  SELECT v_group_id, 'Footer Type', 'FOOTERTYPE', 'static',
         'SingleSelectRadio', 'Choose your footer type',
         '[ { "id": "8156add6-dc34-463b-a5ba-5fac9291376a", "key": "sticky", "label": "Sticky", "isActive": true }, { "id": "4ceeb504-b4b9-42a1-a9dd-5c1c35e10737", "key": "static", "label": "Static", "isActive": true }, { "id": "0d656857-0fab-4519-8be5-762c3481e921", "key": "hidden", "label": "Hidden", "isActive": true } ]',
         true, 'sticky', 1, NOW() AT TIME ZONE 'UTC', true, false
  WHERE NOT EXISTS (
    SELECT 1 FROM sett."OrganizationSettings"
     WHERE "SettingGroupId" = v_group_id AND "ParamCode" = 'FOOTERTYPE'
  );

  -- 2.6  SIDEBARLAYOUT
  INSERT INTO sett."OrganizationSettings"
    ("SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue",
     "ParamDataType", "Description", "AllValues", "CanUserOverride",
     "CurrentValue", "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
  SELECT v_group_id, 'Sidebar Layout', 'SIDEBARLAYOUT', 'popover',
         'SingleSelectIcon', 'Choose your sidebar layout',
         '[ { "id": "300c9563-be50-4be1-afae-7c3b9dd14c38", "key": "module", "label": "Module", "svg": "VerticalSvg", "disabled": "layout === \"semibox\" || layout === \"horizontal\"", "isActive": true }, { "id": "8158700b-d546-4203-9ab3-8ce7b4d01e26", "key": "classic", "label": "Classic", "svg": "SemiBoxSvg", "disabled": "layout === \"semibox\"", "isActive": true }, { "id": "893f0119-7b72-4548-938c-6b9512e9fdc9", "key": "popover", "label": "Popover", "svg": "SemiBoxSvg", "isActive": true } ]',
         true, 'classic', 1, NOW() AT TIME ZONE 'UTC', true, false
  WHERE NOT EXISTS (
    SELECT 1 FROM sett."OrganizationSettings"
     WHERE "SettingGroupId" = v_group_id AND "ParamCode" = 'SIDEBARLAYOUT'
  );

  -- 2.7  LAYOUT
  INSERT INTO sett."OrganizationSettings"
    ("SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue",
     "ParamDataType", "Description", "AllValues", "CanUserOverride",
     "CurrentValue", "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
  SELECT v_group_id, 'Layout', 'LAYOUT', 'vertical',
         'SingleSelectIcon', 'Choose your layout',
         '[ { "id": "16ca0555-acf3-452e-b8fe-196a1ad31730", "key": "vertical", "label": "Vertical", "svg": "VerticalSvg", "isActive": true }, { "id": "e22bb8ac-5386-4192-84e8-fcadd80268c2", "key": "horizontal", "label": "Horizontal", "svg": "HorizontalSvg", "isActive": true }, { "id": "aaf9e6e6-7632-4baf-a7ab-c873ec2c45cf", "key": "semibox", "label": "Semi-Box", "svg": "SemiBoxSvg", "isActive": true } ]',
         true, NULL, 1, NOW() AT TIME ZONE 'UTC', true, false
  WHERE NOT EXISTS (
    SELECT 1 FROM sett."OrganizationSettings"
     WHERE "SettingGroupId" = v_group_id AND "ParamCode" = 'LAYOUT'
  );

  -- 2.8  DIRECTION
  INSERT INTO sett."OrganizationSettings"
    ("SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue",
     "ParamDataType", "Description", "AllValues", "CanUserOverride",
     "CurrentValue", "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
  SELECT v_group_id, 'Direction', 'DIRECTION', 'false',
         'SingleSelectButton', 'Choose your direction',
         '[ { "id": "6b717ca7-5eb6-4263-9ab2-0a95d40e3fcd", "key": false, "label": "Ltr", "isActive": true }, { "id": "1421a479-b7ae-4225-91f4-4de7e8385a80", "key": true, "label": "Rtl", "isActive": true } ]',
         true, 'false', 1, NOW() AT TIME ZONE 'UTC', true, false
  WHERE NOT EXISTS (
    SELECT 1 FROM sett."OrganizationSettings"
     WHERE "SettingGroupId" = v_group_id AND "ParamCode" = 'DIRECTION'
  );

  -- 2.9  THEME
  INSERT INTO sett."OrganizationSettings"
    ("SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue",
     "ParamDataType", "Description", "AllValues", "CanUserOverride",
     "CurrentValue", "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
  SELECT v_group_id, 'Theme', 'THEME', 'blue',
         'SingleSelectRadio', 'Choose a theme',
         '[ { "id": "03156816-6a99-4b5e-a280-510c3cbec279", "key": "zinc", "isActive": true }, { "id": "71c150c6-8f01-4c7b-9bfd-381259878ca6", "key": "slate", "isActive": true }, { "id": "cfda5f50-1309-4913-9e14-8f51cbc4e898", "key": "stone", "isActive": true }, { "id": "22c35fa8-0a72-40a6-8dbb-40d71774cb62", "key": "gray", "isActive": true }, { "id": "25360473-61ea-4c2a-9c09-b8da174e545d", "key": "neutral", "isActive": true }, { "id": "d0ee87c9-d642-49b8-a5ee-b6111f6d358f", "key": "red", "isActive": true }, { "id": "c1f2df7e-e1c0-44a6-b226-4da5a4eff6ed", "key": "rose", "isActive": true }, { "id": "c83032e2-ea49-40b6-922b-bd0ad652b662", "key": "orange", "isActive": true }, { "id": "eaea1711-cb89-4fec-8e40-b383841b7638", "key": "blue", "isActive": true }, { "id": "eb29471d-5828-42c9-bb52-d3f605d17d87", "key": "yellow", "isActive": true }, { "id": "e9863f42-a48a-4f3f-bcaf-c942cafce213", "key": "violet", "isActive": true } ]',
         true, NULL, 1, NOW() AT TIME ZONE 'UTC', true, false
  WHERE NOT EXISTS (
    SELECT 1 FROM sett."OrganizationSettings"
     WHERE "SettingGroupId" = v_group_id AND "ParamCode" = 'THEME'
  );
END $$;

COMMIT;

-- =============================================================================
-- Verify
-- =============================================================================
-- SELECT sg."SettingGroupId", sg."SettingGroupName", os."ParamCode",
--        os."ParamDefaultValue", os."CurrentValue", os."CanUserOverride"
--   FROM sett."SettingGroups" sg
--   LEFT JOIN sett."OrganizationSettings" os ON os."SettingGroupId" = sg."SettingGroupId"
--  WHERE sg."SettingGroupCode" = 'THEMECUSTOMIZER'
--  ORDER BY os."ParamCode";
