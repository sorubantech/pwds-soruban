# PSS 2.0 — Module & Menu Reference

> **Source of truth** for menu codes, parent menus, modules, and FE routes.
> Extracted from `Module_Menu_List.sql` (2026-04-16).
> `/plan-screens` uses this to pre-fill Section ⑨ (Approval Config) correctly.

---

## Modules (6)

| ModuleCode | ModuleName | ModuleUrl | OrderBy | Description |
|-----------|-----------|-----------|---------|-------------|
| CRM | CRM | /crm/dashboards/overview | 1 | Contacts, Donations, Communication, Volunteers, Membership, Grants, Cases, Intelligence |
| ORGANIZATION | Organization | /organization/dashboards/overview | 2 | Organization configuration |
| ACCESSCONTROL | Access Control | /accesscontrol/dashboards/overview | 3 | Users, roles, capabilities, governance |
| GENERAL | General | /general/dashboards/overview | 4 | Region hierarchy, master data |
| SETTING | Setting | /setting/dashboards/overview | 5 | Payment, communication, donation config, public pages, integrations |
| REPORTAUDIT | Report & Audit | /reportaudit/dashboards/overview | 6 | Reports, analytics, audit trail |

---

## CRM Module — Parent Menus & Leaf Screens

### CRM_DASHBOARDS (MenuId: 278)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| CONTACTDASHBOARD | Contact Dashboard | crm/dashboards/contactdashboard | 1 |
| DONATIONDASHBOARD | Donation Dashboard | crm/dashboards/donationdashboard | 2 |
| COMMUNICATIONDASHBOARD | Communication Dashboard | crm/dashboards/communicationdashboard | 3 |
| AMBASSADORDASHBOARD | Ambassador Dashboard | crm/dashboards/ambassadordashboard | 4 |
| VOLUNTEERDASHBOARD | Volunteer Dashboard | crm/dashboards/volunteerdashboard | 5 |
| CASEDASHBOARD | Case Dashboard | crm/dashboards/casedashboard | 6 |

### CRM_CONTACT (MenuId: 258)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| CONTACT | All Contacts | crm/contact/allcontacts | 1 |
| CONTACTTYPE | Contact Types | crm/contact/contacttype | 2 |
| CONTACTSOURCE | Contact Sources | crm/contact/contactsource | 3 |
| TAGSEGMENTATION | Tags & Segmentation | crm/contact/tagsegmentation | 4 |
| CONTACTIMPORT | Contact Import | crm/contact/contactimport | 5 |

### CRM_FAMILY (MenuId: 259)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| FAMILY | Family Management | crm/family/family | 1 |

### CRM_MAINTENANCE (MenuId: 260)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| DUPLICATECONTACT | Duplicate Detection | crm/maintenance/duplicatecontact | 1 |

### CRM_CERTIFICATE (MenuId: 261)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| CERTIFICATETEMPLATE | Certificate Template | crm/certificate/certificatetemplate | 1 |
| PROCESSCERTIFICATES | Process Certificates | crm/certificate/processcertificates | 2 |
| PRINTCERTIFICATES | Print Certificates | crm/certificate/printcertificates | 3 |

### CRM_DONATION (MenuId: 262)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| GLOBALDONATION | All Donations | crm/donation/globaldonation | 1 |
| RECURRINGDONOR | Recurring Donations | crm/donation/recurringdonors | 2 |
| CHEQUEDONATION | Cheque Tracking | crm/donation/chequedonation | 3 |
| DONATIONINKIND | In-Kind Donations | crm/donation/donationinkind | 4 |
| PLEDGE | Pledges | crm/donation/pledge | 5 |
| BULKDONATION | Bulk Upload | crm/donation/bulkdonation | 6 |
| RECONCILIATION | Reconciliation | crm/donation/reconciliation | 7 |
| REFUND | Refunds | crm/donation/refund | 8 |

