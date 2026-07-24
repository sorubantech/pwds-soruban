INSERT INTO sett."SettingGroups"
("SettingGroupId", "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(1, 'Theme Customizer', 'THEMECUSTOMIZER', 'Components', true, 1, 1, '2025-09-02 18:44:26.525', NULL, NULL, true, false);
INSERT INTO sett."SettingGroups"
("SettingGroupId", "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(2, 'Fundraising & Donations', 'FUNDRAISING', '💰', true, 1, 164, '2026-05-15 16:04:33.250', NULL, NULL, true, false);
INSERT INTO sett."SettingGroups"
("SettingGroupId", "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(3, 'Receipts & Tax', 'RECEIPTS', '📃', true, 2, 164, '2026-05-15 16:04:33.256', NULL, NULL, true, false);
INSERT INTO sett."SettingGroups"
("SettingGroupId", "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(4, 'Communication', 'COMMUNICATION', '📧', true, 3, 164, '2026-05-15 16:04:33.256', NULL, NULL, true, false);
INSERT INTO sett."SettingGroups"
("SettingGroupId", "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(5, 'Contacts & Crm', 'CONTACTS', '👥', true, 4, 164, '2026-05-15 16:04:33.256', NULL, NULL, true, false);
INSERT INTO sett."SettingGroups"
("SettingGroupId", "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(6, 'Organization', 'ORGANIZATION', '🏢', true, 5, 164, '2026-05-15 16:04:33.256', NULL, NULL, true, false);
INSERT INTO sett."SettingGroups"
("SettingGroupId", "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(7, 'Field Collection', 'FIELD', '🚶', true, 6, 164, '2026-05-15 16:04:33.256', NULL, NULL, true, false);
INSERT INTO sett."SettingGroups"
("SettingGroupId", "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(8, 'Reports', 'REPORTS', '📊', true, 7, 164, '2026-05-15 16:04:33.256', NULL, NULL, true, false);
INSERT INTO sett."SettingGroups"
("SettingGroupId", "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(9, 'Security & Privacy', 'SECURITY', '🔒', true, 8, 164, '2026-05-15 16:04:33.256', NULL, NULL, true, false);
INSERT INTO sett."SettingGroups"
("SettingGroupId", "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(10, 'Notifications', 'NOTIFICATIONS', '🔔', true, 9, 164, '2026-05-15 16:04:33.256', NULL, NULL, true, false);
INSERT INTO sett."SettingGroups"
("SettingGroupId", "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(11, 'Regional & Compliance', 'REGIONAL', '🌐', true, 10, 164, '2026-05-15 16:04:33.256', NULL, NULL, true, false);
INSERT INTO sett."SettingGroups"
("SettingGroupId", "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(12, 'Branding & Identity', 'BRANDING', '🎨', true, 11, NULL, '2026-05-20 07:57:34.760', NULL, NULL, true, false);
INSERT INTO sett."SettingGroups"
("SettingGroupId", "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(13, 'Login Page', 'LOGIN', '🔐', true, 12, NULL, '2026-05-20 07:57:39.554', NULL, NULL, true, false);







INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(1, 1, 'Direction', 'DIRECTION', 'false', 'SingleSelectButton', 'Choose your direction', '[ { "id": "6b717ca7-5eb6-4263-9ab2-0a95d40e3fcd", "key": false, "label": "Ltr", "isActive": true }, { "id": "1421a479-b7ae-4225-91f4-4de7e8385a80", "key": true, "label": "Rtl", "isActive": true } ]', false, 'false', 1, '2025-09-02 18:47:14.629', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(2, 1, 'Sidebar Image', 'SIDEBARIMAGE', 'none', 'SingleSelectImage', 'Choose a image of sidebar', '[ { "id": "7215391d-1203-4adb-8049-4741f733148a", "file": "/images/all-img/img-2.jpeg", "isActive": true }, { "id": "121d0981-9f70-4671-8a9a-3d83427a3682", "file": "/images/all-img/img-1.jpeg", "isActive": true } ]', false, '', 1, '2025-09-02 18:47:14.629', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(3, 1, 'Color Scheme', 'COLORSCHEME', 'light', 'SingleSelectButton', 'Choose light or dark scheme', '[ { "id": "af77c100-cf71-43f8-b551-f265ae9c8780", "key": "light", "label": "Light", "icon": "heroicons:sun", "isActive": true }, { "id": "6bee633a-122a-4e65-ac9c-37956357b527", "key": "dark", "label": "Dark", "icon": "heroicons:moon", "isActive": true } ]', false, '', 1, '2025-09-02 18:47:14.629', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(4, 1, 'Navbar Type', 'NAVBARTYPE', 'sticky', 'SingleSelectRadio', 'Choose your navbar type', '[ { "id": "280d9537-c070-43fe-8212-040597f7caff", "key": "sticky", "label": "Sticky", "isActive": true }, { "id": "2aa7e937-c38c-4805-935b-3103b0f47a78", "key": "static", "label": "Static", "isActive": true }, { "id": "d64c3600-bd80-41db-8294-f2fc19304284", "key": "floating", "label": "Floating", "isActive": true }, { "id": "53fc4078-9df7-4f5b-861f-d5e0a304f05c", "key": "hidden", "label": "Hidden", "isActive": true } ]', false, '', 1, '2025-09-02 18:47:14.629', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(5, 1, 'Rounded', 'ROUNDED', '0.5', 'SingleSelectButton', 'Choose the radius', '[ { "id": "06543f42-317a-40c4-87a5-685dedbe440b", "key": "0", "label": "0", "isActive": true }, { "id": "434f35d0-e120-4e10-bab7-0b8e387fe365", "key": "0.3", "label": "0.3", "isActive": true }, { "id": "81732857-b9c0-4c9b-96a4-2438dad00374", "key": "0.5", "label": "0.5", "isActive": true }, { "id": "59307d2f-d6de-4cdc-8cee-bc9211a9d282", "key": "0.75", "label": "0.75", "isActive": true }, { "id": "109c44fc-14ed-4c44-b0b6-cf177f1e0dff", "key": "1.0", "label": "1.0", "isActive": true } ]', false, '', 1, '2025-09-02 18:47:14.629', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(6, 1, 'Footer Type', 'FOOTERTYPE', 'static', 'SingleSelectRadio', 'Choose your footer type', '[ { "id": "8156add6-dc34-463b-a5ba-5fac9291376a", "key": "sticky", "label": "Sticky", "isActive": true }, { "id": "4ceeb504-b4b9-42a1-a9dd-5c1c35e10737", "key": "static", "label": "Static", "isActive": true }, { "id": "0d656857-0fab-4519-8be5-762c3481e921", "key": "hidden", "label": "Hidden", "isActive": true } ]', false, 'sticky', 1, '2025-09-02 18:47:14.629', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(7, 1, 'Sidebar Layout', 'SIDEBARLAYOUT', 'popover', 'SingleSelectIcon', 'Choose your sidebar layout', '[ { "id": "300c9563-be50-4be1-afae-7c3b9dd14c38", "key": "module", "label": "Module", "svg": "VerticalSvg", "disabled": "layout === \"semibox\" || layout === \"horizontal\"", "isActive": true }, { "id": "8158700b-d546-4203-9ab3-8ce7b4d01e26", "key": "classic", "label": "Classic", "svg": "SemiBoxSvg", "disabled": "layout === \"semibox\"", "isActive": true }, { "id": "893f0119-7b72-4548-938c-6b9512e9fdc9", "key": "popover", "label": "Popover", "svg": "SemiBoxSvg", "isActive": true } ]', false, 'classic', 1, '2025-09-02 18:47:14.629', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(8, 1, 'Theme', 'THEME', 'blue', 'SingleSelectRadio', 'Choose a theme', '[ { "id": "03156816-6a99-4b5e-a280-510c3cbec279", "key": "zinc", "isActive": true }, { "id": "71c150c6-8f01-4c7b-9bfd-381259878ca6", "key": "slate", "isActive": true }, { "id": "cfda5f50-1309-4913-9e14-8f51cbc4e898", "key": "stone", "isActive": true }, { "id": "22c35fa8-0a72-40a6-8dbb-40d71774cb62", "key": "gray", "isActive": true }, { "id": "25360473-61ea-4c2a-9c09-b8da174e545d", "key": "neutral", "isActive": true }, { "id": "d0ee87c9-d642-49b8-a5ee-b6111f6d358f", "key": "red", "isActive": true }, { "id": "c1f2df7e-e1c0-44a6-b226-4da5a4eff6ed", "key": "rose", "isActive": true }, { "id": "c83032e2-ea49-40b6-922b-bd0ad652b662", "key": "orange", "isActive": true }, { "id": "eaea1711-cb89-4fec-8e40-b383841b7638", "key": "blue", "isActive": true }, { "id": "eb29471d-5828-42c9-bb52-d3f605d17d87", "key": "yellow", "isActive": true }, { "id": "e9863f42-a48a-4f3f-bcaf-c942cafce213", "key": "violet", "isActive": true } ]', false, '', 1, '2025-09-02 18:47:14.629', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(9, 1, 'Layout', 'LAYOUT', 'vertical', 'SingleSelectIcon', 'Choose your layout', '[ { "id": "16ca0555-acf3-452e-b8fe-196a1ad31730", "key": "vertical", "label": "Vertical", "svg": "VerticalSvg", "isActive": true }, { "id": "e22bb8ac-5386-4192-84e8-fcadd80268c2", "key": "horizontal", "label": "Horizontal", "svg": "HorizontalSvg", "isActive": true }, { "id": "aaf9e6e6-7632-4baf-a7ab-c873ec2c45cf", "key": "semibox", "label": "Semi-Box", "svg": "SemiBoxSvg", "isActive": true } ]', false, '', 1, '2025-09-02 18:47:14.629', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(10, 2, 'Default Currency', 'DEFAULT_CURRENCY', 'AED', 'SELECT', 'Default currency for new donations', 'AED|USD|EUR|GBP|INR|SAR', false, 'AED', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(11, 2, 'Allow Multi-currency', 'ALLOW_MULTI_CURRENCY', 'true', 'BOOLEAN', 'Allow donations in different currencies', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(12, 2, 'Minimum Donation Amount', 'MIN_DONATION_AMOUNT', '1.00', 'NUMBER', 'Minimum amount accepted', '0|999999|0.01', false, '1.00', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(13, 2, 'Maximum Donation Amount', 'MAX_DONATION_AMOUNT', '1000000', 'NUMBER', 'Maximum single donation (0 = unlimited)', '0|99999999|1', false, '1000000', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(14, 2, 'Auto-generate Receipt', 'AUTO_GENERATE_RECEIPT', 'true', 'BOOLEAN', 'Automatically create receipt on donation entry', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(15, 2, 'Receipt Delivery Default', 'RECEIPT_DELIVERY_DEFAULT', 'Email', 'SELECT', 'Default receipt delivery method', 'Email|WhatsApp|Print|None', false, 'Email', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(16, 2, 'Require Purpose', 'REQUIRE_PURPOSE', 'true', 'BOOLEAN', 'Mandate purpose selection for every donation', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(17, 2, 'Default Purpose', 'DEFAULT_PURPOSE', 'General Fund', 'SELECT', 'Pre-selected purpose when creating donation', 'General Fund|Education|Healthcare|Disaster Relief|Orphan Sponsorship', false, 'General Fund', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(18, 2, 'Allow Anonymous Donations', 'ALLOW_ANONYMOUS_DONATIONS', 'true', 'BOOLEAN', 'Allow donations without linked contact', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(19, 2, 'Duplicate Check Window', 'DUPLICATE_CHECK_WINDOW', '24 hours', 'SELECT', 'Time window to flag potential duplicates', '1 hour|6 hours|12 hours|24 hours|48 hours|7 days', false, '24 hours', 164, '2026-05-15 16:04:34.867', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(20, 2, 'Duplicate Check Fields', 'DUPLICATE_CHECK_FIELDS', 'Amount,Date,Contact', 'MULTI_CHECK', 'Fields to compare for duplicate detection', 'Amount|Date|Contact|Purpose', false, 'Amount,Date,Contact', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(21, 2, 'Online Donation Confirmation', 'ONLINE_DONATION_CONFIRMATION', 'true', 'BOOLEAN', 'Send confirmation email for online donations', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(22, 2, 'Pledge Reminder Days', 'PLEDGE_REMINDER_DAYS', '7,14,30', 'TAGS', 'Days before pledge due date to send reminders', NULL, false, '7,14,30', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(23, 2, 'Recurring Retry Attempts', 'RECURRING_RETRY_ATTEMPTS', '3', 'SELECT', 'Number of retries for failed recurring payments', '1|2|3|5', false, '3', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(24, 2, 'Recurring Retry Interval', 'RECURRING_RETRY_INTERVAL', '3 days', 'SELECT', 'Days between retry attempts', '1 day|3 days|5 days|7 days', false, '3 days', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(29, 3, 'Tax Exempt Organization', 'TAX_EXEMPT_ORG', 'true', 'BOOLEAN', 'Organization is tax-exempt', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(30, 3, 'Tax Section', 'TAX_SECTION', '80G', 'STRING', 'Applicable tax section (80G, 501c3, etc.)', NULL, false, '80G', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(31, 3, 'Show Tax Info On Receipt', 'SHOW_TAX_INFO_ON_RECEIPT', 'true', 'BOOLEAN', 'Include tax exemption details on receipts', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(32, 3, 'Receipt Validity Days', 'RECEIPT_VALIDITY_DAYS', '365', 'NUMBER', 'Days before receipt download links expire', '0|3650|1', false, '365', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(33, 3, 'Require Receipt Signature', 'REQUIRE_RECEIPT_SIGNATURE', 'false', 'BOOLEAN', 'Require authorized signatory on receipts', NULL, false, 'false', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(34, 3, 'Authorized Signatory', 'AUTHORIZED_SIGNATORY', '', 'STRING', 'Name and title for receipt signature', NULL, false, '', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(35, 4, 'Email Daily Limit', 'EMAIL_DAILY_LIMIT', '5000', 'NUMBER', 'Maximum emails per day', '0|1000000|1', false, '5000', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(36, 4, 'Sms Daily Limit', 'SMS_DAILY_LIMIT', '2000', 'NUMBER', 'Maximum SMS per day', '0|1000000|1', false, '2000', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(37, 4, 'Whatsapp Daily Limit', 'WHATSAPP_DAILY_LIMIT', '1000', 'NUMBER', 'Maximum WhatsApp messages per day', '0|1000000|1', false, '1000', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(38, 4, 'Quiet Hours Start', 'QUIET_HOURS_START', '22:00', 'TIME', 'No automated messages after this time', NULL, false, '22:00', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(39, 4, 'Quiet Hours End', 'QUIET_HOURS_END', '07:00', 'TIME', 'Resume automated messages after this time', NULL, false, '07:00', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(40, 4, 'Unsubscribe Link Required', 'UNSUBSCRIBE_LINK_REQUIRED', 'true', 'BOOLEAN', 'Include unsubscribe in all marketing emails', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(41, 4, 'Auto-archive Campaigns', 'AUTO_ARCHIVE_CAMPAIGNS', '30 days', 'SELECT', 'Archive completed campaigns after N days', '7 days|14 days|30 days|60 days|90 days', false, '30 days', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(42, 4, 'Default Reply-to', 'DEFAULT_REPLY_TO', 'info@example.org', 'EMAIL', 'Default reply-to for outgoing emails', NULL, false, 'info@example.org', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(43, 4, 'Bounce Handling', 'BOUNCE_HANDLING', 'Auto-deactivate after 3', 'SELECT', 'Action after N bounces', 'Auto-deactivate after 1|Auto-deactivate after 3|Auto-deactivate after 5|Manual review', false, 'Auto-deactivate after 3', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(44, 5, 'Auto-merge Duplicates', 'AUTO_MERGE_DUPLICATES', 'false', 'BOOLEAN', 'Automatically merge contacts with same email/phone', NULL, false, 'false', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(45, 5, 'Default Contact Type', 'DEFAULT_CONTACT_TYPE', 'Individual', 'SELECT', 'Default type when creating new contacts', 'Individual|Organization', false, 'Individual', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(46, 5, 'Require Email Or Phone', 'REQUIRE_EMAIL_OR_PHONE', 'true', 'BOOLEAN', 'At least one contact method is required', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(48, 5, 'Inactive After Days', 'INACTIVE_AFTER_DAYS', '365', 'NUMBER', 'Mark contact inactive after N days without activity', '0|3650|1', false, '365', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(49, 5, 'Allow Contact Delete', 'ALLOW_CONTACT_DELETE', 'false', 'BOOLEAN', 'Allow permanent deletion of contacts (vs soft-delete only)', NULL, false, 'false', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(50, 5, 'Gdpr Data Retention', 'GDPR_DATA_RETENTION', '5 years', 'SELECT', 'Data retention period for contact records', '1 year|2 years|5 years|7 years|Indefinite', false, '5 years', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(51, 6, 'Financial Year Start', 'FINANCIAL_YEAR_START', 'January', 'SELECT', 'Month the financial year begins', 'January|February|March|April|May|June|July|August|September|October|November|December', false, 'January', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(52, 6, 'Default Language', 'DEFAULT_LANGUAGE', 'English', 'SELECT', 'Default system language', 'English|Arabic|Hindi|French', false, 'English', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(53, 6, 'Date Format', 'DATE_FORMAT', 'DD/MM/YYYY', 'SELECT', 'System-wide date display format', 'DD/MM/YYYY|MM/DD/YYYY|YYYY-MM-DD', false, 'DD/MM/YYYY', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(54, 6, 'Time Zone', 'TIME_ZONE', 'Asia/Dubai (GMT+4)', 'SELECT', 'Default timezone for the organization', 'UTC|Asia/Dubai (GMT+4)|Asia/Kolkata (GMT+5:30)|America/New_York (EST)|Europe/London (GMT)', false, 'Asia/Dubai (GMT+4)', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(55, 6, 'Multi-branch Mode', 'MULTI_BRANCH_MODE', 'true', 'BOOLEAN', 'Enable multi-branch data segregation', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(56, 6, 'Audit Trail Retention', 'AUDIT_TRAIL_RETENTION', '2 years', 'SELECT', 'How long to keep audit trail records', '6 months|1 year|2 years|5 years|Indefinite', false, '2 years', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(57, 7, 'Offline Mode', 'OFFLINE_MODE', 'true', 'BOOLEAN', 'Allow field agents to work offline', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(58, 7, 'Gps Tracking', 'GPS_TRACKING', 'true', 'BOOLEAN', 'Track agent location during collection visits', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(59, 7, 'Max Sync Interval', 'MAX_SYNC_INTERVAL', '15 minutes', 'SELECT', 'Maximum time between data syncs', '5 minutes|15 minutes|30 minutes|1 hour', false, '15 minutes', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(60, 7, 'Photo Required', 'PHOTO_REQUIRED', 'false', 'BOOLEAN', 'Require photo evidence for field collections', NULL, false, 'false', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(61, 7, 'Daily Collection Limit', 'DAILY_COLLECTION_LIMIT', '50', 'NUMBER', 'Maximum collections per agent per day', '0|10000|1', false, '50', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(62, 8, 'Default Export Format', 'DEFAULT_EXPORT_FORMAT', 'Excel (.xlsx)', 'SELECT', 'Default file format for report exports', 'Excel (.xlsx)|CSV|PDF', false, 'Excel (.xlsx)', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(63, 8, 'Max Report Rows', 'MAX_REPORT_ROWS', '50000', 'NUMBER', 'Maximum rows in a single report export', '100|1000000|100', false, '50000', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(64, 8, 'Schedule Report Email', 'SCHEDULE_REPORT_EMAIL', 'true', 'BOOLEAN', 'Allow scheduled report delivery via email', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(65, 8, 'Report Cache Duration', 'REPORT_CACHE_DURATION', '15 minutes', 'SELECT', 'How long to cache generated reports', '5 minutes|15 minutes|1 hour|No cache', false, '15 minutes', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(66, 9, 'Two-factor Authentication', 'TWO_FACTOR_AUTH', 'Required for admins', 'SELECT', '2FA enforcement policy', 'Optional|Required for admins|Required for all', false, 'Required for admins', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(67, 9, 'Password Min Length', 'PASSWORD_MIN_LENGTH', '8', 'NUMBER', 'Minimum password character length', '6|32|1', false, '8', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(68, 9, 'Password Expiry Days', 'PASSWORD_EXPIRY_DAYS', '90', 'NUMBER', 'Force password change after N days (0 = never)', '0|365|1', false, '90', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(69, 9, 'Session Timeout', 'SESSION_TIMEOUT', '30 minutes', 'SELECT', 'Auto-logout after inactivity', '15 minutes|30 minutes|1 hour|4 hours', false, '30 minutes', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(70, 9, 'Max Login Attempts', 'MAX_LOGIN_ATTEMPTS', '5', 'NUMBER', 'Lock account after N failed login attempts', '1|20|1', false, '5', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(71, 9, 'Ip Whitelisting', 'IP_WHITELISTING', 'false', 'BOOLEAN', 'Restrict access to specific IP addresses', NULL, false, 'false', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(72, 9, 'Data Encryption At Rest', 'DATA_ENCRYPTION_AT_REST', 'true', 'BOOLEAN', 'Encrypt sensitive data stored in database', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(73, 9, 'Mask Pii In Logs', 'MASK_PII_IN_LOGS', 'true', 'BOOLEAN', 'Mask personally identifiable information in system logs', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(74, 10, 'In-app Notifications', 'IN_APP_NOTIFICATIONS', 'true', 'BOOLEAN', 'Show notifications within the application', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(75, 10, 'Email Notifications', 'EMAIL_NOTIFICATIONS', 'true', 'BOOLEAN', 'Send notification emails for important events', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(76, 10, 'Daily Digest', 'DAILY_DIGEST', 'true', 'BOOLEAN', 'Send daily summary of all notifications', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(77, 10, 'Digest Send Time', 'DIGEST_SEND_TIME', '08:00', 'TIME', 'Time to send daily digest email', NULL, false, '08:00', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(78, 10, 'Notification Retention', 'NOTIFICATION_RETENTION', '30 days', 'SELECT', 'How long to keep notification history', '7 days|30 days|90 days', false, '30 days', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(79, 11, 'Default Country', 'DEFAULT_COUNTRY', 'United Arab Emirates', 'SELECT', 'Default country for addresses and forms', 'United Arab Emirates|India|United States|United Kingdom|Saudi Arabia', false, 'United Arab Emirates', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(80, 11, 'Gdpr Compliance', 'GDPR_COMPLIANCE', 'true', 'BOOLEAN', 'Enable GDPR-compliant data handling', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(81, 11, 'Consent Required', 'CONSENT_REQUIRED', 'true', 'BOOLEAN', 'Require explicit consent for data collection', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(82, 11, 'Data Residency', 'DATA_RESIDENCY', 'UAE (Middle East)', 'SELECT', 'Primary data storage region', 'UAE (Middle East)|EU (Frankfurt)|US (Virginia)|India (Mumbai)', false, 'UAE (Middle East)', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(83, 11, 'Right To Erasure', 'RIGHT_TO_ERASURE', 'true', 'BOOLEAN', 'Allow contacts to request complete data deletion', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(84, 11, 'Cookie Consent Banner', 'COOKIE_CONSENT_BANNER', 'true', 'BOOLEAN', 'Show cookie consent on public-facing pages', NULL, false, 'true', 164, '2026-05-15 16:04:34.913', NULL, NULL, true, false, NULL);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(85, 12, 'Instagram Url', 'INSTAGRAM_URL', NULL, 'STRING', 'Instagram URL', NULL, true, 'https://instagram.com/humanityfoundation', NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(86, 12, 'Primary Color Hex', 'PRIMARY_COLOR_HEX', '#43436F', 'STRING', 'Primary brand color (CSS var --brand-primary)', NULL, true, '#43436F', NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 1);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(87, 12, 'Favicon Url', 'FAVICON_URL', NULL, 'STRING', 'Browser tab favicon', NULL, true, 'https://placehold.co/32x32/E25822/FFFFFF?text=H', NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(88, 12, 'Favicon Url', 'FAVICON_URL', NULL, 'STRING', 'Browser tab favicon', NULL, true, NULL, NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 1);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(89, 12, 'Instagram Url', 'INSTAGRAM_URL', NULL, 'STRING', 'Instagram URL', NULL, true, NULL, NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 1);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(90, 12, 'Primary Color Hex', 'PRIMARY_COLOR_HEX', '#43436F', 'STRING', 'Primary brand color (CSS var --brand-primary)', NULL, true, '#E25822', NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(91, 12, 'Email Logo Url', 'EMAIL_LOGO_URL', NULL, 'STRING', 'Logo embedded in transactional emails', NULL, true, NULL, NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 1);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(92, 12, 'Youtube Url', 'YOUTUBE_URL', NULL, 'STRING', 'YouTube channel URL', NULL, true, 'https://youtube.com/@humanityfoundation', NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(93, 12, 'Website Url', 'WEBSITE_URL', NULL, 'STRING', 'Public website URL', NULL, true, NULL, NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 1);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(94, 12, 'Logo Url', 'LOGO_URL', NULL, 'STRING', 'Main app logo (header, login page)', NULL, true, NULL, NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 1);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(95, 12, 'App Logo Small Url', 'APP_LOGO_SMALL_URL', NULL, 'STRING', 'Collapsed sidebar / mobile logo', NULL, true, 'https://thumbs.dreamstime.com/b/colorful-people-logo-19190877.jpg?w=768', NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(96, 12, 'Secondary Color Hex', 'SECONDARY_COLOR_HEX', '#7C3AED', 'STRING', 'Secondary brand color (CSS var --brand-secondary)', NULL, true, '#7C3AED', NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 1);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(97, 12, 'Facebook Url', 'FACEBOOK_URL', NULL, 'STRING', 'Facebook page URL', NULL, true, 'https://facebook.com/humanityfoundation', NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(98, 12, 'Email Footer Text', 'EMAIL_FOOTER_TEXT', NULL, 'STRING', 'Multi-line footer for transactional emails', NULL, true, 'Humanity Foundation
123 Hope Street, City
Reg # 80G-HUM-2024', NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(99, 12, 'Twitter Url', 'TWITTER_URL', NULL, 'STRING', 'Twitter / X URL', NULL, true, 'https://twitter.com/humanityorg', NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(100, 12, 'Logo Url', 'LOGO_URL', NULL, 'STRING', 'Main app logo (header, login page)', NULL, true, 'https://thumbs.dreamstime.com/b/colorful-people-logo-19190877.jpg?w=768', NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(101, 12, 'App Logo Small Url', 'APP_LOGO_SMALL_URL', NULL, 'STRING', 'Collapsed sidebar / mobile logo', NULL, true, NULL, NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 1);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(102, 12, 'Email Footer Text', 'EMAIL_FOOTER_TEXT', NULL, 'STRING', 'Multi-line footer for transactional emails', NULL, true, NULL, NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 1);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(103, 12, 'Twitter Url', 'TWITTER_URL', NULL, 'STRING', 'Twitter / X URL', NULL, true, NULL, NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 1);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(104, 12, 'Facebook Url', 'FACEBOOK_URL', NULL, 'STRING', 'Facebook page URL', NULL, true, NULL, NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 1);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(105, 12, 'Secondary Color Hex', 'SECONDARY_COLOR_HEX', '#7C3AED', 'STRING', 'Secondary brand color (CSS var --brand-secondary)', NULL, true, '#2C5F7C', NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(106, 12, 'Website Url', 'WEBSITE_URL', NULL, 'STRING', 'Public website URL', NULL, true, 'https://humanity.org', NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(107, 12, 'Email Logo Url', 'EMAIL_LOGO_URL', NULL, 'STRING', 'Logo embedded in transactional emails', NULL, true, 'https://placehold.co/300x80/E25822/FFFFFF?text=Humanity+Foundation', NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(108, 12, 'Youtube Url', 'YOUTUBE_URL', NULL, 'STRING', 'YouTube channel URL', NULL, true, NULL, NULL, '2026-05-20 07:58:13.222', NULL, NULL, true, false, 1);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(109, 13, 'Login Template Payload', 'LOGIN_TEMPLATE_PAYLOAD', NULL, 'JSON', 'Per-template JSON payload (carousel slides, video URL, hero image URL, etc.)', NULL, true, NULL, NULL, '2026-05-20 07:58:25.408', NULL, NULL, true, false, 1);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(110, 13, 'Login Template Payload', 'LOGIN_TEMPLATE_PAYLOAD', NULL, 'JSON', 'Per-template JSON payload (carousel slides, video URL, hero image URL, etc.)', NULL, true, '{
  "HERO_IMAGE": {
    "imageUrl": "https://thumbs.dreamstime.com/b/dice-form-words-humility-humanity-dice-form-words-humility-humanity-186087729.jpg?w=992",
    "headline": "Building Hope Together",
    "subheadline": "Sign in to manage donations and volunteer activities."
  },
  "HERO_IMAGE_FULL": {
    "imageUrl": "https://picsum.photos/seed/humanity-children/2560/1440"
  },
  "HERO_VIDEO": {
    "videoUrl": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
    "posterUrl": "https://picsum.photos/seed/humanity-poster/1920/1080",
    "headline": "Every Act of Kindness Matters",
    "subheadline": "Welcome back. Sign in to continue your impact."
  },
  "HERO_CAROUSEL_SPLIT": {
    "autoplayMs": 5000,
    "slides": [
      { "imageUrl": "https://www.slideteam.net/media/catalog/product/cache/1280x720/1/1/11_circles_hub_and_spoke_graphic_Slide01.jpg",     "caption": "Clean Water for 2.4M People",        "linkUrl": "https://humanity.org/programs/water",     "orderBy": 1 },
      { "imageUrl": "https://www.slideteam.net/media/catalog/product/cache/1280x720/1/1/11_circles_joining_graphic_with_icons_Slide01.jpg", "caption": "Education That Transforms Lives",    "linkUrl": "https://humanity.org/programs/education", "orderBy": 2 },
      { "imageUrl": "https://www.slideteam.net/media/catalog/product/cache/1280x720/1/1/11_circles_hub_and_spoke_graphic_Slide01.jpg",   "caption": "Medical Aid Where It''s Needed Most", "linkUrl": "https://humanity.org/programs/health",    "orderBy": 3 },
      { "imageUrl": "https://www.slideteam.net/media/catalog/product/cache/1280x720/1/1/11_circles_joining_graphic_with_icons_Slide01.jpg",  "caption": "Rapid Response in Crisis Zones",     "linkUrl": "https://humanity.org/programs/relief",    "orderBy": 4 }
    ]
  },
  "HERO_CAROUSEL_OVERLAY": {
    "autoplayMs": 6000,
    "slides": [
      { "imageUrl": "https://www.slideteam.net/media/catalog/product/cache/1280x720/1/1/11_circles_hub_and_spoke_graphic_Slide01.jpg", "caption": "Every Donation Builds a Future",   "linkUrl": null, "orderBy": 1 },
      { "imageUrl": "https://www.slideteam.net/media/catalog/product/cache/1280x720/1/1/11_circles_joining_graphic_with_icons_Slide01.jpg", "caption": "Compassion in Action, Worldwide",  "linkUrl": null, "orderBy": 2 },
      { "imageUrl": "https://www.slideteam.net/media/catalog/product/cache/1280x720/1/1/11_circles_hub_and_spoke_graphic_Slide01.jpg", "caption": "Hope That Travels Beyond Borders", "linkUrl": null, "orderBy": 3 }
    ]
  },
  "HERO_CAROUSEL_TESTIMONIAL": {
    "autoplayMs": 6500,
    "slides": [
      { "imageUrl": "https://www.slideteam.net/media/catalog/product/cache/1280x720/1/1/11_circles_joining_graphic_with_icons_Slide01.jpg", "caption": "Humanity Foundation rebuilt our school in just three months. Two hundred children now learn under a safe roof.", "linkUrl": "https://humanity.org/stories/school",     "orderBy": 1 },
      { "imageUrl": "https://www.slideteam.net/media/catalog/product/cache/1280x720/1/1/11_circles_hub_and_spoke_graphic_Slide01.jpg", "caption": "The medical camp reached our village when no one else would. My daughter is alive because of their volunteers.",     "linkUrl": "https://humanity.org/stories/medical",    "orderBy": 2 },
      { "imageUrl": "https://www.slideteam.net/media/catalog/product/cache/1280x720/1/1/11_circles_joining_graphic_with_icons_Slide01.jpg", "caption": "Clean water flowing from a single well changed everything for forty families. This is what real impact looks like.", "linkUrl": "https://humanity.org/stories/water",      "orderBy": 3 }
    ]
  },
"HERO_VIDEO_SPLIT": {
    "videoUrl": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
    "posterUrl": "https://picsum.photos/seed/humanity-vsplit-poster/1920/1080",
    "headline": "Stories That Move the World",
    "subheadline": "Sign in to follow our field work in real time."
  },
  "HERO_VIDEO_OVERLAY": {
    "videoUrl": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4",
    "posterUrl": "https://picsum.photos/seed/humanity-voverlay-poster/2560/1440",
    "headline": "Witness the Change You Fund",
    "subheadline": "Welcome back. Continue your impact."
  },
  "CARD_MINIMAL": {
    "headline": "Welcome to Humanity Foundation",
    "subheadline": "Sign in to your account."
  },
"CARD_GLASS": {
    "headline": "Compassion takes you further.",
    "subheadline": "Sign in to coordinate today''s relief efforts."
  },
  "CARD_GRADIENT": {
    "headline": "Bright futures begin with you.",
    "subheadline": "Sign in to track donations and stories of impact."
  }
}', NULL, '2026-05-20 07:58:25.408', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(111, 13, 'Login Page Background Color', 'LOGIN_PAGE_BACKGROUND_COLOR', '#0f172a', 'STRING', 'Fallback background color while media loads or when no media is configured', NULL, true, '#0f172a', NULL, '2026-05-20 07:58:25.408', NULL, NULL, true, false, 1);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(112, 13, 'Login Template Code', 'LOGIN_TEMPLATE_CODE', 'BGIMAGE', 'SELECT', 'Which login layout the tenant uses', 'BGIMAGE|CAROUSEL|BGVIDEO|FULLIMAGE|MINIMAL', true, 'BGIMAGE', NULL, '2026-05-20 07:58:25.408', NULL, NULL, true, false, 1);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(113, 13, 'Login Template Code', 'LOGIN_TEMPLATE_CODE', 'HERO_IMAGE', 'SELECT', 'Which login layout the tenant uses', 'HERO_IMAGE|HERO_IMAGE_FULL|HERO_CAROUSEL_SPLIT|HERO_CAROUSEL_OVERLAY|HERO_CAROUSEL_TESTIMONIAL|HERO_VIDEO|HERO_VIDEO_SPLIT|HERO_VIDEO_OVERLAY|CARD_MINIMAL|CARD_GLASS|CARD_GRADIENT', true, 'HERO_VIDEO_OVERLAY', NULL, '2026-05-20 07:58:25.408', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(114, 13, 'Login Page Background Color', 'LOGIN_PAGE_BACKGROUND_COLOR', '#0f172a', 'STRING', 'Fallback background color while media loads or when no media is configured', NULL, true, '#0A1929', NULL, '2026-05-20 07:58:25.408', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(115, 2, 'Default Currency', 'DEFAULT_CURRENCY', 'AED', 'SELECT', 'Default currency for new donations', 'AED|USD|EUR|GBP|INR|SAR', false, 'AED', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(116, 2, 'Allow Multi-currency', 'ALLOW_MULTI_CURRENCY', 'true', 'BOOLEAN', 'Allow donations in different currencies', NULL, false, 'true', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(117, 2, 'Minimum Donation Amount', 'MIN_DONATION_AMOUNT', '1.00', 'NUMBER', 'Minimum amount accepted', '0|999999|0.01', false, '1.00', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(118, 2, 'Maximum Donation Amount', 'MAX_DONATION_AMOUNT', '1000000', 'NUMBER', 'Maximum single donation (0 = unlimited)', '0|99999999|1', false, '1000000', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(119, 2, 'Auto-generate Receipt', 'AUTO_GENERATE_RECEIPT', 'true', 'BOOLEAN', 'Automatically create receipt on donation entry', NULL, false, 'true', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(120, 2, 'Receipt Delivery Default', 'RECEIPT_DELIVERY_DEFAULT', 'Email', 'SELECT', 'Default receipt delivery method', 'Email|WhatsApp|Print|None', false, 'Email', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(121, 2, 'Require Purpose', 'REQUIRE_PURPOSE', 'true', 'BOOLEAN', 'Mandate purpose selection for every donation', NULL, false, 'true', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(122, 2, 'Default Purpose', 'DEFAULT_PURPOSE', 'General Fund', 'SELECT', 'Pre-selected purpose when creating donation', 'General Fund|Education|Healthcare|Disaster Relief|Orphan Sponsorship', false, 'General Fund', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(123, 2, 'Allow Anonymous Donations', 'ALLOW_ANONYMOUS_DONATIONS', 'true', 'BOOLEAN', 'Allow donations without linked contact', NULL, false, 'true', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(124, 2, 'Duplicate Check Window', 'DUPLICATE_CHECK_WINDOW', '24 hours', 'SELECT', 'Time window to flag potential duplicates', '1 hour|6 hours|12 hours|24 hours|48 hours|7 days', false, '24 hours', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(125, 2, 'Duplicate Check Fields', 'DUPLICATE_CHECK_FIELDS', 'Amount,Date,Contact', 'MULTI_CHECK', 'Fields to compare for duplicate detection', 'Amount|Date|Contact|Purpose', false, 'Amount,Date,Contact', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(126, 2, 'Online Donation Confirmation', 'ONLINE_DONATION_CONFIRMATION', 'true', 'BOOLEAN', 'Send confirmation email for online donations', NULL, false, 'true', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(127, 2, 'Pledge Reminder Days', 'PLEDGE_REMINDER_DAYS', '7,14,30', 'TAGS', 'Days before pledge due date to send reminders', NULL, false, '7,14,30', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(128, 2, 'Recurring Retry Attempts', 'RECURRING_RETRY_ATTEMPTS', '3', 'SELECT', 'Number of retries for failed recurring payments', '1|2|3|5', false, '3', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(129, 2, 'Recurring Retry Interval', 'RECURRING_RETRY_INTERVAL', '3 days', 'SELECT', 'Days between retry attempts', '1 day|3 days|5 days|7 days', false, '3 days', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(134, 3, 'Tax Exempt Organization', 'TAX_EXEMPT_ORG', 'true', 'BOOLEAN', 'Organization is tax-exempt', NULL, false, 'true', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(135, 3, 'Tax Section', 'TAX_SECTION', '80G', 'STRING', 'Applicable tax section (80G, 501c3, etc.)', NULL, false, '80G', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(136, 3, 'Show Tax Info On Receipt', 'SHOW_TAX_INFO_ON_RECEIPT', 'true', 'BOOLEAN', 'Include tax exemption details on receipts', NULL, false, 'true', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(137, 3, 'Receipt Validity Days', 'RECEIPT_VALIDITY_DAYS', '365', 'NUMBER', 'Days before receipt download links expire', '0|3650|1', false, '365', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(138, 3, 'Require Receipt Signature', 'REQUIRE_RECEIPT_SIGNATURE', 'false', 'BOOLEAN', 'Require authorized signatory on receipts', NULL, false, 'false', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(139, 3, 'Authorized Signatory', 'AUTHORIZED_SIGNATORY', '', 'STRING', 'Name and title for receipt signature', NULL, false, '', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(140, 4, 'Email Daily Limit', 'EMAIL_DAILY_LIMIT', '5000', 'NUMBER', 'Maximum emails per day', '0|1000000|1', false, '5000', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(141, 4, 'Sms Daily Limit', 'SMS_DAILY_LIMIT', '2000', 'NUMBER', 'Maximum SMS per day', '0|1000000|1', false, '2000', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(142, 4, 'Whatsapp Daily Limit', 'WHATSAPP_DAILY_LIMIT', '1000', 'NUMBER', 'Maximum WhatsApp messages per day', '0|1000000|1', false, '1000', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(143, 4, 'Quiet Hours Start', 'QUIET_HOURS_START', '22:00', 'TIME', 'No automated messages after this time', NULL, false, '22:00', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(144, 4, 'Quiet Hours End', 'QUIET_HOURS_END', '07:00', 'TIME', 'Resume automated messages after this time', NULL, false, '07:00', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(145, 4, 'Unsubscribe Link Required', 'UNSUBSCRIBE_LINK_REQUIRED', 'true', 'BOOLEAN', 'Include unsubscribe in all marketing emails', NULL, false, 'true', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(146, 4, 'Auto-archive Campaigns', 'AUTO_ARCHIVE_CAMPAIGNS', '30 days', 'SELECT', 'Archive completed campaigns after N days', '7 days|14 days|30 days|60 days|90 days', false, '30 days', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(147, 4, 'Default Reply-to', 'DEFAULT_REPLY_TO', 'info@example.org', 'EMAIL', 'Default reply-to for outgoing emails', NULL, false, 'info@example.org', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(148, 4, 'Bounce Handling', 'BOUNCE_HANDLING', 'Auto-deactivate after 3', 'SELECT', 'Action after N bounces', 'Auto-deactivate after 1|Auto-deactivate after 3|Auto-deactivate after 5|Manual review', false, 'Auto-deactivate after 3', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(149, 5, 'Auto-merge Duplicates', 'AUTO_MERGE_DUPLICATES', 'false', 'BOOLEAN', 'Automatically merge contacts with same email/phone', NULL, false, 'false', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(150, 5, 'Default Contact Type', 'DEFAULT_CONTACT_TYPE', 'Individual', 'SELECT', 'Default type when creating new contacts', 'Individual|Organization', false, 'Individual', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(151, 5, 'Require Email Or Phone', 'REQUIRE_EMAIL_OR_PHONE', 'true', 'BOOLEAN', 'At least one contact method is required', NULL, false, 'true', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(153, 5, 'Inactive After Days', 'INACTIVE_AFTER_DAYS', '365', 'NUMBER', 'Mark contact inactive after N days without activity', '0|3650|1', false, '365', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(154, 5, 'Allow Contact Delete', 'ALLOW_CONTACT_DELETE', 'false', 'BOOLEAN', 'Allow permanent deletion of contacts (vs soft-delete only)', NULL, false, 'false', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(155, 5, 'Gdpr Data Retention', 'GDPR_DATA_RETENTION', '5 years', 'SELECT', 'Data retention period for contact records', '1 year|2 years|5 years|7 years|Indefinite', false, '5 years', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(156, 6, 'Financial Year Start', 'FINANCIAL_YEAR_START', 'January', 'SELECT', 'Month the financial year begins', 'January|February|March|April|May|June|July|August|September|October|November|December', false, 'January', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(157, 6, 'Default Language', 'DEFAULT_LANGUAGE', 'English', 'SELECT', 'Default system language', 'English|Arabic|Hindi|French', false, 'English', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(158, 6, 'Date Format', 'DATE_FORMAT', 'DD/MM/YYYY', 'SELECT', 'System-wide date display format', 'DD/MM/YYYY|MM/DD/YYYY|YYYY-MM-DD', false, 'DD/MM/YYYY', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(159, 6, 'Time Zone', 'TIME_ZONE', 'Asia/Dubai (GMT+4)', 'SELECT', 'Default timezone for the organization', 'UTC|Asia/Dubai (GMT+4)|Asia/Kolkata (GMT+5:30)|America/New_York (EST)|Europe/London (GMT)', false, 'Asia/Dubai (GMT+4)', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(160, 6, 'Multi-branch Mode', 'MULTI_BRANCH_MODE', 'true', 'BOOLEAN', 'Enable multi-branch data segregation', NULL, false, 'true', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(161, 6, 'Audit Trail Retention', 'AUDIT_TRAIL_RETENTION', '2 years', 'SELECT', 'How long to keep audit trail records', '6 months|1 year|2 years|5 years|Indefinite', false, '2 years', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(162, 7, 'Offline Mode', 'OFFLINE_MODE', 'true', 'BOOLEAN', 'Allow field agents to work offline', NULL, false, 'true', 164, '2026-05-20 10:49:23.519', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(163, 7, 'Gps Tracking', 'GPS_TRACKING', 'true', 'BOOLEAN', 'Track agent location during collection visits', NULL, false, 'true', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(164, 7, 'Max Sync Interval', 'MAX_SYNC_INTERVAL', '15 minutes', 'SELECT', 'Maximum time between data syncs', '5 minutes|15 minutes|30 minutes|1 hour', false, '15 minutes', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(165, 7, 'Photo Required', 'PHOTO_REQUIRED', 'false', 'BOOLEAN', 'Require photo evidence for field collections', NULL, false, 'false', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(166, 7, 'Daily Collection Limit', 'DAILY_COLLECTION_LIMIT', '50', 'NUMBER', 'Maximum collections per agent per day', '0|10000|1', false, '50', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(167, 8, 'Default Export Format', 'DEFAULT_EXPORT_FORMAT', 'Excel (.xlsx)', 'SELECT', 'Default file format for report exports', 'Excel (.xlsx)|CSV|PDF', false, 'Excel (.xlsx)', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(168, 8, 'Max Report Rows', 'MAX_REPORT_ROWS', '50000', 'NUMBER', 'Maximum rows in a single report export', '100|1000000|100', false, '50000', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(169, 8, 'Schedule Report Email', 'SCHEDULE_REPORT_EMAIL', 'true', 'BOOLEAN', 'Allow scheduled report delivery via email', NULL, false, 'true', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(170, 8, 'Report Cache Duration', 'REPORT_CACHE_DURATION', '15 minutes', 'SELECT', 'How long to cache generated reports', '5 minutes|15 minutes|1 hour|No cache', false, '15 minutes', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(171, 9, 'Two-factor Authentication', 'TWO_FACTOR_AUTH', 'Required for admins', 'SELECT', '2FA enforcement policy', 'Optional|Required for admins|Required for all', false, 'Required for admins', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(172, 9, 'Password Min Length', 'PASSWORD_MIN_LENGTH', '8', 'NUMBER', 'Minimum password character length', '6|32|1', false, '8', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(173, 9, 'Password Expiry Days', 'PASSWORD_EXPIRY_DAYS', '90', 'NUMBER', 'Force password change after N days (0 = never)', '0|365|1', false, '90', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(174, 9, 'Session Timeout', 'SESSION_TIMEOUT', '30 minutes', 'SELECT', 'Auto-logout after inactivity', '15 minutes|30 minutes|1 hour|4 hours', false, '30 minutes', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(175, 9, 'Max Login Attempts', 'MAX_LOGIN_ATTEMPTS', '5', 'NUMBER', 'Lock account after N failed login attempts', '1|20|1', false, '5', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(176, 9, 'Ip Whitelisting', 'IP_WHITELISTING', 'false', 'BOOLEAN', 'Restrict access to specific IP addresses', NULL, false, 'false', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(177, 9, 'Data Encryption At Rest', 'DATA_ENCRYPTION_AT_REST', 'true', 'BOOLEAN', 'Encrypt sensitive data stored in database', NULL, false, 'true', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(178, 9, 'Mask Pii In Logs', 'MASK_PII_IN_LOGS', 'true', 'BOOLEAN', 'Mask personally identifiable information in system logs', NULL, false, 'true', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(179, 10, 'In-app Notifications', 'IN_APP_NOTIFICATIONS', 'true', 'BOOLEAN', 'Show notifications within the application', NULL, false, 'true', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(180, 10, 'Email Notifications', 'EMAIL_NOTIFICATIONS', 'true', 'BOOLEAN', 'Send notification emails for important events', NULL, false, 'true', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(181, 10, 'Daily Digest', 'DAILY_DIGEST', 'true', 'BOOLEAN', 'Send daily summary of all notifications', NULL, false, 'true', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(182, 10, 'Digest Send Time', 'DIGEST_SEND_TIME', '08:00', 'TIME', 'Time to send daily digest email', NULL, false, '08:00', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(183, 10, 'Notification Retention', 'NOTIFICATION_RETENTION', '30 days', 'SELECT', 'How long to keep notification history', '7 days|30 days|90 days', false, '30 days', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(184, 11, 'Default Country', 'DEFAULT_COUNTRY', 'United Arab Emirates', 'SELECT', 'Default country for addresses and forms', 'United Arab Emirates|India|United States|United Kingdom|Saudi Arabia', false, 'United Arab Emirates', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(185, 11, 'Gdpr Compliance', 'GDPR_COMPLIANCE', 'true', 'BOOLEAN', 'Enable GDPR-compliant data handling', NULL, false, 'true', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(186, 11, 'Consent Required', 'CONSENT_REQUIRED', 'true', 'BOOLEAN', 'Require explicit consent for data collection', NULL, false, 'true', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(187, 11, 'Data Residency', 'DATA_RESIDENCY', 'UAE (Middle East)', 'SELECT', 'Primary data storage region', 'UAE (Middle East)|EU (Frankfurt)|US (Virginia)|India (Mumbai)', false, 'UAE (Middle East)', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(188, 11, 'Right To Erasure', 'RIGHT_TO_ERASURE', 'true', 'BOOLEAN', 'Allow contacts to request complete data deletion', NULL, false, 'true', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);
INSERT INTO sett."OrganizationSettings"
("OrganizationSettingId", "SettingGroupId", "ParamName", "ParamCode", "ParamDefaultValue", "ParamDataType", "Description", "AllValues", "CanUserOverride", "CurrentValue", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted", "CompanyId")
VALUES(189, 11, 'Cookie Consent Banner', 'COOKIE_CONSENT_BANNER', 'true', 'BOOLEAN', 'Show cookie consent on public-facing pages', NULL, false, 'true', 164, '2026-05-20 10:49:23.520', NULL, NULL, true, false, 3);

-- ============================================================
-- Cleanup — remove number-sequence ParamCodes that duplicate the real
-- NumberSequenceGenerator (Company Settings §9 / sett.NumberSequence* tables).
-- These 5 keys were inert strings with no runtime reader; NEXT_RECEIPT_NUMBER
-- was even user-editable and could silently desync from the live counter.
-- Canonical owners:
--   RECEIPT_NUMBER_PREFIX/FORMAT/NEXT_RECEIPT_NUMBER/FINANCIAL_YEAR_RESET
--     -> sett.NumberSequenceEntityTypes/Configs for entity GLOBALDONATION
--   CONTACT_CODE_FORMAT
--     -> sett.NumberSequenceEntityTypes/Configs for entity CONTACT
-- Removed from the INSERT list above; this idempotent DELETE also clears any
-- rows already seeded into existing tenant databases.  CanUserOverride was
-- false for all 5, so there are no UserSettings overrides to cascade.
-- ============================================================
DELETE FROM sett."OrganizationSettings"
WHERE "ParamCode" IN (
    'RECEIPT_NUMBER_PREFIX',
    'RECEIPT_NUMBER_FORMAT',
    'NEXT_RECEIPT_NUMBER',
    'FINANCIAL_YEAR_RESET',
    'CONTACT_CODE_FORMAT'
);

-- ============================================================
-- Cleanup 2 — entity-shadow codes moved to dedicated screens
-- (settings reconciliation, 2026-07-22 — see repo-root
--  PSS-2.0-SETTINGS-SCREEN-RECONCILIATION.md §5B).
-- These ParamCodes shadow entities that own their own expandable
-- screen + table; they must not be edited/seeded in the generic
-- settings store.  The matching INSERT rows above are LEFT IN PLACE
-- on purpose so this is trivially reversible — to un-move a code,
-- delete its line from this DELETE list and the seed row re-lands.
--
-- Canonical owners:
--   TAX_EXEMPT_ORG / TAX_SECTION / SHOW_TAX_INFO_ON_RECEIPT /
--   RECEIPT_VALIDITY_DAYS / REQUIRE_RECEIPT_SIGNATURE /
--   AUTHORIZED_SIGNATORY  -> #9 Receipt & Tax Management
--                            (fund.CountryTaxConfig / fund.ReceiptTemplate)
--   DEFAULT_PURPOSE        -> #2 Donation Purpose  (IsDefault flag)
--   DEFAULT_CONTACT_TYPE   -> #19 Contact Type      (IsDefault flag)
--
-- ⚠ PREREQUISITE before running this block: confirm each destination
--   screen actually absorbs the field (e.g. #9 captures AUTHORIZED_SIGNATORY
--   / RECEIPT_VALIDITY_DAYS; #2 and #19 expose an IsDefault).  If a
--   destination is not ready, remove that ParamCode from the list below.
--
-- NOT removed (kept, reassigned — see §5B refinement):
--   DEFAULT_CURRENCY      -> #75 (org base-currency identity)
--   ALLOW_MULTI_CURRENCY  -> #85 (policy toggle)
-- NOT present in seed at all: ALLOWED_CURRENCIES (0 rows).
-- ============================================================
DELETE FROM sett."OrganizationSettings"
WHERE "ParamCode" IN (
    'TAX_EXEMPT_ORG',
    'TAX_SECTION',
    'SHOW_TAX_INFO_ON_RECEIPT',
    'RECEIPT_VALIDITY_DAYS',
    'REQUIRE_RECEIPT_SIGNATURE',
    'AUTHORIZED_SIGNATORY',
    'DEFAULT_PURPOSE',
    'DEFAULT_CONTACT_TYPE'
);