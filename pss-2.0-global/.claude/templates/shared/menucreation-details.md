# DB Seed Reference Data

## auth.Roles

| RoleId | RoleName | RoleCode |
|--------|----------|----------|
| 1 | Super Admin | SUPERADMIN |
| 2 | Business Admin | BUSINESSADMIN |
| 3 | Staff | STAFF |
| 4 | Administrator | ADMINISTRATOR |
| 5 | Staff Data Entry | STAFFDATAENTRY |
| 6 | Staff Correspondence | STAFFCORRESPONDANCE |
| 7 | System Role | SYSTEMROLE |

## auth.Capabilities

| CapabilityId | CapabilityName | CapabilityCode |
|-------------|----------------|----------------|
| 1 | Delete | DELETE |
| 2 | Export | EXPORT |
| 3 | Import | IMPORT |
| 4 | Create | CREATE |
| 5 | Read | READ |
| 6 | Toggle | TOGGLE |
| 7 | Modify | MODIFY |
| 8 | Layout Builder | LAYOUTBUILDER |
| 9 | Role Capability Editor | ROLECAPABILITYEDITOR |
| 10 | DropDown | DROPDOWN |
| 11 | Role Widget Editor | ROLEWIDGETEDITOR |
| 12 | Role Report Editor | ROLEREPORTEDITOR |
| 13 | Menu Rendering | ISMENURENDER |
| 14 | Print | PRINT |
| 15 | Auto Refresh | AUTOREFRESH |
| 16 | Manual Refresh | MANUALREFRESH |
| 17 | Role Html Report Editor | ROLEHTMLREPORTEDITOR |

## sett.GridTypes

| GridTypeCode | GridTypeName | When to Use |
|-------------|-------------|-------------|
| MASTER_GRID | Master Grid | Simple CRUD master tables (Bank, Gender, etc.) — generates GridFormSchema for modal add/edit |
| FLOW | Flow Grid | Business/workflow screens (Donation, Contact, etc.) — custom view pages with React Hook Form, NO parent GridFormSchema. Child grids MAY have GridFormSchema. |

## sett.DataTypes

| DataTypeCode | Mapping From |
|-------------|-------------|
| INT | integer, int, FK IDs |
| STRING | character varying, text, varchar |
| BOOL | boolean |
| DATETIME | timestamp, timestamp with time zone, DateTime |
| DECIMAL | numeric, decimal, money |

## AI Decision: MenuCapabilities per Screen Type

**ISMENURENDER is ALWAYS included** — without it the backend won't return this menu in the navigation API.

**Master/CRUD screens (MASTER_GRID):**
READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

**Business/Flow screens (FLOW):**
READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, PRINT, ISMENURENDER

**Config/Settings screens:**
READ, CREATE, MODIFY, DELETE, TOGGLE, ISMENURENDER

**Report screens:**
READ, EXPORT, PRINT, ISMENURENDER

## AI Decision: RoleCapabilities per Screen Type

**Master/CRUD screens:**
| Role | Capabilities |
|------|-------------|
| SUPERADMIN | All (READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER) |
| BUSINESSADMIN | All |
| ADMINISTRATOR | All |
| STAFF | READ, ISMENURENDER |
| STAFFDATAENTRY | READ, CREATE, MODIFY, ISMENURENDER |
| STAFFCORRESPONDANCE | READ, ISMENURENDER |

**Business/Flow screens:**
| Role | Capabilities |
|------|-------------|
| SUPERADMIN | All |
| BUSINESSADMIN | All |
| ADMINISTRATOR | READ, CREATE, MODIFY, DELETE, TOGGLE, EXPORT, ISMENURENDER |
| STAFF | READ, CREATE, MODIFY, EXPORT, ISMENURENDER |
| STAFFDATAENTRY | READ, CREATE, MODIFY, ISMENURENDER |
| STAFFCORRESPONDANCE | READ, ISMENURENDER |

**AI should adjust** based on business sensitivity — financial screens may restrict CREATE/MODIFY from lower roles.