### CRM_P2PFUNDRAISING (MenuId: 263)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| P2PCAMPAIGN | P2P Campaigns | crm/p2pfundraising/p2pcampaign | 1 |
| P2PFUNDRAISER | P2P Fundraisers | crm/p2pfundraising/p2pfundraiser | 2 |
| CROWDFUNDING | Crowdfunding | crm/p2pfundraising/crowdfunding | 3 |
| MATCHINGGIFT | Matching Gifts | crm/p2pfundraising/matchinggift | 4 |

### CRM_COMMUNICATION (MenuId: 264)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| EMAILTEMPLATE | Email Templates | crm/communication/emailtemplate | 1 |
| EMAILCAMPAIGN | Email Campaigns | crm/communication/emailcampaign | 2 |
| EMAILANALYTICS | Email Analytics | crm/communication/emailanalytics | 3 |
| EMAILKEYWORD | Email Keywords | crm/communication/emailkeywords | 4 |
| PLACEHOLDERDEFINITION | Placeholder Definitions | crm/communication/placeholderdefinition | 5 |
| SAVEDFILTER | Saved Filters | crm/communication/savedfilter | 6 |

### CRM_WHATSAPP (MenuId: 265)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| WHATSAPPTEMPLATE | WhatsApp Templates | crm/whatsapp/whatsapptemplate | 1 |
| WHATSAPPCAMPAIGN | WhatsApp Campaigns | crm/whatsapp/whatsappcampaign | 2 |
| WHATSAPPCONVERSATION | WhatsApp Conversations | crm/whatsapp/whatsappconversation | 3 |

### CRM_SMS (MenuId: 266)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| SMSTEMPLATE | SMS Templates | crm/sms/smstemplate | 1 |
| SMSCAMPAIGN | SMS Campaigns | crm/sms/smscampaign | 2 |

### CRM_NOTIFICATION (MenuId: 267)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| NOTIFICATIONTEMPLATE | Notification Templates | crm/notification/notificationtemplate | 1 |
| NOTIFICATIONCENTER | Notification Center | crm/notification/notificationcenter | 2 |

### CRM_AUTOMATION (MenuId: 268)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| AUTOMATIONWORKFLOW | Automation Workflows | crm/automation/automationworkflow | 1 |

### CRM_PRAYERREQUEST (MenuId: 269)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| PRAYERREQUESTS | Prayer Requests | crm/prayerrequest/prayerrequests | 1 |

> **Consolidated 2026-05-12** (UX decision): the original three menus (`PRAYERREQUESTENTRY`, `REVIEWREPLY`, `REPLYQUEUE`) were collapsed into ONE menu `PRAYERREQUESTS` with three tabs (`?tab=entry` / `?tab=replyqueue` / `?tab=reviewreplies`). Tab visibility is capability-driven: `READ` shows Entry tab; `REPLY_DRAFT` shows Reply Queue tab; `REPLY_APPROVE` shows Review Replies tab. The workspace shell + Tab 1 are built by #136; Tabs 2/3 are built by #137/#138 as tab content (no new menus/routes).

### CRM_ORGANIZATION (MenuId: 270)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| ORGANIZATIONALUNIT | Organizational Units | crm/organization/organizationalunit | 1 |
| CAMPAIGN | Campaigns | crm/organization/campaign | 2 |
| DONATIONCATEGORY | Donation Category | setting/donationconfig/donationcategory | 3 |
| DONATIONGROUP | Donation Group | setting/donationconfig/donationgroup | 4 |
| DONATIONPURPOSE | Donation Purpose | setting/donationconfig/donationpurpose | 5 |

> **Note**: Donation Category/Group/Purpose have MenuUrl under `setting/donationconfig/` but are parented under CRM_ORGANIZATION.

### CRM_EVENT (MenuId: 271)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| EVENT | Events | crm/event/event | 1 |
| EVENTTICKETING | Event Ticketing | crm/event/eventticketing | 2 |
| AUCTIONMANAGEMENT | Auction Management | crm/event/auctionmanagement | 3 |
| EVENTANALYTICS | Event Analytics | crm/event/eventanalytics | 4 |

