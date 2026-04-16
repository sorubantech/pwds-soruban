# PSS 2.0 — Screen Dependency Order

> Screens must be built in dependency order. A screen's FK targets must exist before it can be generated.
> This file defines the exact build sequence.

---

## Build Waves

### Wave 1: P1-Setup Masters (No FK dependencies — build first)

These are master/reference tables that other screens depend on. They have no FK to other new entities.

| Order | Screen | Module | Type | New Module? | Depends On |
|-------|--------|--------|------|-------------|------------|
| 1.1 | Program | Case Mgmt | MASTER_GRID | YES — `case` schema | Nothing new |
| 1.2 | Membership Tier | Membership | MASTER_GRID | YES — `mem` schema | Nothing new |
| 1.3 | Document Types | Settings | MASTER_GRID | NO — `com` schema | Nothing new (BE exists) |

**After Wave 1**: Program, MembershipTier, DocumentType entities available as FK targets.

---

### Wave 2: P2-Core Entities (FK to existing or Wave 1 entities)

| Order | Screen | Module | Type | Key FKs (all must exist) |
|-------|--------|--------|------|--------------------------|
| 2.1 | SMS Template | Communication | MASTER_GRID | Company (exists) |
| 2.2 | WhatsApp Template | Communication | MASTER_GRID | Company (exists) |
| 2.3 | WhatsApp Setup | Communication | Config | Company (exists) |
| 2.4 | Notification Templates | Communication | MASTER_GRID | Company (exists) |
| 2.5 | Tags & Segmentation | Contacts | MASTER_GRID | Contact (exists) |
| 2.6 | Matching Gift | Fundraising | MASTER_GRID | Donation (exists), Contact (exists) |
| 2.7 | Pledge | Fundraising | FLOW | Contact (exists), Campaign (exists) |
| 2.8 | Beneficiary | Case Mgmt | FLOW | Contact (exists), Program (Wave 1) |
| 2.9 | Volunteer | Volunteer | FLOW | Contact (exists) |
| 2.10 | Member Enrollment | Membership | FLOW | Contact (exists), MembershipTier (Wave 1) |
| 2.11 | Grant | Grants | FLOW | Contact (exists), Staff (exists) |
| 2.12 | Ambassador | Field Collection | FLOW | Staff (exists), Branch (exists) |
| 2.13 | User Management | Administration | FLOW | User entity (exists, FE only needed) |

**After Wave 2**: Volunteer, Beneficiary, Grant, MemberEnrolment, Pledge, Ambassador entities available.

---

### Wave 3: P3-Business Entities (FK to Wave 2 entities)

| Order | Screen | Module | Type | Key FKs (all must exist) |
|-------|--------|--------|------|--------------------------|
| 3.1 | Case | Case Mgmt | FLOW | Beneficiary (Wave 2), Staff (exists) |
| 3.2 | Volunteer Schedule | Volunteer | FLOW | Volunteer (Wave 2), Event (exists) |
| 3.3 | Hour Tracking | Volunteer | FLOW | Volunteer (Wave 2) |
| 3.4 | Membership Renewal | Membership | FLOW | MemberEnrolment (Wave 2) |
| 3.5 | Grant Report | Grants | FLOW | Grant (Wave 2) |
| 3.6 | Refund | Fundraising | FLOW | Donation (exists), Contact (exists) |
| 3.7 | Payment Reconciliation | Fundraising | FLOW | PaymentTransaction (exists) |
| 3.8 | SMS Campaign | Communication | FLOW | SMSTemplate (Wave 2) |
| 3.9 | WhatsApp Campaign | Communication | FLOW | WhatsAppTemplate (Wave 2) |
| 3.10 | WhatsApp Conversations | Communication | FLOW | Contact (exists) |
| 3.11 | Notification Center | Communication | FLOW | Notification (exists) |
| 3.12 | P2P Campaign | Fundraising | FLOW | Campaign (exists), Contact (exists) |
| 3.13 | Crowdfunding | Fundraising | FLOW | Campaign (exists) |
| 3.14 | Event Ticketing | Organization | FLOW | Event (exists) |
| 3.15 | Auction Management | Organization | FLOW | Event (exists), Campaign (exists) |
| 3.16 | Contact Import | Contacts | FLOW | ImportSession (exists) |
| 3.17 | Audit Trail | Administration | FLOW | No FK deps, complex custom |
| 3.18 | Custom Fields | Settings | Config | BE API exists |

**After Wave 3**: All standard CRUD screens complete.

---

### Wave 4: P4-Advanced (AI, analytics, custom — separate pipeline)

| Order | Screen | Module | Type | Notes |
|-------|--------|--------|------|-------|
| 4.1 | Automation Workflow | Communication | FLOW | Complex workflow builder UI |
| 4.2 | Engagement Scoring | AI Intelligence | FLOW | ML scoring engine integration |
| 4.3 | Churn Prediction | AI Intelligence | FLOW | ML prediction model |
| 4.4 | Action Board | AI Intelligence | FLOW | AI-driven task recommendations |

**Note**: Wave 4 screens require custom business logic beyond standard CRUD. They may need manual development or specialized prompts.

---

## New Module Creation Required

These waves introduce entities in schemas that don't have a DbContext yet:

| Module | Schema | Needed By | Entities |
|--------|--------|-----------|----------|
| Case Management | `case` | Wave 1 (Program) | Programme, Beneficiary, Case, CaseNote |
| Volunteer | `vol` | Wave 2 (Volunteer) | Volunteer, VolunteerHourLog, VolunteerSchedule |
| Membership | `mem` | Wave 1 (MembershipTier) | MembershipTier, MemberEnrolment, MembershipRenewal |
| Grants | `grant` | Wave 2 (Grant) | Grant, GrantReport, GrantBudget |

**For each new module, the backend developer must create:**
1. `I{Module}DbContext.cs` in Base.Application/Data/Persistence/
2. `{Module}DbContext.cs` in Base.Infrastructure/Data/Persistence/
3. `{Module}Mappings.cs` in Base.Application/Mappings/
4. Add `I{Module}DbContext` to IApplicationDbContext inheritance
5. Register `{Module}Mappings.ConfigureMappings()` in DependencyInjection.cs
6. New `Decorator{Module}Modules` class in DecoratorProperties.cs
7. Update GlobalUsing.cs (3 files)

---

## Estimated Effort by Wave

| Wave | Screens | New Modules | Estimated Sessions |
|------|---------|-------------|-------------------|
| Wave 1 | 3 | 2 (case, mem) | 3 plan + 3 build = 6 |
| Wave 2 | 13 | 2 (vol, grant) | 2 plan + 13 build = 15 |
| Wave 3 | 18 | 0 | 3 plan + 18 build = 21 |
| Wave 4 | 4 | 0 | Custom — estimate 4-8 |
| **Total** | **38** | **4** | **~46-50 sessions** |
