# PSS 2.0 (PeopleServe) — Application Business Context

## What Is PSS 2.0?

PSS 2.0 (PeopleServe) is a **multi-tenant NGO SaaS platform** — a global, cloud-based software product designed for non-profit organisations, charities, social enterprises, and faith-based ministries worldwide.

The platform provides an end-to-end operational backbone: constituent (donor/beneficiary) management, fundraising, communications, volunteer management, membership, grants, case management, field operations, and AI-driven intelligence — all in a single, configurable system.

**Positioning**: Competing with platforms like Salesforce Nonprofit Cloud, Bloomerang, Neon CRM, DonorDock, and Virtuous — targeting the mid-market NGO segment with differentiators in WhatsApp-native communication, field ambassador operations, mobile-first design, and AI engagement scoring.

---

## Target Users & Roles

| Role | Description | Access Level |
|------|-------------|-------------|
| **SuperAdmin** | PeopleServe platform administrator | Cross-tenant, all organisations |
| **BusinessAdmin** | Organisation-level admin | Single tenant, all modules |
| **Administrator** | Senior operations manager | Full access within their org |
| **Staff** | Programme staff, fundraising staff, field workers | Role-based module access |
| **StaffDataEntry** | Data entry operators | Limited CRUD access |
| **StaffCorrespondance** | Communications and correspondence staff | Read + communications |
| **SystemRole** | System/automated process identity | Internal use |

---

## Core Business Processes

### 1. Constituent (Contact) Management — CRM
The heart of the platform — managing relationships with donors, beneficiaries, volunteers, and members.

- **Contact profiles**: Full personal information (name, address, phones, emails, social links)
- **Multiple contact points**: Multiple addresses, phones, and emails per contact
- **Household/family grouping**: Track family relationships between contacts
- **Contact types**: Donor, Beneficiary, Volunteer, Member, Church Leader, Ambassador
- **Communication preferences**: Preferred language, channel (phone, email, SMS, WhatsApp, postal)
- **Constituent timeline**: Chronological view of all interactions (donations, communications, events, cases)
- **Engagement scoring**: AI-driven 0–100 score reflecting giving history, recency, frequency, engagement depth
- **Duplicate detection and merge**: Identify and merge duplicate constituent records
- **Tags and segmentation**: Flexible tagging for targeted campaigns and reporting
- **Contact source tracking**: How they first connected (event, website, referral, walk-in, field agent)
- **360° view**: All donations, communications, cases, event attendance, volunteer hours for any contact

### 2. Fundraising and Donation Management
Multi-channel donation processing for modern NGOs.

**Donation Channels:**
- Cash and in-person collection
- Cheque / Demand Draft
- Online payment gateway (Stripe, Razorpay, PayPal, etc.)
- Recurring (standing order / subscription giving)
- Peer-to-peer (P2P) fundraising campaigns
- Crowdfunding campaign pages
- In-kind / non-cash gifts with valuation
- Bulk/corporate donations
- Field collection (QR code, mobile agent)
- Pledge commitments with fulfilment tracking
- International/multi-currency donations

**Donation Lifecycle:**
```
Donor identified → Contact created/found → Donation received → Purpose allocated
→ Distribution split (if multiple purposes) → Receipt generated
→ Thank-you communication sent → Tax document issued
```

**Key Features:**
- Multi-currency support
- Donation split across multiple purposes in a single transaction
- Receipt and tax document generation (country-specific)
- Recurring donation management with webhook-based status updates
- Corporate matching gift tracking
- Refund and failed-payment retry handling
- Payment reconciliation with accounting systems
- Suggested donation amounts (AI-driven, Phase 2)

### 3. Communication and Marketing
Reaching constituents through every relevant channel.

- **Email campaigns**: Bulk email with dynamic templates ({{ContactName}}, {{DonationAmount}}, etc.)
- **SMS campaigns**: Text message outreach
- **WhatsApp**: Native integration — campaigns, conversations, template editor (key differentiator for non-Western markets)
- **Automated workflows**: Trigger-based sequences (post-donation thank you, lapse alerts, event reminders)
- **Notification centre**: In-app notifications for staff
- **Per-tenant email/SMS config**: Separate provider settings per organisation
- **Template management**: Reusable templates for receipts, newsletters, event invitations, certificates
- **Saved filters**: Reusable recipient filter sets
- **Placeholder management**: Dynamic template variables per entity type
- **Email/communication analytics**: Delivery, open, click, bounce tracking

### 4. Event Management
Managing fundraising events, community gatherings, and programme events.