### CRM_FIELDCOLLECTION (MenuId: 272)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| AMBASSADORLIST | Ambassador List | crm/fieldcollection/ambassadorlist | 1 |
| AMBASSADORCOLLECTION | Record Collection | crm/fieldcollection/ambassadorcollection | 2 |
| COLLECTIONLIST | Collection List | crm/fieldcollection/collectionlist | 3 |
| RECEIPTBOOK | Receipt Books | crm/fieldcollection/receiptbook | 4 |
| AMBASSADORPERFORMANCE | Performance | crm/fieldcollection/ambassadorperformance | 5 |
| COLLECTIONDISTRIBUTION | Collection Distribution | crm/fieldcollection/collectiondistribution | 6 |

### CRM_VOLUNTEER (MenuId: 273)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| VOLUNTEERLIST | Volunteer List | crm/volunteer/volunteerlist | 1 |
| VOLUNTEERFORM | Register Volunteer | crm/volunteer/registervolunteer | 2 |
| VOLUNTEERSCHEDULING | Scheduling | crm/volunteer/volunteerscheduling | 3 |
| VOLUNTEERHOURTRACKING | Hour Tracking | crm/volunteer/volunteerhourtracking | 4 |
| VOLUNTEERCONVERSION | Donor Conversion | crm/volunteer/volunteerconversion | 5 |

### CRM_MEMBERSHIP (MenuId: 274)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| MEMBERLIST | Member List | crm/membership/memberlist | 1 |
| MEMBERENROLLMENT | Enroll Member | crm/membership/memberenrollment | 2 |
| MEMBERSHIPTIER | Tiers & Plans | crm/membership/membershiptier | 3 |
| MEMBERSHIPRENEWAL | Renewals | crm/membership/membershiprenewal | 4 |

### CRM_GRANT (MenuId: 275)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| GRANTLIST | All Grants | crm/grant/grantlist | 1 |
| GRANTFORM | New Application | crm/grant/grantform | 2 |
| GRANTCALENDAR | Grant Calendar | crm/grant/grantcalendar | 3 |
| GRANTREPORTING | Funder Reports | crm/grant/grantreporting | 4 |

### CRM_CASEMANAGEMENT (MenuId: 276)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| BENEFICIARYLIST | Beneficiary List | crm/casemanagement/beneficiarylist | 1 |
| BENEFICIARYFORM | Register Beneficiary | crm/casemanagement/registerbeneficiary | 2 |
| CASELIST | Case List | crm/casemanagement/caselist | 3 |
| PROGRAMMANAGEMENT | Program Management | crm/casemanagement/programmanagement | 4 |

### CRM_INTELLIGENCE (MenuId: 277)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| ENGAGEMENTSCORING | Engagement Scores | crm/intelligence/engagementscoring | 1 |
| CHURNPREDICTION | Churn Prediction | crm/intelligence/churnprediction | 2 |
| ACTIONBOARD | Action Board | crm/intelligence/actionboard | 3 |
| AIDRAFT | AI Draft | crm/intelligence/aidraft | 4 |
| AIREPORTING | Ask Your Data | crm/intelligence/aireporting | 5 |
| PREDICTIVEANALYTICS | Predictive Analytics | crm/intelligence/predictiveanalytics | 6 |

---

## Organization Module

### ORG_COMPANY (MenuId: 362)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| COMPANY | Company Configuration | organization/company/company | 1 |
| BRANCH | Branches | organization/company/branch | 2 |

### ORG_STAFF (MenuId: 363)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| STAFFS | Staffs | organization/staff/staff | 1 |
| STAFFCATEGORY | Staff Category | organization/staff/staffcategory | 2 |

---

## Access Control Module

### AC_USERSROLES (MenuId: 365)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| USER | Users | accesscontrol/usersroles/user | 1 |
| ROLE | Roles | accesscontrol/usersroles/role | 2 |
| CAPABILITY | Capabilities | accesscontrol/usersroles/capability | 3 |
| ROLECAPABILITY | Role Capability | accesscontrol/usersroles/rolecapability | 4 |
| USERROLE | User Role | accesscontrol/usersroles/userrole | 5 |
| WIDGETROLE | Widget Role | accesscontrol/usersroles/widgetrole | 6 |

### AC_GOVERNANCE (MenuId: 366)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| MENU | Menus | accesscontrol/governance/menu | 1 |
| MODULE | Modules | accesscontrol/governance/module | 2 |

