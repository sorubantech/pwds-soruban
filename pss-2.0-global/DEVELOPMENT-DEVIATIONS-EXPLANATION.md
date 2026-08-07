# PSS 2.0 — Note on Development Deviations and Direction Changes

**Prepared for:** Management
**Prepared by:** Karthick (on behalf of the development team)
**Date:** 15 July 2026

---

## Purpose of this note

I would like to respectfully place on record a clear and honest summary of the
development journey of PSS 2.0 so far. During this period the product direction
changed several times, and on a few occasions there was some miscommunication
about the intended scope and target. My intention here is not to point at anyone,
but simply to explain — calmly and factually — what happened at each stage, and
why the effort and timeline moved the way they did.

Each time the direction changed, it was not only a change in planning. It meant
re-working the database table structure, re-implementing the business logic, and
in most cases carrying out fresh data migration and data cleanup as well. I want
the team's effort during these repeated cycles to be understood in the right
spirit.

---

## The journey, stage by stage

### 1. Start — Global product, lighter version
The project began as a **global product** in a lighter form, focused on the core
entities: **Contact, Donation, and Communications**. On this basis we started the
foundational entity-screen development.

### 2. At 60–70% completion — Shift to JC India (PSS 1.0)
When we had reached roughly **60–70% completion**, management asked us to build
for **JC India (PSS 1.0)**. This required refactoring the foundational tables and
moving the PSS 1.0 business into PSS 2.0 — areas such as **Family, Incoming Mode,
Donations, and related modules**. The entire business table structure was
converted to match the PSS 1.0 design. During this same period we also began the
**data migration** work for the JC India database. In addition, during this phase
we developed the **AI Report for PSS 1.0**, which was a separate piece of effort
built alongside the main migration work.

### 3. At ~80% completion — Back to Global product (BeaconCRM reference)
After about **80% of the development and data migration** was completed (Contact,
Donations, Families, and Masters), management asked us to convert the product
**back to a global product**, this time referring to **BeaconCRM** as the model.
Accordingly, we removed the JC India-specific fields, tables, data, and business
logic, performed the necessary cleanup in PSS 2.0, and once again restarted
development from the global perspective.

### 4. Demo with Jackson Sir and Brian — Shift to JC International
A demo was then held with the team, **Jackson Sir, and Brian**. In that demo,
Jackson Sir advised that **this product is for JC International**, and that
**Brian would guide us and provide the requirements**. Following the demo, we
began planning to move from the global product towards **JC International**, and
Brian shared the requirements accordingly. Once again we carried out the same
table-design refactoring and business implementation, and we also completed the
**data migration for the International database — working day and night, with
around 80% of the data moved.**

### 5. Next demo with Jackson Sir — Back to Global again
After some days, another demo was conducted with Jackson Sir. He was **not
satisfied**, and mentioned that the product **did not look like a global
product**. In that same meeting, **Logaraja Sir explained the earlier stages
(points 1 to 4 above)** so that the full context was clear. Jackson Sir then
acknowledged this and said sorry, noting that Brian had been included in this
direction.

We then converted the product **from JC International back to global** once more,
and the same activities followed — removing tables and fields, cleaning up the
data, and restarting the **Contact, Donations, Family, and Communications** work.
After some further days, another demo was conducted with Jackson Sir, in which he
asked us to **complete by 6 April**. At that point **Logaraja Sir requested
Jackson Sir to sign an agreement to keep the plan fixed and not change the
direction again**, so that the team could work towards a stable target.

### 6. 6 April review — Scope expands to a full business application
The **6 April meeting** was scheduled by **Logaraja Sir**, and the review was
carried out with the team and Jackson Sir. The business shown was **again not
found satisfactory**
— because what was reviewed was, in effect, the previous demo's business, now with
all the international details cleaned up and fresh bulk data inserted for Contacts,
Donations, and so on.

In that meeting, Jackson Sir shared a **business document** and asked us to
include **Case, Grant, Pledges, Matching Gift, and related modules** in the
development. At this point, the product moved from a **lighter version** to a
**full business application**.

---

## Summary of the impact

Across these stages, the target changed direction multiple times:

**Global (lighter)** → **JC India / PSS 1.0** → **Global (BeaconCRM)** →
**JC International** → **Global** → **Full business application**

At each turn, the change was not limited to planning alone. Every direction shift
required:

- **Re-designing and refactoring the database table structure**
- **Re-implementing the business logic** for the new target
- **Fresh data migration**, and in several cases **data cleanup** to remove the
  previous target's specific fields, tables, and data

In addition, at the 6 April stage the very nature of the product changed — from a
**lighter CRM (Contact, Donation, Communications)** to a **full business
application** covering Case, Grant, Pledges, Matching Gift, and more. This is a
substantial expansion of scope compared to how the project began.

---

## Closing

I want to state clearly and with full respect that the team has put in genuine,
sincere effort throughout this period, including working late nights on the data
migrations. The deviations described above were driven by changes in direction and
some miscommunication about the intended target — not by any lack of effort on the
development side.

My only request is that this history be understood, and that going forward we are
able to **fix the plan and scope**, so that the team's effort translates fully
into steady, visible progress towards a stable product.

Thank you for taking the time to read this. I am happy to walk through any of the
stages in more detail if that would be helpful.

*— Karthick*
