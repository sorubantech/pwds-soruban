# Screen Input Template

Copy this template, fill in the details, and paste to start the AI development pipeline.

---

```
Screen: {ScreenName}
Business: {What this screen does, who uses it, why it exists — 1-3 sentences}

Table:
{Choose one format:}

{Option A — SQL: Paste full CREATE TABLE}
{Option B — Already exists: Write "Already exists" if tables are in the codebase}
{Option C — Quick spec: schema."TableName" with fields}

{Quick spec format example:}
{  schema."TableName"                         }
{  FieldName    type    [FK -- schema.Table]  [NULL]  }
{  PK is first field. NULL means optional. No NULL = required. }
{  FK format: FK -- schema.TableName          }

Business Rules:
- {Rule 1}
- {Rule 2}
- {Rule 3}

Relationships:
- {e.g., "Parent: EntityA, Child: EntityB"}
- {e.g., "FK to Country, Currency, Branch"}

Workflow:
- {e.g., "Draft → Submitted → Approved → Completed"}
- {or "None" for simple CRUD}

Scope: {FULL | BE_ONLY | FE_ONLY | DB_SEED_ONLY}
  FULL       — Backend + Frontend + DB Seed (default)
  BE_ONLY    — Backend + DB Seed only, no frontend
  FE_ONLY    — Frontend only (backend already exists)
  DB_SEED_ONLY — Only generate the seed SQL script

Menu:
  Parent: {PARENTMENUCODE}
  Module: {MODULECODE}
  FEFolder: {frontend folder path — e.g., commonasset/demographics}
```

---

## Examples

### Example 1: Simple Master Table (SQL format)
```
Screen: Donation Purpose
Business: Master table for managing donation purposes (programme areas that donations can be directed to). Admin manages this list.

Table:
CREATE TABLE "fund"."DonationPurposes" (
  "DonationPurposeId" integer NOT NULL,
  "DonationPurposeCode" character varying(50) NOT NULL,
  "DonationPurposeName" character varying(100) NOT NULL,
  "Description" character varying(500),
  PRIMARY KEY ("DonationPurposeId")
);

Business Rules:
- DonationPurposeCode must be unique
- DonationPurposeName is required, max 100 chars
- Description optional

Relationships:
- None

Workflow:
- None

Menu:
  Parent: FUNDRAISINGSETUP
  Module: FUNDRAISING
  FEFolder: fundraising/setup
```

### Example 2: Simple Master Table (Quick spec format)
```
Screen: Testing
Business: Master table for managing testing records with country reference.

Table:
audit."Testings"
TestingId       int
TestingName     string
TestingCode     string
CountryId       int       FK -- com.Countries
Description     string    NULL

Business Rules:
- TestingCode must be unique
- TestingName required, max 100 chars
- CountryId required FK
- Description optional

Relationships:
- FK: Country

Workflow:
- None

Menu:
  Parent: DEMOGRAPHICS
  Module: ADMIN
  FEFolder: commonasset/demographics
```

### Example 3: Business Screen (Existing Tables)
```
Screen: Postal Donation
Business: Manages postal donations received via mail. Each donation can be split into multiple distributions across blessing plans.

Table:
Already exists

Business Rules:
- CRUD operations for Postal Donation
- Postal Distribution as child — add/edit/delete in view page
- Donations can optionally belong to a PostalDonationBatch

Relationships:
- Parent: PostalDonationBatch (optional)
- Child: PostalDonationDistribution
- FK: Company, Branch, Currency, DonationType, PaymentMode, Language, Bank, Country, Contact

Workflow:
- None

Menu:
  Parent: DONATIONSETUP
  Module: DONATION
  FEFolder: donation/donationactivity
```

### Example 4: Workflow Screen
```
Screen: Grant Application
Business: NGO staff submit and track grant applications from funders. Goes through a review workflow from draft to completion. Each application is assigned to a responsible staff member.

Table:
CREATE TABLE "grant"."GrantApplications" (
  "GrantApplicationId" integer NOT NULL,
  "GrantTitle" character varying(500) NOT NULL,
  "FunderId" integer NOT NULL,               -- FK -> corg.Contacts (funder contact)
  "AssignedStaffId" integer NOT NULL,        -- FK -> app.Staffs
  "CurrentStatus" character varying(50) NOT NULL,
  "RequestedAmount" numeric(18,2) NOT NULL,
  "AwardedAmount" numeric(18,2),
  "ApplicationDate" timestamp with time zone,
  "DeadlineDate" timestamp with time zone,
  "ReportingDueDate" timestamp with time zone,
  "Notes" text,
  PRIMARY KEY ("GrantApplicationId")
);

Business Rules:
- GrantTitle is required
- FunderId and AssignedStaffId are required FKs
- RequestedAmount must be greater than zero
- AwardedAmount only set when status is Awarded
- ReportingDueDate only relevant after status is Awarded

Relationships:
- FK: Funder (Contact), AssignedStaff
- Child: GrantReport (funder reporting submissions)

Workflow:
- Draft → Submitted → Under Review → Awarded / Rejected → Reporting → Closed

Menu:
  Parent: GRANTMANAGEMENT
  Module: GRANTS
  FEFolder: grants/applications
```