- **Event creation**: Title, description, dates, venue, capacity, ticketing
- **Public event registration pages**: Embeddable / shareable registration
- **Ticketing and attendance tracking**: Check-in, attendance confirmation
- **Event-linked donations**: Capture donations during or after events
- **Post-event analytics**: Attendance vs. target, revenue generated, follow-up actions

### 5. Volunteer Management
Recruiting, scheduling, and tracking volunteers.

- **Volunteer profiles**: Personal details, skills, availability, history
- **Volunteer recruitment**: Application and onboarding workflow
- **Hour tracking**: Log and approve volunteer hours per programme/event
- **Volunteer scheduling**: Assign volunteers to events, programmes, or roles
- **Volunteer-to-donor conversion**: Track and incentivise volunteers who become donors
- **Volunteer dashboard**: Overview of hours, upcoming assignments, impact

### 6. Membership Management
Managing membership tiers, renewals, and member portals.

- **Membership tiers**: Define tiers with benefits, fees, and renewal periods
- **Member enrolment**: Enrol contacts as members with tier assignment
- **Renewal management**: Automated renewal reminders, lapse tracking
- **Member portal**: Self-service portal for members to view status, update details, renew
- **Membership reporting**: Active members, renewals due, revenue by tier

### 7. Grant Management
Tracking grant applications, deadlines, reporting, and compliance.

- **Grant pipeline**: Track opportunities, applications, and awarded grants
- **Deadline management**: Calendar view of application and reporting deadlines
- **Funder relationships**: Track funders as contacts with relationship history
- **Grant reporting**: Generate reports to meet funder requirements
- **Budget management**: Track grant budgets against actuals (enterprise)

### 8. Programme and Case Management
Managing service delivery, beneficiaries, and outcomes for service-delivery NGOs.

- **Programme management**: Define programmes with goals, budgets, timelines
- **Beneficiary intake**: Register beneficiaries, capture intake information
- **Case management**: Open, track, and close cases with notes, documents, referrals
- **Case dashboard**: Active cases, overdue actions, staff workload
- **Outcome measurement**: Track programme outputs and impact indicators

### 9. Field Collection (Ambassador Module)
A unique differentiator — dedicated field fundraising agent workflow.

- **Ambassador (field agent) profiles**: Manage field collectors with territory assignment
- **QR code-based collection**: Agents collect donations via QR → links to donor contact
- **Collection tracking**: Log collections with geo-stamp and agent attribution
- **Receipt book management**: Track physical receipt books issued to agents
- **Performance monitoring**: Collection targets vs. actuals, leaderboards
- **Agent mobile app**: Offline-capable mobile collection with sync

### 10. AI and Intelligence
Intelligent features that surface insights and drive action.

- **Engagement scoring**: AI-driven 0–100 score per constituent (giving history, recency, frequency, depth)
- **Churn/lapse prediction**: Identify donors likely to lapse 60–90 days in advance
- **Action Board**: AI-surfaced daily task list — who to contact, who's at risk, who's ready to upgrade
- **Next-best-action**: Personalised recommendations for each constituent interaction
- **AI communication drafting**: Assisted drafting of personalised outreach (Phase 2)
- **Natural language reporting**: Query data via plain English (Phase 2)
- **Predictive fundraising analytics**: Forecast campaign outcomes (Phase 3)

### 11. Reporting and Analytics
Organisation-wide performance, fundraising trends, and operational metrics.

- **Standard reports**: Per-module standard reports (donation, contact, campaign, volunteer, membership)
- **Custom report builder**: Drag-and-drop report creation across entities
- **Dashboard with KPI widgets**: Role-specific dashboards with real-time metrics
- **Donor retention dashboard**: LYBUNT, SYBUNT, retention rates, churn cohorts (signature feature)
- **PowerBI integration**: Advanced analytics dashboards
- **Scheduled reports**: Automated report delivery by email
- **Export**: Excel/CSV/PDF export for all reports
- **HTML report viewer**: Rich formatted reports with branding

### 12. Mobile Experience
Purpose-built mobile for donors and staff — a key differentiator.

- **Donor app**: Donors view giving history, donate, RSVP to events, update profile
- **Staff/field agent app**: Staff access constituent data, log collections, check tasks, receive push notifications
- **Push notifications**: FCM/APNs-based real-time notifications
- **QR code scanning**: Collection and event check-in via QR
- **Offline capability**: Field collection works without internet, syncs on reconnect

### 13. Dashboard and Customisation
Operational dashboards for different user roles.

