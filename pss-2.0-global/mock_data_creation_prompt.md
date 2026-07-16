/continue-screen #2 #3 #4 #6 #10 #15 #16 #18 #42 #44 #135 #62 #63 #64 #49 #50 #51 #52 and this reation

Act as a Senior Solution Architect, Product Manager, Business Analyst, and PostgreSQL Database Developer with 20+ years of experience building enterprise Case Management, Grant Management, and Fund Management systems.

## Objective

I need to prepare realistic demo data for my application for a management demonstration tomorrow.

The mock data must simulate a live production environment so that every dashboard, list page, detail page, reports, analytics, and tracking screen looks realistic.

## Timeline

Generate complete historical and future data covering:

- Previous 3 years
- Current year
- Next 2 years

The data should be distributed naturally across the timeline instead of being inserted on a single date.

## Business Domain

This is a Case & Program Management system where organizations provide services and financial support to beneficiaries.

The business flow includes:

1. Program Creation
2. Program Review
3. Program Approval / Rejection
4. Funding Campaign Creation
5. Fund Raising from multiple funding sources
6. Donations / Fund Collection
7. Grant Requests
8. Grant Review
9. Grant Approval / Rejection
10. Fund Allocation
11. Fund Transfer
12. Beneficiary Enrollment
13. Service Delivery
14. Payment Processing
15. Fund Utilization
16. Case Tracking
17. Activity Logs
18. Status History
19. Documents
20. Audit Trail
21. Notifications
22. Reports
23. Dashboards

## Important Requirements

This is NOT random sample data.

The data should look exactly like a real production application after running for several years.

Every module must be interconnected.

Example:

Organization
    ↓
Program
    ↓
Funding Campaign
    ↓
Funding Source
    ↓
Collected Funds
    ↓
Grant Request
    ↓
Approval Workflow
    ↓
Fund Allocation
    ↓
Beneficiary
    ↓
Fund Transfer
    ↓
Service Delivery
    ↓
Case Closure

Everything should reference valid IDs and relationships.

## Data Expectations

Create realistic:

- Organizations
- Programs
- Categories
- Departments
- Employees
- Users
- Roles
- Beneficiaries
- Families
- Volunteers
- Donors
- Corporate Sponsors
- Government Agencies
- NGOs
- Funding Sources
- Campaigns
- Donations
- Grant Requests
- Approvals
- Rejections
- Allocations
- Payments
- Transactions
- Service Requests
- Case Notes
- Documents
- Activities
- Notifications
- Audit Logs

## Realistic Business Behaviour

The data should include:

- Successful approvals
- Rejected requests
- Pending approvals
- Cancelled programs
- Completed programs
- Active programs
- Expired programs
- Partial funding
- Fully funded programs
- Over-funded campaigns
- Failed transfers
- Refunded transactions
- Multiple approval levels
- Multiple beneficiaries per program
- Multiple funding sources per program
- Multiple grants per beneficiary
- Different payment statuses
- Different workflow stages

## Dashboard Friendly Data

Generate enough records so dashboards show meaningful charts like:

- Monthly funding trends
- Program growth
- Beneficiary growth
- Approval ratios
- Pending approvals
- Fund utilization
- Geographic distribution
- Category-wise reports
- Department reports
- Employee performance
- Program status distribution

## PostgreSQL Requirement

Generate PostgreSQL INSERT scripts.

Separate each module into its own SQL file.

Example:

01_organizations.sql
02_departments.sql
03_users.sql
04_programs.sql
05_program_approvals.sql
06_funding_sources.sql
07_fundraising.sql
08_donations.sql
09_grant_requests.sql
10_grant_approvals.sql
11_allocations.sql
12_beneficiaries.sql
13_payments.sql
14_service_delivery.sql
15_activity_logs.sql
16_notifications.sql
17_audit_logs.sql

Every SQL file should be executable independently while maintaining referential integrity.

## Relationships

All foreign keys must be valid.

No orphan records.

No duplicate business keys.

IDs should be realistic.

Dates should follow business logic.

Amounts should be realistic.

Status transitions must make sense.

Approval history should align with current status.

Fund balances should always be mathematically correct.

## Naming

Use realistic names for:

- Organizations
- Programs
- Donors
- Beneficiaries
- Employees
- Cities
- States
- Countries
- Banks
- Payment references

Avoid placeholder values like:

Test
ABC
XYZ
Sample
Lorem Ipsum

Use production-quality names.

## Goal

When my management opens any screen, it should appear as though the system has been actively used by a real organization for the past 3 years, with ongoing operations and planned activities for the next 2 years.

The data should be internally consistent across all screens so users can navigate between modules without finding missing or inconsistent information.

Before generating any SQL, first analyze the complete database schema, identify all table relationships, dependencies, foreign keys, business rules, and workflow logic. Then generate the SQL scripts in the correct dependency order to ensure they execute successfully without constraint violations.