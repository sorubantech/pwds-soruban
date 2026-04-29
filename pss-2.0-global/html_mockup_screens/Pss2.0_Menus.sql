INSERT INTO auth."Modules"
("ModuleId", "ModuleName", "ModuleCode", "ModuleUrl", "Description", "OrderBy", "ModuleIcon", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES('51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'Setting', 'SETTING', '/setting/dashboards/overview', 'Payment, communication, donation config, public pages, integrations', 5, 'solar:settings-bold', 1, '2025-09-03 11:42:57.371', 5, '2026-01-30 09:30:50.579', true, false);
INSERT INTO auth."Modules"
("ModuleId", "ModuleName", "ModuleCode", "ModuleUrl", "Description", "OrderBy", "ModuleIcon", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES('4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, 'Report & Audit', 'REPORTAUDIT', '/reportaudit/dashboards/overview', 'Reports, analytics, audit trail', 6, 'solar:chart-square-bold', 1, '2025-09-03 11:42:57.371', 5, '2026-01-30 09:30:50.579', true, false);
INSERT INTO auth."Modules"
("ModuleId", "ModuleName", "ModuleCode", "ModuleUrl", "Description", "OrderBy", "ModuleIcon", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES('eda573b9-a49c-4ac3-8281-c693f9dc38c2'::uuid, 'Access Control', 'ACCESSCONTROL', '/accesscontrol/dashboards/overview', 'Users, roles, capabilities, governance', 3, 'solar:shield-keyhole-bold', 1, '2025-08-26 12:37:32.675', 5, '2026-01-28 14:00:15.118', true, false);
INSERT INTO auth."Modules"
("ModuleId", "ModuleName", "ModuleCode", "ModuleUrl", "Description", "OrderBy", "ModuleIcon", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES('aab02c59-71ff-4cd3-9062-5802f0f74156'::uuid, 'Organization', 'ORGANIZATION', '/organization/dashboards/overview', 'Organization configuration', 2, 'solar:buildings-bold', 5, '2026-01-28 14:51:23.478', NULL, NULL, true, false);
INSERT INTO auth."Modules"
("ModuleId", "ModuleName", "ModuleCode", "ModuleUrl", "Description", "OrderBy", "ModuleIcon", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES('e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'CRM', 'CRM', '/crm/dashboards/overview', 'Contacts, Donations, Communication, Volunteers, Membership, Grants, Cases, Intelligence', 1, 'solar:people-nearby-bold', 1, '2025-09-03 11:42:57.371', 5, '2026-01-30 09:30:50.579', true, false);
INSERT INTO auth."Modules"
("ModuleId", "ModuleName", "ModuleCode", "ModuleUrl", "Description", "OrderBy", "ModuleIcon", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES('f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'General', 'GENERAL', '/general/dashboards/overview', 'Region hierarchy, master data', 4, 'solar:database-bold', 1, '2025-09-03 11:42:57.371', 5, '2026-01-30 09:30:50.579', true, false);



INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(258, 'Contact', 'CRM_CONTACT', NULL, 'solar:user-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 2, false, 2, '2026-04-14 17:44:59.586', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(259, 'Family', 'CRM_FAMILY', NULL, 'solar:users-group-rounded-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 3, false, 2, '2026-04-14 17:45:03.737', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(260, 'Maintenance', 'CRM_MAINTENANCE', NULL, 'solar:tuning-2-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 4, false, 2, '2026-04-14 17:45:07.370', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(261, 'Certificate', 'CRM_CERTIFICATE', NULL, 'solar:diploma-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 5, false, 2, '2026-04-14 17:45:10.313', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(262, 'Donation', 'CRM_DONATION', NULL, 'solar:hand-money-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 6, false, 2, '2026-04-14 17:45:13.099', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(263, 'P2P Fundraising', 'CRM_P2PFUNDRAISING', NULL, 'solar:hand-shake-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 7, false, 2, '2026-04-14 17:45:16.413', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(264, 'Communication', 'CRM_COMMUNICATION', NULL, 'solar:letter-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 8, false, 2, '2026-04-14 17:45:20.920', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(265, 'WhatsApp', 'CRM_WHATSAPP', NULL, 'solar:chat-round-dots-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 9, false, 2, '2026-04-14 17:45:25.297', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(266, 'SMS', 'CRM_SMS', NULL, 'solar:smartphone-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 10, false, 2, '2026-04-14 17:45:29.031', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(267, 'Notification', 'CRM_NOTIFICATION', NULL, 'solar:bell-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 11, false, 2, '2026-04-14 17:45:33.169', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(268, 'Automation', 'CRM_AUTOMATION', NULL, 'solar:bolt-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 12, false, 2, '2026-04-14 17:45:36.396', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(269, 'Prayer Request', 'CRM_PRAYERREQUEST', NULL, 'solar:heart-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 13, false, 2, '2026-04-14 17:45:40.206', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(270, 'Organization', 'CRM_ORGANIZATION', NULL, 'solar:buildings-2-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 14, false, 2, '2026-04-14 17:45:44.029', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(271, 'Event', 'CRM_EVENT', NULL, 'solar:calendar-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 15, false, 2, '2026-04-14 17:45:48.397', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(272, 'Field Collection', 'CRM_FIELDCOLLECTION', NULL, 'solar:map-arrow-right-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 16, false, 2, '2026-04-14 17:45:52.191', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(273, 'Volunteer', 'CRM_VOLUNTEER', NULL, 'solar:hand-heart-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 17, false, 2, '2026-04-14 17:45:56.078', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(274, 'Membership', 'CRM_MEMBERSHIP', NULL, 'solar:card-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 18, false, 2, '2026-04-14 17:45:59.863', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(275, 'Grant', 'CRM_GRANT', NULL, 'solar:document-add-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 19, false, 2, '2026-04-14 17:46:11.164', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(276, 'Case Management', 'CRM_CASEMANAGEMENT', NULL, 'solar:clipboard-list-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 20, false, 2, '2026-04-14 17:46:14.707', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(277, 'Intelligence', 'CRM_INTELLIGENCE', NULL, 'solar:brain-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 21, false, 2, '2026-04-14 17:46:18.206', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(278, 'Dashboards', 'CRM_DASHBOARDS', NULL, 'solar:chart-2-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 1, false, 2, '2026-04-14 17:46:21.586', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(279, 'All Contacts', 'CONTACT', 258, 'solar:user-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/contact/allcontacts', NULL, 1, true, 2, '2026-04-14 17:50:30.329', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(280, 'Contact Types', 'CONTACTTYPE', 258, 'solar:users-group-two-rounded-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/contact/contacttype', NULL, 2, true, 2, '2026-04-14 17:50:34.327', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(281, 'Contact Sources', 'CONTACTSOURCE', 258, 'solar:magnet-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/contact/contactsource', NULL, 3, true, 2, '2026-04-14 17:50:38.335', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(282, 'Tags & Segmentation', 'TAGSEGMENTATION', 258, 'solar:tag-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/contact/tagsegmentation', NULL, 4, true, 2, '2026-04-14 17:50:41.491', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(283, 'Contact Import', 'CONTACTIMPORT', 258, 'solar:import-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/contact/contactimport', NULL, 5, true, 2, '2026-04-14 17:50:45.407', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(284, 'Family Management', 'FAMILY', 259, 'solar:users-group-rounded-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/family/family', NULL, 1, true, 2, '2026-04-14 17:50:52.393', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(285, 'Duplicate Detection', 'DUPLICATECONTACT', 260, 'solar:copy-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/maintenance/duplicatecontact', NULL, 1, true, 2, '2026-04-14 17:50:57.483', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(286, 'Certificate Template', 'CERTIFICATETEMPLATE', 261, 'solar:diploma-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/certificate/certificatetemplate', NULL, 1, true, 2, '2026-04-14 17:51:03.465', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(287, 'Process Certificates', 'PROCESSCERTIFICATES', 261, 'solar:restart-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/certificate/processcertificates', NULL, 2, true, 2, '2026-04-14 17:51:06.903', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(288, 'Print Certificates', 'PRINTCERTIFICATES', 261, 'solar:printer-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/certificate/printcertificates', NULL, 3, true, 2, '2026-04-14 17:51:10.844', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(289, 'All Donations', 'DONATION', 262, 'solar:hand-money-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/donation/globaldonation', NULL, 1, true, 2, '2026-04-14 17:51:16.129', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(290, 'Recurring Donations', 'RECURRINGDONOR', 262, 'solar:repeat-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/donation/recurringdonors', NULL, 2, true, 2, '2026-04-14 17:51:20.519', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(291, 'Cheque Tracking', 'CHEQUEDONATION', 262, 'solar:document-text-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/donation/chequedonation', NULL, 3, true, 2, '2026-04-14 17:51:25.390', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(292, 'In-Kind Donations', 'DONATIONINKIND', 262, 'solar:box-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/donation/donationinkind', NULL, 4, true, 2, '2026-04-14 17:51:28.887', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(293, 'Pledges', 'PLEDGE', 262, 'solar:clipboard-check-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/donation/pledge', NULL, 5, true, 2, '2026-04-14 17:51:31.985', 2, '2026-04-21 18:19:01.653', true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(294, 'Bulk Upload', 'BULKDONATION', 262, 'solar:upload-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/donation/bulkdonation', NULL, 6, true, 2, '2026-04-14 17:51:36.368', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(295, 'P2P Campaigns', 'P2PCAMPAIGN', 263, 'solar:flag-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/p2pfundraising/p2pcampaign', NULL, 1, true, 2, '2026-04-14 17:51:46.494', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(296, 'P2P Fundraisers', 'P2PFUNDRAISER', 263, 'solar:user-speak-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/p2pfundraising/p2pfundraiser', NULL, 2, true, 2, '2026-04-14 17:51:50.746', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(297, 'Crowdfunding', 'CROWDFUNDING', 263, 'solar:users-group-rounded-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/p2pfundraising/crowdfunding', NULL, 3, true, 2, '2026-04-14 17:51:54.079', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(298, 'Matching Gifts', 'MATCHINGGIFT', 263, 'solar:hand-shake-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/p2pfundraising/matchinggift', NULL, 4, true, 2, '2026-04-14 17:51:57.499', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(299, 'Email Templates', 'EMAILTEMPLATE', 264, 'solar:letter-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/communication/emailtemplate', NULL, 1, true, 2, '2026-04-14 17:52:03.990', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(300, 'Email Campaigns', 'EMAILCAMPAIGN', 264, 'solar:mailbox-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/communication/emailcampaign', NULL, 2, true, 2, '2026-04-14 17:52:06.831', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(301, 'Email Analytics', 'EMAILANALYTICS', 264, 'solar:chart-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/communication/emailanalytics', NULL, 3, true, 2, '2026-04-14 17:52:10.431', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(302, 'Email Keywords', 'EMAILKEYWORD', 264, 'solar:text-bold-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/communication/emailkeywords', NULL, 4, true, 2, '2026-04-14 17:52:13.187', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(303, 'Placeholder Definitions', 'PLACEHOLDERDEFINITION', 264, 'solar:code-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/communication/placeholderdefinition', NULL, 5, true, 2, '2026-04-14 17:52:17.454', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(304, 'Saved Filters', 'SAVEDFILTER', 264, 'solar:filter-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/communication/savedfilter', NULL, 6, true, 2, '2026-04-14 17:52:20.521', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(305, 'WhatsApp Templates', 'WHATSAPPTEMPLATE', 265, 'solar:chat-round-dots-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/whatsapp/whatsapptemplate', NULL, 1, true, 2, '2026-04-14 17:52:25.967', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(306, 'WhatsApp Campaigns', 'WHATSAPPCAMPAIGN', 265, 'solar:chat-round-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/whatsapp/whatsappcampaign', NULL, 2, true, 2, '2026-04-14 17:52:28.665', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(307, 'WhatsApp Conversations', 'WHATSAPPCONVERSATION', 265, 'solar:chat-round-line-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/whatsapp/whatsappconversation', NULL, 3, true, 2, '2026-04-14 17:52:33.240', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(308, 'SMS Templates', 'SMSTEMPLATE', 266, 'solar:smartphone-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/sms/smstemplate', NULL, 1, true, 2, '2026-04-14 17:52:37.429', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(309, 'SMS Campaigns', 'SMSCAMPAIGN', 266, 'solar:smartphone-2-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/sms/smscampaign', NULL, 2, true, 2, '2026-04-14 17:52:41.662', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(310, 'Notification Templates', 'NOTIFICATIONTEMPLATE', 267, 'solar:bell-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/notification/notificationtemplate', NULL, 1, true, 2, '2026-04-14 17:52:49.438', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(311, 'Notification Center', 'NOTIFICATION', 267, 'solar:bell-bing-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/notification/notificationcenter', NULL, 2, true, 2, '2026-04-14 17:52:52.465', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(312, 'Automation Workflows', 'AUTOMATIONWORKFLOW', 268, 'solar:bolt-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/automation/automationworkflow', NULL, 1, true, 2, '2026-04-14 17:52:56.373', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(313, 'Prayer Request Entry', 'PRAYERREQUESTENTRY', 269, 'solar:pen-new-square-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/prayerrequest/prayerrequestentry', NULL, 1, true, 2, '2026-04-14 17:53:02.830', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(314, 'Review Reply', 'REVIEWREPLY', 269, 'solar:chat-square-check-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/prayerrequest/reviewreply', NULL, 2, true, 2, '2026-04-14 17:53:06.933', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(315, 'Reply Queue', 'REPLYQUEUE', 269, 'solar:queue-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/prayerrequest/replyqueue', NULL, 3, true, 2, '2026-04-14 17:53:09.836', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(321, 'Events', 'EVENT', 271, 'solar:calendar-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/event/event', NULL, 1, true, 2, '2026-04-14 17:56:00.465', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(322, 'Organizational Units', 'ORGANIZATIONALUNIT', 270, 'solar:buildings-2-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/organization/organizationalunit', NULL, 1, true, 2, '2026-04-14 17:56:06.753', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(323, 'Campaigns', 'CAMPAIGN', 270, 'solar:flag-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/organization/campaign', NULL, 2, true, 2, '2026-04-14 17:56:09.467', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(324, 'Event Ticketing', 'EVENTTICKETING', 271, 'solar:ticket-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/event/eventticketing', NULL, 2, true, 2, '2026-04-14 17:56:20.666', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(325, 'Auction Management', 'AUCTIONMANAGEMENT', 271, 'solar:sledgehammer-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/event/auctionmanagement', NULL, 3, true, 2, '2026-04-14 17:56:24.332', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(326, 'Event Analytics', 'EVENTANALYTICS', 271, 'solar:chart-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/event/eventanalytics', NULL, 4, true, 2, '2026-04-14 17:56:27.780', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(327, 'Ambassador List', 'AMBASSADORLIST', 272, 'solar:users-group-rounded-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/fieldcollection/ambassadorlist', NULL, 1, true, 2, '2026-04-14 17:56:35.575', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(328, 'Record Collection', 'AMBASSADORCOLLECTION', 272, 'solar:notebook-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/fieldcollection/ambassadorcollection', NULL, 2, true, 2, '2026-04-14 17:56:39.945', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(329, 'Collection List', 'COLLECTIONLIST', 272, 'solar:list-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/fieldcollection/collectionlist', NULL, 3, true, 2, '2026-04-14 17:56:42.742', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(330, 'Receipt Books', 'RECEIPTBOOK', 272, 'solar:book-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/fieldcollection/receiptbook', NULL, 4, true, 2, '2026-04-14 17:56:47.243', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(332, 'Collection Distribution', 'COLLECTIONDISTRIBUTION', 272, 'solar:transfer-horizontal-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/fieldcollection/collectiondistribution', NULL, 6, true, 2, '2026-04-14 17:56:55.359', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(333, 'Volunteer List', 'VOLUNTEER', 273, 'solar:hand-heart-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/volunteer/volunteerlist', NULL, 1, true, 2, '2026-04-14 17:57:01.455', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(334, 'Register Volunteer', 'VOLUNTEERFORM', 273, 'solar:user-plus-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/volunteer/registervolunteer', NULL, 2, true, 2, '2026-04-14 17:57:07.537', NULL, NULL, false, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(335, 'Scheduling', 'VOLUNTEERSCHEDULING', 273, 'solar:calendar-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/volunteer/volunteerscheduling', NULL, 3, true, 2, '2026-04-14 17:57:12.559', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(336, 'Hour Tracking', 'VOLUNTEERHOURTRACKING', 273, 'solar:clock-circle-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/volunteer/volunteerhourtracking', NULL, 4, true, 2, '2026-04-14 17:57:17.893', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(337, 'Donor Conversion', 'VOLUNTEERCONVERSION', 273, 'solar:transfer-horizontal-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/volunteer/volunteerconversion', NULL, 5, true, 2, '2026-04-14 17:57:20.970', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(338, 'Member List', 'MEMBERLIST', 274, 'solar:card-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/membership/memberlist', NULL, 1, true, 2, '2026-04-14 17:57:31.680', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(339, 'Enroll Member', 'MEMBERENROLLMENT', 274, 'solar:user-plus-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/membership/memberenrollment', NULL, 2, true, 2, '2026-04-14 17:57:34.450', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(340, 'Tiers & Plans', 'MEMBERSHIPTIER', 274, 'solar:sort-from-bottom-to-top-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/membership/membershiptier', NULL, 3, true, 2, '2026-04-14 17:57:38.759', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(341, 'Renewals', 'MEMBERSHIPRENEWAL', 274, 'solar:restart-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/membership/membershiprenewal', NULL, 4, true, 2, '2026-04-14 17:57:41.867', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(342, 'All Grants', 'GRANTLIST', 275, 'solar:document-add-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/grant/grantlist', NULL, 1, true, 2, '2026-04-14 17:57:48.045', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(343, 'New Application', 'GRANTFORM', 275, 'solar:pen-new-square-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/grant/grantform', NULL, 2, true, 2, '2026-04-14 17:57:50.861', NULL, NULL, false, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(344, 'Grant Calendar', 'GRANTCALENDAR', 275, 'solar:calendar-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/grant/grantcalendar', NULL, 3, true, 2, '2026-04-14 17:57:54.054', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(345, 'Funder Reports', 'GRANTREPORTING', 275, 'solar:chart-square-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/grant/grantreporting', NULL, 4, true, 2, '2026-04-14 17:57:58.003', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(346, 'Beneficiary List', 'BENEFICIARYLIST', 276, 'solar:users-group-rounded-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/casemanagement/beneficiarylist', NULL, 1, true, 2, '2026-04-14 17:58:06.294', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(347, 'Register Beneficiary', 'BENEFICIARYFORM', 276, 'solar:user-plus-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/casemanagement/registerbeneficiary', NULL, 2, true, 2, '2026-04-14 17:58:09.702', NULL, NULL, false, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(348, 'Case List', 'CASELIST', 276, 'solar:clipboard-list-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/casemanagement/caselist', NULL, 3, true, 2, '2026-04-14 17:58:13.080', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(349, 'Program Management', 'PROGRAMMANAGEMENT', 276, 'solar:folder-with-files-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/casemanagement/programmanagement', NULL, 4, true, 2, '2026-04-14 17:58:16.014', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(350, 'Engagement Scores', 'ENGAGEMENTSCORING', 277, 'solar:graph-up-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/intelligence/engagementscoring', NULL, 1, true, 2, '2026-04-14 17:58:25.966', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(351, 'Churn Prediction', 'CHURNPREDICTION', 277, 'solar:danger-triangle-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/intelligence/churnprediction', NULL, 2, true, 2, '2026-04-14 17:58:29.601', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(352, 'Action Board', 'ACTIONBOARD', 277, 'solar:checklist-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/intelligence/actionboard', NULL, 3, true, 2, '2026-04-14 17:58:32.288', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(353, 'AI Draft', 'AIDRAFT', 277, 'solar:magic-stick-3-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/intelligence/aidraft', NULL, 4, true, 2, '2026-04-14 17:58:36.332', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(354, 'Ask Your Data', 'AIREPORTING', 277, 'solar:chat-square-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/intelligence/aireporting', NULL, 5, true, 2, '2026-04-14 17:58:39.459', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(355, 'Predictive Analytics', 'PREDICTIVEANALYTICS', 277, 'solar:cpu-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/intelligence/predictiveanalytics', NULL, 6, true, 2, '2026-04-14 17:58:43.869', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(356, 'Contact Dashboard', 'CONTACTDASHBOARD', 278, 'solar:user-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/dashboards/contactdashboard', NULL, 1, true, 2, '2026-04-14 17:58:50.254', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(357, 'Donation Dashboard', 'DONATIONDASHBOARD', 278, 'solar:hand-money-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/dashboards/donationdashboard', NULL, 2, true, 2, '2026-04-14 17:58:54.393', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(358, 'Communication Dashboard', 'COMMUNICATIONDASHBOARD', 278, 'solar:letter-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/dashboards/communicationdashboard', NULL, 3, true, 2, '2026-04-14 17:58:56.868', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(359, 'Ambassador Dashboard', 'AMBASSADORDASHBOARD', 278, 'solar:map-arrow-right-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/dashboards/ambassadordashboard', NULL, 4, true, 2, '2026-04-14 17:58:59.624', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(360, 'Volunteer Dashboard', 'VOLUNTEERDASHBOARD', 278, 'solar:hand-heart-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/dashboards/volunteerdashboard', NULL, 5, true, 2, '2026-04-14 17:59:02.248', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(361, 'Case Dashboard', 'CASEDASHBOARD', 278, 'solar:clipboard-list-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/dashboards/casedashboard', NULL, 6, true, 2, '2026-04-14 17:59:04.703', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(362, 'Company', 'ORG_COMPANY', NULL, 'solar:buildings-bold', 'aab02c59-71ff-4cd3-9062-5802f0f74156'::uuid, NULL, NULL, 1, false, 2, '2026-04-14 18:00:59.240', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(363, 'Staff', 'ORG_STAFF', NULL, 'solar:user-id-bold', 'aab02c59-71ff-4cd3-9062-5802f0f74156'::uuid, NULL, NULL, 2, false, 2, '2026-04-14 18:01:03.223', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(365, 'Users & Roles', 'AC_USERSROLES', NULL, 'solar:shield-user-bold', 'eda573b9-a49c-4ac3-8281-c693f9dc38c2'::uuid, NULL, NULL, 1, false, 2, '2026-04-14 18:02:06.828', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(366, 'Governance', 'AC_GOVERNANCE', NULL, 'solar:shield-keyhole-bold', 'eda573b9-a49c-4ac3-8281-c693f9dc38c2'::uuid, NULL, NULL, 2, false, 2, '2026-04-14 18:02:15.526', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(367, 'Region', 'GEN_REGION', NULL, 'solar:map-point-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, NULL, NULL, 1, false, 2, '2026-04-14 18:02:22.163', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(368, 'Masters', 'GEN_MASTERS', NULL, 'solar:database-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, NULL, NULL, 2, false, 2, '2026-04-14 18:02:27.128', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(369, 'Public Pages', 'SET_PUBLICPAGES', NULL, 'solar:monitor-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, NULL, NULL, 1, false, 2, '2026-04-14 18:02:43.351', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(370, 'Payment Config', 'SET_PAYMENTCONFIG', NULL, 'solar:card-transfer-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, NULL, NULL, 2, false, 2, '2026-04-14 18:02:47.156', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(371, 'Communication Config', 'SET_COMMUNICATIONCONFIG', NULL, 'solar:chat-line-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, NULL, NULL, 3, false, 2, '2026-04-14 18:02:51.664', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(372, 'Donation Config', 'SET_DONATIONCONFIG', NULL, 'solar:hand-money-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, NULL, NULL, 4, false, 2, '2026-04-14 18:02:55.834', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(373, 'Membership Config', 'SET_MEMBERSHIPCONFIG', NULL, 'solar:card-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, NULL, NULL, 5, false, 2, '2026-04-14 18:03:01.084', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(374, 'Data Config', 'SET_DATACONFIG', NULL, 'solar:server-square-cloud-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, NULL, NULL, 6, false, 2, '2026-04-14 18:03:04.533', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(375, 'Grid Management', 'SET_GRIDMANAGEMENT', NULL, 'solar:widget-2-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, NULL, NULL, 7, false, 2, '2026-04-14 18:03:07.487', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(376, 'Dashboard & Widget', 'SET_DASHBOARDWIDGET', NULL, 'solar:chart-2-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, NULL, NULL, 8, false, 2, '2026-04-14 18:03:13.090', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(377, 'Org Settings', 'SET_ORGSETTINGS', NULL, 'solar:settings-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, NULL, NULL, 9, false, 2, '2026-04-14 18:03:16.061', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(378, 'Integration', 'SET_INTEGRATION', NULL, 'solar:plug-circle-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, NULL, NULL, 10, false, 2, '2026-04-14 18:03:19.515', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(379, 'Document', 'SET_DOCUMENT', NULL, 'solar:document-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, NULL, NULL, 11, false, 2, '2026-04-14 18:03:22.716', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(380, 'Reports', 'RA_REPORTS', NULL, 'solar:chart-square-bold', '4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, NULL, NULL, 1, false, 2, '2026-04-14 18:03:26.071', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(381, 'Report Setup', 'RA_REPORTSETUP', NULL, 'solar:settings-bold', '4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, NULL, NULL, 2, false, 2, '2026-04-14 18:03:28.901', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(382, 'Audit', 'RA_AUDIT', NULL, 'solar:shield-check-bold', '4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, NULL, NULL, 3, false, 2, '2026-04-14 18:03:34.145', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(383, 'Company Configuration', 'COMPANY', 362, 'solar:buildings-bold', 'aab02c59-71ff-4cd3-9062-5802f0f74156'::uuid, 'organization/company/company', NULL, 1, true, 2, '2026-04-14 18:04:15.068', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(384, 'Branches', 'BRANCH', 362, 'solar:map-point-bold', 'aab02c59-71ff-4cd3-9062-5802f0f74156'::uuid, 'organization/company/branch', NULL, 2, true, 2, '2026-04-14 18:04:18.886', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(386, 'Staffs', 'STAFFS', 363, 'solar:user-id-bold', 'aab02c59-71ff-4cd3-9062-5802f0f74156'::uuid, 'organization/staff/staff', NULL, 1, true, 2, '2026-04-14 18:04:51.655', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(387, 'Staff Category', 'STAFFCATEGORY', 363, 'solar:tag-bold', 'aab02c59-71ff-4cd3-9062-5802f0f74156'::uuid, 'organization/staff/staffcategory', NULL, 2, true, 2, '2026-04-14 18:04:56.002', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(388, 'Users', 'USER', 365, 'solar:user-bold', 'eda573b9-a49c-4ac3-8281-c693f9dc38c2'::uuid, 'accesscontrol/usersroles/user', NULL, 1, true, 2, '2026-04-14 18:05:04.011', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(389, 'Roles', 'ROLE', 365, 'solar:shield-user-bold', 'eda573b9-a49c-4ac3-8281-c693f9dc38c2'::uuid, 'accesscontrol/usersroles/role', NULL, 2, true, 2, '2026-04-14 18:05:08.074', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(390, 'Capabilities', 'CAPABILITY', 365, 'solar:key-bold', 'eda573b9-a49c-4ac3-8281-c693f9dc38c2'::uuid, 'accesscontrol/usersroles/capability', NULL, 3, true, 2, '2026-04-14 18:05:13.623', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(391, 'Role Capability', 'ROLECAPABILITY', 365, 'solar:shield-check-bold', 'eda573b9-a49c-4ac3-8281-c693f9dc38c2'::uuid, 'accesscontrol/usersroles/rolecapability', NULL, 4, true, 2, '2026-04-14 18:05:16.958', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(392, 'User Role', 'USERROLE', 365, 'solar:user-check-bold', 'eda573b9-a49c-4ac3-8281-c693f9dc38c2'::uuid, 'accesscontrol/usersroles/userrole', NULL, 5, true, 2, '2026-04-14 18:05:21.200', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(393, 'Widget Role', 'WIDGETROLE', 365, 'solar:widget-bold', 'eda573b9-a49c-4ac3-8281-c693f9dc38c2'::uuid, 'accesscontrol/usersroles/widgetrole', NULL, 6, true, 2, '2026-04-14 18:05:25.083', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(394, 'Menus', 'MENU', 366, 'solar:hamburger-menu-bold', 'eda573b9-a49c-4ac3-8281-c693f9dc38c2'::uuid, 'accesscontrol/governance/menu', NULL, 1, true, 2, '2026-04-14 18:05:29.552', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(395, 'Modules', 'MODULE', 366, 'solar:widget-2-bold', 'eda573b9-a49c-4ac3-8281-c693f9dc38c2'::uuid, 'accesscontrol/governance/module', NULL, 2, true, 2, '2026-04-14 18:05:32.098', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(396, 'Country', 'COUNTRY', 367, 'solar:earth-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/region/country', NULL, 1, true, 2, '2026-04-14 18:05:37.327', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(397, 'State', 'STATE', 367, 'solar:map-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/region/state', NULL, 2, true, 2, '2026-04-14 18:05:40.225', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(398, 'District', 'DISTRICT', 367, 'solar:map-point-wave-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/region/district', NULL, 3, true, 2, '2026-04-14 18:05:44.256', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(399, 'City', 'CITY', 367, 'solar:city-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/region/city', NULL, 4, true, 2, '2026-04-14 18:05:50.788', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(400, 'Locality', 'LOCALITY', 367, 'solar:streets-map-point-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/region/locality', NULL, 5, true, 2, '2026-04-14 18:05:54.940', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(401, 'Pincode', 'PINCODE', 367, 'solar:map-point-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/region/pincode', NULL, 6, true, 2, '2026-04-14 18:05:57.826', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(402, 'Currency', 'CURRENCY', 368, 'solar:dollar-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/masters/currency', NULL, 1, true, 2, '2026-04-14 18:06:06.325', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(403, 'Currency Conversion', 'CURRENCYCONVERSION', 368, 'solar:transfer-horizontal-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/masters/currencyconversion', NULL, 2, true, 2, '2026-04-14 18:06:09.692', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(404, 'Bank', 'BANK', 368, 'solar:card-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/masters/bank', NULL, 3, true, 2, '2026-04-14 18:06:12.280', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(405, 'Gender', 'GENDER', 368, 'solar:user-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/masters/gender', NULL, 4, true, 2, '2026-04-14 18:06:14.539', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(406, 'Salutation', 'SALUTATION', 368, 'solar:text-bold-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/masters/salutation', NULL, 5, true, 2, '2026-04-14 18:06:19.705', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(407, 'Blood Group', 'BLOODGROUP', 368, 'solar:heart-pulse-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/masters/bloodgroup', NULL, 6, true, 2, '2026-04-14 18:06:23.418', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(408, 'Language', 'LANGUAGE', 368, 'solar:global-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/masters/language', NULL, 7, true, 2, '2026-04-14 18:06:27.108', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(409, 'Occupation', 'OCCUPATION', 368, 'solar:case-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/masters/occupation', NULL, 8, true, 2, '2026-04-14 18:06:30.586', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(410, 'Relation', 'RELATION', 368, 'solar:users-group-two-rounded-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/masters/relation', NULL, 9, true, 2, '2026-04-14 18:06:35.180', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(411, 'Payment Mode', 'PAYMENTMODE', 368, 'solar:card-transfer-bold', 'f161a84c-71c4-4b49-89f1-97cbc90966e5'::uuid, 'general/masters/paymentmode', NULL, 10, true, 2, '2026-04-14 18:06:38.234', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(412, 'Online Donation Pages', 'ONLINEDONATIONPAGE', 369, 'solar:hand-money-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/publicpages/onlinedonationpage', NULL, 1, true, 2, '2026-04-14 18:06:49.471', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(413, 'P2P Campaign Pages', 'P2PCAMPAIGNPAGE', 369, 'solar:flag-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/publicpages/p2pcampaignpage', NULL, 2, true, 2, '2026-04-14 18:06:52.953', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(414, 'Prayer Request Page', 'PRAYERREQUESTPAGE', 369, 'solar:heart-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/publicpages/prayerrequestpage', NULL, 3, true, 2, '2026-04-14 18:06:57.178', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(415, 'Membership Portal', 'MEMBERPORTAL', 369, 'solar:card-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/publicpages/memberportal', NULL, 4, true, 2, '2026-04-14 18:06:59.958', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(416, 'Volunteer Registration Page', 'VOLUNTEERREGPAGE', 369, 'solar:hand-heart-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/publicpages/volunteerregpage', NULL, 5, true, 2, '2026-04-14 18:07:05.468', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(417, 'Event Registration Page', 'EVENTREGPAGE', 369, 'solar:calendar-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/publicpages/eventregpage', NULL, 6, true, 2, '2026-04-14 18:07:09.669', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(418, 'Payment Gateways', 'COMPANYPAYMENTGATEWAY', 370, 'solar:card-transfer-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/paymentconfig/companypaymentgateway', NULL, 1, true, 2, '2026-04-14 18:07:18.262', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(419, 'Payment Gateway Master', 'PAYMENTGATEWAY', 370, 'solar:server-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/paymentconfig/paymentgateway', NULL, 2, true, 2, '2026-04-14 18:07:21.418', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(420, 'WhatsApp Setup', 'WHATSAPPSETUP', 371, 'solar:chat-round-dots-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/communicationconfig/whatsappsetup', NULL, 1, true, 2, '2026-04-14 18:07:26.470', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(421, 'SMS Setup', 'SMSSETUP', 371, 'solar:smartphone-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/communicationconfig/smssetup', NULL, 2, true, 2, '2026-04-14 18:07:29.222', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(422, 'Email Provider Config', 'EMAILPROVIDERCONFIG', 371, 'solar:letter-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/communicationconfig/emailproviderconfig', NULL, 3, true, 2, '2026-04-14 18:07:34.104', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(423, 'Donation Purpose', 'DONATIONPURPOSE', 270, 'solar:target-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'setting/donationconfig/donationpurpose', NULL, 5, true, 2, '2026-04-14 18:07:38.194', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(424, 'Donation Category', 'DONATIONCATEGORY', 270, 'solar:folder-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'setting/donationconfig/donationcategory', NULL, 3, true, 2, '2026-04-14 18:07:42.922', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(425, 'Donation Group', 'DONATIONGROUP', 270, 'solar:users-group-rounded-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'setting/donationconfig/donationgroup', NULL, 4, true, 2, '2026-04-14 18:07:47.750', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(426, 'Donation Verse', 'DONATIONVERSE', 372, 'solar:book-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/donationconfig/donationverse', NULL, 4, true, 2, '2026-04-14 18:07:51.328', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(427, 'Receipts & Tax', 'RECEIPTMANAGEMENT', 372, 'solar:document-text-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/donationconfig/receiptmanagement', NULL, 5, true, 2, '2026-04-14 18:07:54.374', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(428, 'Membership Tiers Config', 'MEMBERSHIPTIERCONFIG', 373, 'solar:sort-from-bottom-to-top-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/membershipconfig/membershiptierconfig', NULL, 1, true, 2, '2026-04-14 18:08:01.091', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(429, 'Master Data', 'MASTERDATA', 374, 'solar:database-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/dataconfig/masterdata', NULL, 1, true, 2, '2026-04-14 18:08:09.271', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(430, 'Master Data Type', 'MASTERDATATYPE', 374, 'solar:server-square-cloud-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/dataconfig/masterdatatype', NULL, 2, true, 2, '2026-04-14 18:08:13.971', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(431, 'Grid Config', 'GRID', 375, 'solar:widget-2-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/gridmanagement/grid', NULL, 1, true, 2, '2026-04-14 18:08:22.631', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(432, 'Field', 'FIELD_SETTING', 375, 'solar:text-field-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/gridmanagement/field', NULL, 2, true, 2, '2026-04-14 18:08:27.396', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(433, 'Dashboard', 'DASHBOARD', 376, 'solar:chart-2-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/dashboardwidget/dashboard', NULL, 1, true, 2, '2026-04-14 18:08:32.600', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(434, 'Dashboard Layout', 'DASHBOARDLAYOUT', 376, 'solar:widget-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/dashboardwidget/dashboardlayout', NULL, 2, true, 2, '2026-04-14 18:08:35.612', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(435, 'Widget', 'WIDGET', 376, 'solar:widget-3-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/dashboardwidget/widget', NULL, 3, true, 2, '2026-04-14 18:08:38.737', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(436, 'Widget Type', 'WIDGETTYPE', 376, 'solar:widget-4-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/dashboardwidget/widgettype', NULL, 4, true, 2, '2026-04-14 18:08:43.184', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(437, 'Widget Property', 'WIDGETPROPERTY', 376, 'solar:settings-minimalistic-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/dashboardwidget/widgetproperty', NULL, 5, true, 2, '2026-04-14 18:08:47.756', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(438, 'Setting Group', 'SETTINGGROUP', 377, 'solar:folder-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/orgsettings/settinggroup', NULL, 1, true, 2, '2026-04-14 18:08:54.246', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(439, 'Organization Setting', 'ORGANIZATIONSETTING', 377, 'solar:settings-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/orgsettings/organizationsetting', NULL, 2, true, 2, '2026-04-14 18:09:02.023', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(440, 'User Setting', 'USERSETTING', 377, 'solar:user-check-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/orgsettings/usersetting', NULL, 3, true, 2, '2026-04-14 18:09:05.901', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(441, 'Accounting Integration', 'ACCOUNTINGINTEGRATION', 378, 'solar:calculator-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/integration/accountingintegration', NULL, 1, true, 2, '2026-04-14 18:09:12.139', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(442, 'Social Media', 'SOCIALMEDIAINTEGRATION', 378, 'solar:share-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/integration/socialmediaintegration', NULL, 2, true, 2, '2026-04-14 18:09:15.136', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(443, 'API Keys', 'APIMANAGEMENT', 378, 'solar:key-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/integration/apimanagement', NULL, 3, true, 2, '2026-04-14 18:09:18.107', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(444, 'Marketplace', 'INTEGRATIONMARKETPLACE', 378, 'solar:shop-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/integration/integrationmarketplace', NULL, 4, true, 2, '2026-04-14 18:09:21.258', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(445, 'Document Types', 'DOCUMENTTYPE', 379, 'solar:document-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/document/documenttype', NULL, 1, true, 2, '2026-04-14 18:09:30.336', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(446, 'Certificate Template Config', 'CERTIFICATETEMPLATECONFIG', 379, 'solar:diploma-bold', '51ebbad9-85a0-4a18-a3fe-50e15d8c84a9'::uuid, 'setting/document/certificatetemplateconfig', NULL, 2, true, 2, '2026-04-14 18:09:33.731', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(447, 'Report Catalog', 'REPORTCATALOG', 380, 'solar:list-bold', '4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, 'reportaudit/reports/reportcatalog', NULL, 1, true, 2, '2026-04-14 18:09:47.867', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(448, 'Custom Builder', 'CUSTOMREPORTBUILDER', 380, 'solar:pen-new-square-bold', '4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, 'reportaudit/reports/customreportbuilder', NULL, 2, true, 2, '2026-04-14 18:09:53.886', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(449, 'Retention Dashboard', 'RETENTIONDASHBOARD', 380, 'solar:chart-2-bold', '4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, 'reportaudit/reports/retentiondashboard', NULL, 3, true, 2, '2026-04-14 18:09:56.964', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(450, 'Fundraising Summary', 'FUNDRAISINGSUMMARY', 380, 'solar:hand-money-bold', '4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, 'reportaudit/reports/fundraisingsummary', NULL, 4, true, 2, '2026-04-14 18:09:59.686', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(451, 'PowerBI Reports', 'POWERBIREPORT', 380, 'solar:chart-square-bold', '4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, 'reportaudit/reports/powerbireport', NULL, 5, true, 2, '2026-04-14 18:10:02.614', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(452, 'HTML Reports', 'HTMLREPORT', 380, 'solar:code-bold', '4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, 'reportaudit/reports/htmlreport', NULL, 6, true, 2, '2026-04-14 18:10:05.795', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(453, 'Scheduled Reports', 'SCHEDULEDREPORT', 380, 'solar:alarm-bold', '4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, 'reportaudit/reports/scheduledreport', NULL, 7, true, 2, '2026-04-14 18:10:10.018', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(454, 'Generate Report', 'GENERATEREPORT', 380, 'solar:file-download-bold', '4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, 'reportaudit/reports/generatereport', NULL, 8, true, 2, '2026-04-14 18:10:14.695', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(455, 'PowerBI Report Master', 'POWERBIREPORTMASTER', 381, 'solar:server-bold', '4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, 'reportaudit/reportsetup/powerbireportmaster', NULL, 1, true, 2, '2026-04-14 18:10:21.337', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(456, 'PowerBI User Mapping', 'POWERBIUSERMAPPING', 381, 'solar:user-check-bold', '4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, 'reportaudit/reportsetup/powerbiusermapping', NULL, 2, true, 2, '2026-04-14 18:10:24.662', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(457, 'Audit Trail', 'AUDITTRAIL', 382, 'solar:shield-check-bold', '4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, 'reportaudit/audit/audittrail', NULL, 1, true, 2, '2026-04-14 18:10:28.564', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(458, 'Company Settings', 'COMPANYSETTINGS', 382, 'solar:settings-bold', '4dcf6f88-dafc-40a8-a49a-c657ae09f1df'::uuid, 'reportaudit/audit/companysettings', NULL, 2, true, 2, '2026-04-14 18:10:33.379', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(459, 'Performance', 'AMBASSADORPERFORMANCE', 272, 'solar:book-2-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/fieldcollection/ambassadorperformance', NULL, 5, true, 2, '2026-04-15 12:29:48.525', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(460, 'Reconciliation', 'RECONCILIATION', 262, 'solar:checklist-bold', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/donation/reconciliation', NULL, 7, true, 2, '2026-04-14 17:51:31.985', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(461, 'Refunds', 'REFUND', 262, 'phosphor:arrow-u-up-left', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, 'crm/donation/refund', NULL, 8, true, 2, '2026-04-14 17:51:31.985', 2, '2026-04-21 18:23:30.108', true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(463, 'WhatsApp Message', 'WHATSAPPMESSAGE', NULL, 'lucide:message-circle', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 10, false, 2, '2026-04-17 13:06:07.118', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(464, 'Tags (grid)', 'TAG', 282, 'ph:tag', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 1, true, 2, '2026-04-18 15:17:16.034', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(465, 'Segments (grid)', 'SEGMENT', 282, 'ph:funnel', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 2, true, 2, '2026-04-18 15:17:21.331', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(466, 'Matching Companies (Hidden)', 'MATCHINGCOMPANY', 298, 'ph:buildings', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 1, true, 2, '2026-04-19 18:34:42.594', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(467, 'Matching Gift Records (Hidden)', 'MATCHINGGIFTRECORD', 298, 'ph:list-checks', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 2, true, 2, '2026-04-19 18:34:49.555', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(468, 'Matching Gift Settings (Hidden)', 'MATCHINGGIFTSETTINGS', 298, 'ph:gear', 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, NULL, 3, true, 2, '2026-04-19 18:34:56.625', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(469, 'Auction Bids', 'AUCTIONBID', 325, NULL, 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, 'Hidden sub-entity — accessed via BidHistoryModal under AUCTIONMANAGEMENT.', 1, false, 2, '2026-04-21 14:38:16.661', NULL, NULL, true, false);
INSERT INTO auth."Menus"
("MenuId", "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description", "OrderBy", "IsLeastMenu", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
VALUES(470, 'Event Auction Config', 'EVENTAUCTION', 325, NULL, 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid, NULL, 'Hidden parent-config — governs bidding state under AUCTIONMANAGEMENT.', 2, false, 2, '2026-04-21 14:38:21.768', NULL, NULL, true, false);