- **Widget-based dashboards**: KPIs, charts, donation trends, engagement metrics
- **Per-user customisation**: Each user arranges their own dashboard
- **Role-specific views**: Admin sees org-wide metrics, field manager sees territory metrics

### 14. Data Import and Export
Bulk data migration and regular imports.

- **Excel/CSV import**: Bulk contact and donation data import with field mapping
- **Validation pipeline**: Validate data before committing with error reports
- **Background processing**: Large imports via background jobs with real-time progress
- **Template generation**: Downloadable import templates per entity type

---

## Platform Modules

### Application Module (Schema: `app`)
**Purpose**: Core organisational and operational management.
- **Organisation (Company)**: Tenant root — each NGO is a separate organisation
- **Branch**: Physical offices, chapters, regional centres
- **BranchPincode**: Service area mapping
- **BranchUser**: Staff-branch assignments
- **Staff**: All organisation workers
- **StaffCategory**: Staff classifications
- **Campaign**: Fundraising campaigns with targets and timelines
- **Event**: Fundraising events, community gatherings, programme events
- **Product**: Programme offerings and giving products
- **OrganisationalUnit**: Department/team structure

### Auth Module (Schema: `auth`)
**Purpose**: User access control and security.
- **User**: System users with credentials
- **Role**: Permission groups
- **Capability**: Granular permissions (Read, Create, Modify, Delete, Toggle, Import, Export)
- **Menu**: Navigation hierarchy
- **Module**: Application module groupings
- **MenuCapability / RoleCapability / UserRole**: Permission assignment chain

### Contact Module (Schema: `corg`)
**Purpose**: Constituent relationship management.
- **Contact**: Donors, beneficiaries, volunteers, members — the core CRM entity
- **ContactEmailAddress / ContactPhoneNumber / ContactAddress**: Multiple contact points
- **ContactRelationship**: Contact-to-contact relationships
- **ContactType / ContactTypeAssignment**: Donor, Beneficiary, Volunteer, Member, Ambassador
- **ContactChannel / ChannelType**: Communication preferences
- **ContactSocialLink**: Digital identity
- **Family**: Household grouping of contacts

### Donation Module (Schema: `fund`)
**Purpose**: Financial management — donations, receipts, distributions.
- **Donation**: Individual donation records
- **DonationDistribution**: Split donations across multiple purposes
- **DonationPurpose / DonationCategory / DonationGroup**: Purpose hierarchy
- **BulkDonation / BulkDonationDistribution**: Batch/corporate processing
- **ChequeDonation**: Cheque-specific tracking
- **OnlineDonation**: Payment gateway donations
- **RecurringDonation**: Standing order / subscription giving
- **Pledge / PledgePayment**: Pledge commitments and fulfilment
- **InKindDonation**: Non-cash gifts with valuation
- **MatchingGift**: Corporate employer matching gift tracking
- **Refund**: Donation refund records

### Shared Module (Schema: `com`)
**Purpose**: Global reference data.
- **Country / State / District / City**: Geographic hierarchy
- **Bank**: Banking institutions
- **Currency / CurrencyConversion**: Multi-currency support
- **Gender / Nationality / Occupation / Salutation / Language / Relation**: Personal reference data
- **DocumentType**: Document classifications
- **PaymentGateway**: Stripe, Razorpay, PayPal, etc.
- **PaymentMode**: Cash, Cheque, Online, Wire Transfer, QR
- **MasterData / MasterDataType**: Configurable lookup values

### Setting Module (Schema: `sett`)
**Purpose**: Dynamic UI configuration and system settings.
- **Grid / GridType / GridField / Field / DataType**: No-code data table generation
- **GridFieldFilter / UserGridFilter / UserGridField**: User-customised grid views
- **CustomField**: Dynamic JSONB custom fields
- **Dashboard / DashboardLayout / Widget / WidgetType**: Dashboard builder
- **OrganisationSetting / UserSetting**: System and user preferences
- **CaptionResource**: Localisation (multilingual labels)

### Notify Module (Schema: `notify`)
**Purpose**: Email, SMS, WhatsApp, and notification management.
- **EmailTemplate / SMSTemplate / WhatsAppTemplate**: Message templates with placeholders
- **EmailSendJob / EmailSendQueue**: Email scheduling and queue
- **CompanyEmailProvider / CompanyEmailConfiguration**: Per-tenant provider config
- **Notification**: In-app notifications
- **AutomationWorkflow**: Trigger-based communication sequences
- **PlaceholderDefinition**: Custom template variables
- **SavedFilter**: Saved recipient filters for bulk sends