---

## General Module

### GEN_REGION (MenuId: 367)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| COUNTRY | Country | general/region/country | 1 |
| STATE | State | general/region/state | 2 |
| DISTRICT | District | general/region/district | 3 |
| CITY | City | general/region/city | 4 |
| LOCALITY | Locality | general/region/locality | 5 |
| PINCODE | Pincode | general/region/pincode | 6 |

### GEN_MASTERS (MenuId: 368)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| CURRENCY | Currency | general/masters/currency | 1 |
| CURRENCYCONVERSION | Currency Conversion | general/masters/currencyconversion | 2 |
| BANK | Bank | general/masters/bank | 3 |
| GENDER | Gender | general/masters/gender | 4 |
| SALUTATION | Salutation | general/masters/salutation | 5 |
| BLOODGROUP | Blood Group | general/masters/bloodgroup | 6 |
| LANGUAGE | Language | general/masters/language | 7 |
| OCCUPATION | Occupation | general/masters/occupation | 8 |
| RELATION | Relation | general/masters/relation | 9 |
| PAYMENTMODE | Payment Mode | general/masters/paymentmode | 10 |

---

## Setting Module

### SET_PUBLICPAGES (MenuId: 369)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| ONLINEDONATIONPAGE | Online Donation Pages | setting/publicpages/onlinedonationpage | 1 |
| P2PCAMPAIGNPAGE | P2P Campaign Pages | setting/publicpages/p2pcampaignpage | 2 |
| PRAYERREQUESTPAGE | Prayer Request Page | setting/publicpages/prayerrequestpage | 3 |
| MEMBERPORTAL | Membership Portal | setting/publicpages/memberportal | 4 |
| VOLUNTEERREGPAGE | Volunteer Registration Page | setting/publicpages/volunteerregpage | 5 |
| EVENTREGPAGE | Event Registration Page | setting/publicpages/eventregpage | 6 |

### SET_PAYMENTCONFIG (MenuId: 370)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| COMPANYPAYMENTGATEWAY | Payment Gateways | setting/paymentconfig/companypaymentgateway | 1 |
| PAYMENTGATEWAY | Payment Gateway Master | setting/paymentconfig/paymentgateway | 2 |

### SET_COMMUNICATIONCONFIG (MenuId: 371)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| WHATSAPPSETUP | WhatsApp Setup | setting/communicationconfig/whatsappsetup | 1 |
| SMSSETUP | SMS Setup | setting/communicationconfig/smssetup | 2 |
| EMAILPROVIDERCONFIG | Email Provider Config | setting/communicationconfig/emailproviderconfig | 3 |

### SET_DONATIONCONFIG (MenuId: 372)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| DONATIONVERSE | Donation Verse | setting/donationconfig/donationverse | 4 |
| RECEIPTMANAGEMENT | Receipts & Tax | setting/donationconfig/receiptmanagement | 5 |

### SET_MEMBERSHIPCONFIG (MenuId: 373)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| MEMBERSHIPTIERCONFIG | Membership Tiers Config | setting/membershipconfig/membershiptierconfig | 1 |

### SET_DATACONFIG (MenuId: 374)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| MASTERDATA | Master Data | setting/dataconfig/masterdata | 1 |
| MASTERDATATYPE | Master Data Type | setting/dataconfig/masterdatatype | 2 |

### SET_GRIDMANAGEMENT (MenuId: 375)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| GRID | Grid Config | setting/gridmanagement/grid | 1 |
| FIELD_SETTING | Field | setting/gridmanagement/field | 2 |

### SET_DASHBOARDWIDGET (MenuId: 376)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| DASHBOARD_SETTING | Dashboard | setting/dashboardwidget/dashboard | 1 |
| DASHBOARDLAYOUT | Dashboard Layout | setting/dashboardwidget/dashboardlayout | 2 |
| WIDGET | Widget | setting/dashboardwidget/widget | 3 |
| WIDGETTYPE | Widget Type | setting/dashboardwidget/widgettype | 4 |
| WIDGETPROPERTY | Widget Property | setting/dashboardwidget/widgetproperty | 5 |

