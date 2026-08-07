# PeopleServe 2.0 — MVP‑1 Scope (Management Summary)

**Date:** 28 Jul 2026 · **Prepared for:** Management review & sign‑off

**In one line:** MVP‑1 is the smallest complete product we can sell, hand over and support — a charity can be signed up, set up by our team in under an hour, and run its day‑to‑day fundraising and casework from day one.

---

## 1. Business modules

| Included in MVP‑1 | What the customer can do |
|---|---|
| **System & Access Control (RBAC)** | Users, roles and a permission matrix — each role is granted view / create / edit / delete per screen, so an organisation controls exactly who sees and does what. Includes module and menu control per organisation. |
| **Contacts** | Donors, beneficiaries, families, organisations — the shared address book, plus **one‑to‑one email** to an individual contact from their record, logged against them |
| **Fundraising (core) — incl. Donation Management** | Record and manage donations (cash, cheque, bank, in‑kind), issue receipts and receipt books, record **refunds**, run campaigns, and monitor everything on the donation dashboard |
| **Case Management** | Applications from beneficiaries, approvals, and disbursements against a case |
| **Grants** | Grants received from funders, budgets, expenses, fund receipts |
| **Volunteer** | Volunteer register, skills, assignments and hours, plus the **public volunteer registration page** the organisation can publish to recruit. A volunteer *login* portal (volunteers signing in to manage their own profile and shifts) comes later. |
| **Public pages** | Organisation‑branded pages the charity publishes to the web: **online donation page**, **peer‑to‑peer campaign & fundraiser pages**, **crowdfunding pages**, **volunteer registration page** — with online card payment through a payment gateway. Set up by the customer's admin, no developer involvement. |
| **Communication — bulk email** | Email templates, mailing lists and **bulk email campaigns** to donors, volunteers and contacts, with delivery tracking. SMS and WhatsApp campaigns follow in MVP‑2. |
| **Organization & Ticketed Events** | Branches and staff, plus **paid ticket events** — ticket types and pricing, registrations, attendee lists and ticket income. General (free / non‑ticketed) event management is **not** in MVP‑1. |

**Deferred to MVP‑2:** Pledges · Volunteer **login** portal · SMS and WhatsApp campaigns · General (non‑ticketed) events · Membership · Prayer Requests · Field Collection · Certificates · Advanced Reports.

*Note on public pages: all of the charity's own public pages — donation, peer‑to‑peer, crowdfunding and volunteer registration — **are in MVP‑1**, and money can be collected online through them. The only public surface deferred is the **volunteer login portal**, where volunteers hold an account and sign in.*

*Note on refunds: refunds are **recorded and tracked inside the system only** — the donation is marked refunded, receipts and reports adjust accordingly, and the audit trail is kept. The money itself is returned to the donor outside the system (by the finance team through the bank or the gateway's own console); MVP‑1 does not send the refund to the payment gateway automatically.*

*Rationale: MVP‑1 covers money in, money out and the people on both sides. Everything deferred is an add‑on to that spine, not a prerequisite.*

---

## 2. Settings — two levels

| Level | Owner | Contents |
|---|---|---|
| **Company Settings** | Customer admin | Organisation identity (name, address, contacts, logo, colours), login page appearance, currency and region, and the **numbering rules** for receipts, cases, grants, events etc. |
| **General Settings** | Customer admin | Behaviour policies grouped into **setting groups**: Fundraising · Communication · Contacts · Field Collection · Reports · Security · Notifications · Compliance. Each group is a small set of switches and defaults that change how a module behaves — configured by the organisation, no development work needed. **In MVP‑1 in full.** |

Both are in MVP‑1, alongside the access‑control screens (**Users · Roles & Permissions matrix · Modules · Menus**) and the reference masters — currencies, regions, document types, salutations — which we pre‑load for every new customer.

---

## 3. Plans

*The plans below are **worked examples**, shown to illustrate how packaging works — the names, module mix and limits are **not final** and are for management to set (see §6.2). The system itself is not tied to these: plans, modules and limits are configured, so they can be renamed, re‑priced or re‑cut at any time without development work.*

| Example plan | Modules | Illustrative limits |
|---|---|---|
| **Free** | Contacts, Donations, limited Email | 2,000 contacts · 25,000 donations · 500 emails/mo · 2 users |
| **Plan 50K** | + Ticketed Events, Volunteers, full Email *(Membership on MVP‑2)* | 500,000 contacts · 5m donations · 15 users |
| **Plan 100K** | + Case Management, Grants *(SMS, WhatsApp on MVP‑2)* | 1m contacts · 10m donations · 50 users |
| **Custom** | Everything available | Negotiated per customer |

The plan catalogue is defined once and stays stable — modules marked *(MVP‑2)* switch on for existing customers when they ship, at no change to their plan.

Access is checked three ways every time: **is the module in your plan · are you within your limit · does your role allow it**. Customers are warned at 80% of a limit and blocked at 100%. **Our own subscription billing** is not automated in MVP‑1 — we invoice customers manually. (This is separate from the payment gateway used on the charity's public donation pages, which *is* in MVP‑1.)

---

## 4. Onboarding

**Staff‑assisted (in MVP‑1).** Our team creates the customer's system through a 7‑step wizard: company profile → plan & subscription → modules → branding → primary administrator → starting data → review & create. The system then builds the tenant automatically (roles, menus, settings, reference data), emails the welcome link, and tracks a go‑live checklist until the customer is Active. The run is resumable — if a step fails we retry it, not the whole thing.

**Self‑service (MVP‑2).** The same engine, packaged for the customer: after a sale we email a single‑use link valid for 7 days; the customer completes 5 steps (commercial terms locked) and their system is created without our involvement.

**Behind both:** a lead record captures every enquiry, moves through triage → qualification → commercials → management approval → won, and then feeds the wizard directly.

---

## 5. Product / marketing site

A public website on `www.<product>.com`, built inside the same product (no separate CMS, no extra hosting): **Home · Modules & Features · Pricing · FAQ · Enquiry · Thank‑you**. The enquiry form appears on Home and Pricing and lands directly in our lead pipeline. Pricing shows plan contents with **"Talk to us"** instead of figures until packaging is signed off. Customer stories page comes later, once we have references.

Three addresses, one system: `www.` (marketing) · `app.` (customers) · `admin.` (our internal control plane).

---

## 6. Current development — company onboarding

The business modules and settings described above are already built. **Development is currently focused on company onboarding** — the machinery that turns a signed customer into a working, fully set‑up system without manual database work. Delivered so far:

| Piece | What it does |
|---|---|
| Plans & entitlements | The plan catalogue, subscriptions, module access and usage limits described in §3 |
| Multi‑currency pricing | A plan can be priced in each market's own currency |
| Provisioning engine | Creates a new customer's system in one run — organisation, roles, menus, settings and reference data — copied from a standard template organisation |
| Provisioning monitor | Internal screen showing each onboarding run step by step, with retry if a step fails |
| Lead & deal capture | Enquiry → qualification → commercial terms → approval → won, feeding straight into the onboarding wizard |
| Go‑live checklist | Tracks each new customer from created to Active |
| Tenant list & detail | Internal view of every customer, their plan and their status |

**Remaining before the first live customer:** apply the database changes and reference data · populate the standard template organisation that every new customer is copied from · rehearse an onboarding end to end · business acceptance testing across the MVP‑1 modules and settings · write and sign off the marketing site content.
