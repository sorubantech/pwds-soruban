# PSS 2.0 — Initial Scope Document

**Product:** PSS 2.0 (Global NGO / Non-Profit Management Platform)
**Scope stage:** Stage 1 — Global product, lighter version
**Modules in scope:** Contact · Donation · Communications
**Prepared by:** Karthick (on behalf of the development team)
**Status:** Baseline scope (as originally agreed at project start)

---

## 1. Purpose

This document records the **initial, agreed scope** of PSS 2.0 as the project
began — a **lighter, global product** built around three core pillars:
**Contact, Donation, and Communications**.

It is intended as the baseline reference for what the product was meant to be at
the outset, before any later changes in direction. Anything not listed here (for
example Case, Grant, Pledges, Matching Gift and other full-business-application
modules) was **outside the initial scope** and was introduced at a later stage.

---

## 2. Product vision (lighter version)

PSS 2.0 was conceived as a **multi-tenant, cloud-based platform** that lets a
non-profit organisation:

1. Maintain a clean, de-duplicated database of the **people and organisations**
   it works with (its contacts and supporters).
2. Record and track the **donations** those supporters give, and issue receipts.
3. **Communicate** with them through email, SMS and other channels, using
   templates and campaigns.

The emphasis at this stage was on a **focused, easy-to-use CRM** — not a full
back-office business application. The three modules below define that focus.

---

## 3. In-scope modules

### 3.1 Contact

The single source of truth for every person and organisation the charity
interacts with.

**Core capabilities**

- **Individual contacts** — personal details, contact information (email, phone,
  address), demographics, and preferences.
- **Organisation / company contacts** — corporate supporters, partner
  organisations, and their key people.
- **Contact relationships** — links between contacts (e.g. spouse, colleague,
  member of an organisation) and household / family grouping at a basic level.
- **Contact categorisation** — types, tags, and status (active / inactive) to
  segment the database.
- **Consent & communication preferences** — opt-in / opt-out per channel,
  supporting data-protection compliance.
- **Search, filter and de-duplication** — find contacts quickly and avoid
  duplicate records.
- **Contact activity view** — a consolidated view of a contact's donations and
  communications history.

**Supporting master data:** contact types, salutations, address / country /
region lookups, tags, and preference categories.

### 3.2 Donation

Recording and tracking of monetary gifts from contacts.

**Core capabilities**

- **One-time donations** — capture amount, date, currency, contact, and the
  channel through which the gift was received (incoming mode).
- **Recurring / regular donations** — standing gifts tracked over time.
- **Donation categorisation** — donation category, purpose / fund, and appeal,
  so income can be reported by cause.
- **Receipting** — generate and number donation receipts for supporters.
- **Payment / incoming modes** — cash, cheque, bank transfer, card, online, etc.
- **Donation history and totals** — per-contact and per-fund giving history and
  summary totals.
- **Basic donation reporting** — income by period, by category / purpose, and by
  contact.

**Supporting master data:** donation categories, purposes / funds, appeals,
incoming (payment) modes, currencies, and receipt numbering settings.

### 3.3 Communications

Outbound engagement with contacts across channels.

**Core capabilities**

- **Email communication** — send individual and bulk emails to selected
  contacts or segments.
- **SMS communication** — send text messages to contacts (subject to consent).
- **Communication templates** — reusable, personalised templates for email and
  SMS, with merge fields (e.g. contact name, donation amount).
- **Campaigns** — group a communication effort to a defined audience and track
  it as a single activity.
- **Audience selection** — target communications using contact categories, tags,
  and filters.
- **Communication log / history** — a record of what was sent, to whom, and
  when, visible on the contact's activity view.
- **Preference enforcement** — respect each contact's opt-in / opt-out settings
  per channel.

**Supporting master data:** template categories, communication channels, and
sender / from-address configuration.

---

## 4. Cross-cutting platform capabilities

These apply across all three modules and were part of the initial scope as the
platform foundation:

- **Multi-tenancy** — each organisation's data isolated within a shared platform.
- **User accounts, roles and permissions** — controlled access to screens and
  actions.
- **Organisation settings** — per-tenant configuration (branding, numbering,
  defaults, currency).
- **Audit trail** — created / modified tracking on core records.
- **Master / lookup data management** — the supporting reference data listed
  under each module above.
- **Dashboards and basic reporting** — summary views for contacts, donations,
  and communication activity.

---

*This is the baseline scope for the lighter global product
(Contact, Donation, Communications).*