### Report Module (Schema: `rep`)
**Purpose**: Reporting and analytics.
- **Report**: Report definitions
- **ReportExecutionLog**: Audit trail
- **PowerBIReport / PowerBIUserMapping**: PowerBI integration

### Volunteer Module (Schema: `vol`)
**Purpose**: Volunteer lifecycle management.
- **Volunteer**: Volunteer profiles linked to contacts
- **VolunteerHourLog**: Hour tracking per event/programme
- **VolunteerSchedule**: Scheduling assignments
- **VolunteerApplication**: Recruitment workflow

### Membership Module (Schema: `mem`)
**Purpose**: Membership tier and renewal management.
- **MembershipTier**: Tier definitions with benefits and fees
- **MemberEnrolment**: Member registration with tier assignment
- **MembershipRenewal**: Renewal tracking and reminders

### Grant Module (Schema: `grant`)
**Purpose**: Grant lifecycle management.
- **Grant**: Grant opportunity and application records
- **Funder**: Funder organisations (linked to contacts)
- **GrantReport**: Funder reporting submissions
- **GrantBudget**: Budget tracking per grant

### Case Management Module (Schema: `case`)
**Purpose**: Service delivery and beneficiary case tracking.
- **Programme**: Programme definitions with goals and budgets
- **Beneficiary**: Beneficiary records (linked to contacts)
- **Case**: Individual case records with status workflow
- **CaseNote**: Case notes and activity log

### Field Collection Module (Schema: `field`)
**Purpose**: Field ambassador fundraising operations.
- **Ambassador**: Field agent profiles with territory assignment
- **FieldCollection**: Collection records with agent and location
- **ReceiptBook**: Physical receipt book issuance and tracking

### AI Module (Schema: `ai`)
**Purpose**: Engagement scoring, predictions, and intelligent actions.
- **EngagementScore**: AI-generated constituent engagement scores
- **ChurnPrediction**: Lapse risk scores with recommended actions
- **ActionBoard**: AI-surfaced daily task items per staff user

### Import Module
**Purpose**: Bulk data import with validation.
- **ImportSession / ImportSessionDetail**: Import tracking with status workflow

### Audit Module
**Purpose**: Change tracking and compliance.
- **TrackingData**: Entity change history

---

## Multi-Tenancy Model

- **Organisation (Company)** = Tenant root — each NGO is an independent tenant
- **Branch** = Physical office or chapter within an organisation
- Most business data is organisation-scoped (CompanyId)
- Reference data (countries, currencies, languages) is global/shared
- SuperAdmin sees all tenants; Branch staff see only their branch

---

## Permission Model

**7 standard capabilities per entity:**
1. **Read** — View list and detail
2. **Create** — Add new records
3. **Modify** — Edit existing records
4. **Delete** — Soft delete (IsDeleted=true)
5. **Toggle** — Activate/deactivate (IsActive toggle)
6. **Import** — Bulk data import
7. **Export** — Data export to Excel/CSV

**Special capabilities**: Download, Dropdown, Roleeditor, Reporteditor, Widgeteditor, Layoutbuilder, Templateeditor, Print, AutoRefresh, ManualRefresh

---

## Business Terminology

| Term | Meaning in NGO Context |
|------|----------------------|
| **Contact / Constituent** | Any person in the system — donor, beneficiary, volunteer, member, ambassador |
| **Donor** | Person or organisation that makes financial contributions |
| **Beneficiary** | Person who receives services or aid from the NGO |
| **Donation Purpose** | The programme or cause area a donation supports |
| **Donation Distribution** | Split of one donation across multiple purposes |
| **Campaign** | Fundraising initiative with target amount and timeline |
| **Pledge** | Committed future donation with a fulfilment schedule |
| **Recurring Donation** | Regular automated giving (monthly, annual, etc.) |
| **In-Kind Gift** | Non-cash donation (goods, services) with estimated value |
| **Matching Gift** | Employer/corporate donation that matches a donor's gift |
| **Ambassador** | Field fundraising agent who collects donations on behalf of the NGO |
| **MasterData** | Configurable lookup values (general-purpose key-value store) |
| **Grid** | Dynamic data table configuration for any entity (no-code UI) |
| **Widget** | Dashboard visualisation component (KPI, chart, list) |
| **CustomField** | Dynamic user-defined fields stored as JSONB |
| **Engagement Score** | AI-generated 0–100 score reflecting constituent engagement depth |
| **LYBUNT** | Last Year But Unfortunately Not This Year — lapsed donor segment |
| **SYBUNT** | Some Year But Unfortunately Not This Year — lapsed donor segment |
| **Tenant** | An individual NGO organisation using the platform |