### SET_ORGSETTINGS (MenuId: 377)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| SETTINGGROUP | Setting Group | setting/orgsettings/settinggroup | 1 |
| ORGANIZATIONSETTING | Organization Setting | setting/orgsettings/organizationsetting | 2 |
| USERSETTING | User Setting | setting/orgsettings/usersetting | 3 |
| COMPANYSETTINGS | Company Settings | setting/orgsettings/companysettings | 4 |

### SET_INTEGRATION (MenuId: 378)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| ACCOUNTINGINTEGRATION | Accounting Integration | setting/integration/accountingintegration | 1 |
| SOCIALMEDIAINTEGRATION | Social Media | setting/integration/socialmediaintegration | 2 |
| APIMANAGEMENT | API Keys | setting/integration/apimanagement | 3 |
| INTEGRATIONMARKETPLACE | Marketplace | setting/integration/integrationmarketplace | 4 |

### SET_DOCUMENT (MenuId: 379)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| DOCUMENTTYPE | Document Types | setting/document/documenttype | 1 |
| CERTIFICATETEMPLATECONFIG | Certificate Template Config | setting/document/certificatetemplateconfig | 2 |

---

## Report & Audit Module

### RA_REPORTS (MenuId: 380)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| REPORTCATALOG | Report Catalog | reportaudit/reports/reportcatalog | 1 |
| CUSTOMREPORTBUILDER | Custom Builder | reportaudit/reports/customreportbuilder | 2 |
| RETENTIONDASHBOARD | Retention Dashboard | reportaudit/reports/retentiondashboard | 3 |
| FUNDRAISINGSUMMARY | Fundraising Summary | reportaudit/reports/fundraisingsummary | 4 |
| POWERBIREPORT | PowerBI Reports | reportaudit/reports/powerbireport | 5 |
| HTMLREPORT | HTML Reports | reportaudit/reports/htmlreport | 6 |
| SCHEDULEDREPORT | Scheduled Reports | reportaudit/reports/scheduledreport | 7 |
| GENERATEREPORT | Generate Report | reportaudit/reports/generatereport | 8 |

### RA_REPORTSETUP (MenuId: 381)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| POWERBIREPORTMASTER | PowerBI Report Master | reportaudit/reportsetup/powerbireportmaster | 1 |
| POWERBIUSERMAPPING | PowerBI User Mapping | reportaudit/reportsetup/powerbiusermapping | 2 |

### RA_AUDIT (MenuId: 382)
| MenuCode | MenuName | MenuUrl | OrderBy |
|----------|----------|---------|---------|
| AUDITTRAIL | Audit Trail | reportaudit/audit/audittrail | 1 |
<!-- COMPANYSETTINGS re-parented to SET_ORGSETTINGS (MenuId 377) by CompanySettings #75 build (2026-05-01). See sql-scripts-dyanmic/CompanySettings-sqlscripts.sql for the live UPDATE statement. -->

---

## Key Observations (for /plan-screens)

1. **Donation config screens moved to Settings**: DonationPurpose, DonationCategory, DonationGroup have CRM_ORGANIZATION as ParentMenu but FE routes under `setting/donationconfig/`
2. **WhatsApp/SMS Setup in Settings**: Config screens are under SET_COMMUNICATIONCONFIG, not CRM
3. **Prayer Request is NEW**: 3 screens (Entry, Review Reply, Reply Queue) under CRM_PRAYERREQUEST — not in current registry
4. **Some menus have List + Form split**: Volunteer has VOLUNTEERLIST + VOLUNTEERFORM, Beneficiary has BENEFICIARYLIST + BENEFICIARYFORM, Grant has GRANTLIST + GRANTFORM — but they map to ONE screen each (list page + view page for FLOW type)
5. **Ambassador Performance**: New screen under CRM_FIELDCOLLECTION — not in current registry
6. **Certificate screens**: Process + Print certificates — not in current registry
7. **Email Keywords**: Under CRM_COMMUNICATION — not in current registry
8. **Report module expanded**: Generate Report, PowerBI Master/Mapping — more screens than registry tracked
