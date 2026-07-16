# JC India (PSS 1.0) → PSS 2.0 — Data Migration: Approach, Impact & Estimation

**Prepared for:** Management
**Prepared by:** Development team
**Date:** 15 July 2026
**Scope:** **Contact, Family, Donation, and Staff members** — plus the custom fields and the master/lookup tables these depend on.
**Migration type:** **One-time bulk cutover.** JC India (PSS 1.0) is frozen on a chosen cutover date, moved once into PSS 2.0's cloud database, then retired. There is no ongoing day-to-day sync between the two systems.

> **How to read this document.** Section 3 (the Approach) is written as plain development steps with a flow diagram, so anyone can follow *what will actually happen*. Section 4 (Impact) explains, in plain language, every problem we will hit, **which entity and which fields it affects**, and how we handle it. Section 5 (Estimation) gives the timeline **with the reason behind each number**.

---

## 1. Executive summary (one page)

- **We are migrating four things:** Contacts (about **50 lakh / 5 million** records), Families (about **30–40 lakh / 3.5 million**), Donations (**2–3 times the donations**, roughly **10–15 million**, plus their donation lines and pledge records), and **Staff members** (the internal users, a small table but important because donations and families record *who* created/collected them).
- **The old PSS 1.0 database has almost no "relationships" defined inside it.** In a well-built database, the system itself enforces that "this donation belongs to this contact." In JC India's PSS 1.0, that enforcement does **not** exist — the links are only *implied* by matching id numbers. So during migration we must **carefully rebuild every relationship by hand**, and to do that we must **carry the old id number of each record into PSS 2.0.**
- **The best method is a purpose-built one-time migration service** (extract the data out, transform/clean it, load it into PSS 2.0 in bulk), reusing the bulk-import framework that already exists inside PSS 2.0. **We have already built and used this approach for the Contact import** — so part of the work is already done and proven. What remains is to **retest/harden the Contact import** and **build the same import for Donations, Families, and Staff.** (Other possible approaches, and why we did not choose them, are compared in Section 2.3.)
- **A big part of the head start:** the Contact import — the largest and most complex of the four — is **already developed**. Donations, Families and Staff reuse that same proven pipeline.
- **Good news on custom fields:** what PSS 1.0 calls "Facet", "Facet Category" and "Facet Group" are **already present in PSS 2.0** as **Donation Purpose, Donation Category, and Donation Group**. So these are straightforward master mappings, **not** new custom-field development.
- **Timeline:** about **one month** with a **2-person team**, covering the remaining build (Donations, Families, Staff), retesting the existing Contact import, a full practice run, and the final production cutover. This is achievable in one month *because the hardest piece — the Contact import — is already built.*
- **Important expectation to set:** the actual loading of the data into PSS 2.0 takes only **a few hours** of machine time. The weeks of effort are for **mapping the fields correctly, cleaning bad data, rebuilding relationships, and checking that every number ties out** — this is where migrations succeed or fail.

---

## 2. What we reviewed to prepare this

We did not guess — we opened and studied the actual databases and code of all three systems:

| System | What it is | Where |
|---|---|---|
| **Source** | JC India PSS 1.0 database (SQL Server) | `D:\Repos\Pss1.0\PSSDatabase` |
| **Target** | PSS 2.0 backend (PostgreSQL, .NET 8) | `…\pss-2.0-global\PSS_2.0_Backend\PeopleServe` |
| **Old tool** | The existing trigger-based migration SQL | `D:\Repos\PSS2.0-Data-Migration` |

### 2.1 How the same information is stored in the two systems

| Business thing | In PSS 1.0 (source) | In PSS 2.0 (target) |
|---|---|---|
| **Contact** | `CRM.DONOR` — one very wide table. Phone numbers, emails and **two full addresses** are all columns inside this one table. Has two id numbers: `DONID` (the system id) and `DONCODE` (the business code). | `corg.Contacts` + separate child tables for addresses, phones, emails. |
| **Family** | `CRM.FAMILY`. A contact belongs to a family through the column `DONOR.DONFAMILY`; the family head is flagged by `DONOR.DONFAMILYHEAD`. | `corg.Families`. |
| **Donation** | `CRM.DONATION` (the donation) + `CRM.DONATION_TRN` (the split lines of that donation). A donation points to its contact through `DONATION.DONATEDONID`. | `fund.GlobalDonations` (+ donation-in-kind child). |
| **Staff member** | The PSS 1.0 staff/user table — the internal people who record and collect donations. Their id is referenced by "created by / collected by" columns across Contacts, Families and Donations. | The PSS 2.0 staff/user table. Their old id must also be carried, so "created/collected by" links can be rebuilt. |
| **Donation Purpose / Category / Group** | `CRMMAS.FACETS` (= **Purpose**), `CRMMAS.FACETCATEGORY` (= **Category**), `CRMMAS.FACETGROUP` (= **Group**). | **Already exist:** `fund.DonationPurposes`, `fund.DonationCategories`, `fund.DonationGroups`. |
| **A donor's pledges / subscriptions** | `CRM.DONOR_FACETS` — how much a donor pledged/paid against each purpose. ⚠ It links to the contact through **`DONCODE`, not `DONID`**. | Maps to the contact's pledge / donation-purpose data (linked by contact). |
| **Custom fields (genuinely extra info)** | Any additional donor attributes that have **no matching column** in PSS 2.0. | Stored inside `corg.Contacts` in the **`CustomFields`** field (a small JSON block keyed by `sett.Fields`). |
| **Lookups** (Title, Country, State, District, Pincode, Occupation, Language, Relation, Contact Type, Incoming Mode/Sub-mode, Payment Instrument, Currency) | Various `CRMMAS.*` tables | Matching `com.*` / `corg.*` / `fund.*` master tables |

### 2.2 The three facts that shape everything

1. **PSS 1.0 has almost no enforced relationships.** In the whole area we care about, only **one** real database-level relationship exists (Donation → Currency). Everything else — Contact→Family, Donation→Contact, line→donation, pledge→contact — is only a matching id number with nothing protecting it. **This means the source can contain broken links** (a donation pointing at a contact that no longer exists), and we must find and handle those during migration.
2. **PSS 2.0 currently has nowhere to record "where this record came from."** None of the PSS 2.0 tables has a column to hold the original PSS 1.0 id. Because the source relationships are only id-based, **the only safe way to rebuild them is to carry each old id into PSS 2.0.** So **adding that "old id" column is the very first development task** — it is the backbone of the whole migration.
3. **The source is JC-India-only, but PSS 2.0 is built for a global product.** PSS 2.0 *requires* information on every Family and Donation that JC India never recorded — which **Company/organization** it belongs to, the **currency and base currency**, and the **country**. Since the old data doesn't have these, we **fill them in** during migration (JC India company, Indian Rupee, etc.).

### 2.3 Other approaches we considered

There is more than one way to move data between two databases. We looked at all the realistic options and chose the one that fits **this** situation — a one-time move of tens of millions of records that also have to be **cleaned and re-linked**. Here is the honest comparison.

| Approach | What it means (plain language) | Good for | Why it does / doesn't fit us |
|---|---|---|---|
| **A. Purpose-built one-time service** *(chosen ✅)* | Our own program: pull the old data out, clean and reshape it, rebuild the relationships, load it into PSS 2.0 in bulk. Reuses PSS 2.0's existing import framework. | Big one-time moves that need cleaning and relationship-rebuilding. | **Best fit. The Contact part is already built and working**, so we only extend it to Donations, Families and Staff. Gives us full control over cleaning and re-linking. |
| **B. Ready-made migration tools** (e.g. AWS DMS, pgloader, SSIS) | Off-the-shelf tools that copy tables from SQL Server to PostgreSQL automatically. | A **straight copy** where the two databases already match. | They copy tables as-is. They **cannot** fill in the missing global fields (company, currency, country) or rebuild the missing relationships. We'd still have to write all the same custom logic afterwards — so they save little and add a new tool to learn. |
| **C. Export to files, then import** (CSV/Excel out of PSS 1.0, in to PSS 2.0) | Dump the old tables to spreadsheets/files and load them in. | **Small**, simple, one-off data sets. | At 30–50 million rows this is slow, fragile and error-prone, with **no automatic relationship rebuild**. Not safe at this volume. |
| **D. Direct database link** (linked server / foreign-data wrapper writing straight across) | Connect the two databases and write directly from one into the other. | Quick, small, trusted transfers. | Runs cleaning and loading in one risky step with **no safe staging area** and no easy re-run. A failure midway is hard to recover. Too risky for a production cutover. |
| **E. Old trigger-based tool** (the existing `D:\Repos\PSS2.0-Data-Migration`) | The earlier tool that watches for changes and syncs master data continuously. | **Continuous small syncs** of master/lookup data. | Built for the opposite job. It has **no coverage for Contacts or Donations** (the hardest parts), is slow for a one-time bulk load, and depends on a newer SQL Server feature JC India may not have. We keep only its **one good idea** — storing the source id in every record — and apply it properly in approach A. |

**Bottom line:** Approaches B–E are each good for a *different* job. For a one-time bulk move that must also **clean the data and rebuild relationships that the source never enforced**, a purpose-built service (A) is the right tool — and we already have a working head start on it.

---

## 3. The approach — step by step

### STEP 1 — The overall process (the big picture)

At the highest level, migration is three moves: **pull the old data out → clean and reshape it → load it into PSS 2.0**, with a **practice run first** and a **final production run** at the end.

```
   PSS 1.0 (JC India)              MIGRATION WORKBENCH                 PSS 2.0 (cloud)
   SQL Server                      (a temporary work area)             PostgreSQL
   ─────────────────               ──────────────────────              ─────────────────

   Frozen backup copy   ──(1)──►   Staging tables            ──(4)──►  Live PSS 2.0 tables
   • Contacts (DONOR)    EXTRACT   • raw copies of the       LOAD IN   • Contacts + child tables
   • Families (FAMILY)   the data    old data                 BULK     • Families
   • Donations           out                │                          • Donations
   • Pledges                                 │                          • Staff members
   • Staff members                           │                          • Custom fields (JSON)
   • Master lookups                          ▼
                                    (2) BUILD THE ID MAP
                                    old id  ──►  new id
                                    (one row per record, so
                                     relationships can be
                                     rebuilt)
                                          │
                                          ▼
                                    (3) TRANSFORM & CLEAN
                                    • fill in Company / Currency / Country
                                    • reconnect Contact→Family, Donation→Contact
                                    • split phones/emails/addresses out
                                    • fix dates, remove duplicates,
                                      set broken links aside
                                          │
                                          ▼
                            (5) CHECK EVERYTHING BALANCES
                            • counts match   • donation totals match
                            • relationships correct   • samples verified
```

**In one sentence:** we copy the old data into a safe work area, build a lookup that says "old record X became new record Y," use that lookup to reconnect all the relationships while filling in the missing global information and cleaning bad data, load it into PSS 2.0 in large batches, and then verify that every count and every total matches before going live.

Everything is built to be **re-runnable** — if a practice run finds a problem, we fix it and run the whole thing again from scratch, as many times as needed, until it is perfect. Only then do we do the real cutover.

---

### STEP 2 — Prepare PSS 2.0 to receive the data (foundation work)

Before any data moves, development does the groundwork:

1. **Add the "old id" column.** Add a `LegacyId` field to the Contacts, Families and Donations tables in PSS 2.0 (with an index for speed). This is what lets us rebuild relationships and trace any PSS 2.0 record back to its PSS 1.0 origin. *(Following team policy, we prepare the database-change script and the user runs and commits it.)*
2. **Set up the work area.** Create the temporary staging tables where the old data lands before cleaning.
3. **Take a frozen backup** of the JC India database and work only on that copy — we never touch the live JC India system. We also switch off the old system's audit triggers on the copy so the extract runs fast.

---

### STEP 3 — Migrate the master/lookup tables first

The lookups (Title, Country, State, Occupation, Currency, Payment mode, and the Donation **Purpose/Category/Group** that were "Facets") are migrated **first**, because Contacts and Donations point at them.

- For each lookup, we load it and record **"old lookup id → new lookup id"** in the id map.
- **Donation Purpose, Category and Group already exist in PSS 2.0**, so this is a direct match-and-map, not new development.

---

### STEP 4 — Migrate Staff members

- Load the staff/user records into PSS 2.0 **first among the main entities**, because Contacts, Families and Donations all record *which staff member* created or collected them.
- Record **"old staff id → new staff id"** in the id map, so those "created by / collected by" links can be rebuilt on every later record.
- This is a **small table**, so it is quick — but doing it early keeps the audit trail intact.

---

### STEP 5 — Migrate Families

- Load each family into PSS 2.0, **filling in the Company** (JC India) and **Country**, which the old table did not carry.
- Record **"old FAMID → new FamilyId"** in the id map, so contacts can be reconnected to their families in the next step.

---

### STEP 6 — Migrate Contacts (the biggest table — import already built)

> **Head start:** the Contact import is **already developed and working**. This step is mostly **retesting and hardening** it against the frozen JC India copy, not building from scratch.

- Load each contact from `DONOR` into `corg.Contacts`.
- **Split out** the inline phone numbers, emails and the two address blocks into the separate PSS 2.0 child tables.
- **Reconnect each contact to its family** using the family id map from Step 5.
- **Fill in Company and Country.**
- Record **both** the old `DONID` **and** the old `DONCODE` in the id map — we need both because donations use one and pledges use the other.
- Fold any genuinely extra donor attributes into the contact's **CustomFields** JSON.

---

### STEP 7 — Migrate Donations and pledges (import to be built)

- Load each donation from `DONATION` (and its split lines from `DONATION_TRN`) into `fund.GlobalDonations`.
- **Reconnect each donation to its contact** using the contact id map from Step 6 (matching on `DONID`).
- **Reconnect pledges** from `DONOR_FACETS` to the contact — carefully matching on **`DONCODE`**, because that table uses the business code, not the system id.
- **Carry the original receipt numbers** exactly as they were.
- **Fill in the currency and base currency** (Rupee → base currency) and the Company.
- Set aside, into a "rejected" list, any donation whose contact cannot be found — for review, rather than silently dropping or crashing.

---

### STEP 8 — Check everything balances (before going live)

We do not declare success until all of these pass:

- **Counts match:** number of contacts/families/donations out of PSS 1.0 = number loaded into PSS 2.0 + number deliberately set aside. Nothing vanishes unexplained.
- **Money matches:** total donation amount in PSS 1.0 (by period and currency) = total in PSS 2.0, **to the rupee**.
- **Relationships are correct:** every migrated donation finds its contact; every family head is correctly flagged; every pledge is attached to the right contact.
- **Samples verified:** a set of random contacts, families and donations are compared field-by-field, old vs new.

---

### STEP 9 — Practice run, then production cutover

1. **Practice run #1 — small slice.** Run the whole chain on a small sample end to end, fix whatever surfaces.
2. **Practice run #2 — full volume on a copy.** Run all 30–50 million records on a copy of production, measure the time, tune the speed, fix any data issues.
3. **Production cutover.** Freeze JC India, run the migration for real into PSS 2.0 cloud, run the number-sequence fix (so new receipt/contact codes continue cleanly after the imported ones), do the final balance checks, and sign off.

---

## 4. Impact analysis — what problems will come, and where

Each item below says **what the problem is, which entity/fields it touches, and how we handle it.**

| # | Impact | Which entity / fields | Why it matters | How we handle it | Severity |
|---|---|---|---|---|---|
| 1 | **We must add an "old id" column to PSS 2.0** | New `LegacyId` on **Contacts**, **Families**, **Donations**, **Staff** | Without it we cannot rebuild relationships or trace records back to PSS 1.0 | Add the column + index as the first task (script prepared by us, run by user) | **High** |
| 2 | **Missing global information in the old data** | **Family** → `CompanyId`, `CountryId`; **Donation** → `CompanyId`, `CurrencyId`, `BaseCurrencyId`, exchange rate; **Contact child rows** → `CompanyId` | These are mandatory in PSS 2.0 but JC India never recorded them | Fill in JC India company, Rupee/base currency and country on every row during transform | **High** |
| 3 | **Two id numbers on the contact (`DONID` vs `DONCODE`)** | **Donation → contact** uses `DONID`; **Pledge (`DONOR_FACETS`) → contact** uses `DONCODE` | Using the wrong id silently attaches pledges to the wrong person | Store **both** ids in the id map; apply the correct one per table | **High** |
| 4 | **Broken links in the source** | **Donation → Contact**, **Contact → Family**, **created/collected-by → Staff** (no enforcement in PSS 1.0) | The old data can contain donations pointing to missing contacts, or records pointing to a staff member who no longer exists | Set broken records aside in a "rejected" list for review; never crash the batch, never silently lose them | **Medium-High** |
| 5 | **Custom fields have no place on Family and Donation** | PSS 2.0 stores custom fields **only on Contact**; Family and Donation have no such field | Any extra Family/Donation attribute in PSS 1.0 that has no matching column has nowhere to go | Map to a real column where one exists; for the rest, **management decides** per field: add a column, or accept a documented drop. *(Facet Purpose/Category/Group are NOT affected — they already have proper masters.)* | **Medium** |
| 6 | **Messy keys in the old data** | `PINCODE` and one address table have **no id at all**; a few tables use a different id style; masters and transactions use different id sizes | These need clean, consistent handling on the way in | Generate clean keys where missing; handle each id style explicitly | **Medium** |
| 7 | **Receipt / code numbering must continue cleanly** | **Donation** receipt numbers; **Contact** codes | After we import historical numbers, the app must not reissue the same number to a new record | Carry the original numbers, then run the number-sequence backfill so new numbers start after the highest imported one | **Medium** |
| 8 | **Old server version / speed at volume** | All large tables (30–50 million rows), plus large free-text fields (e.g. prayer request) | Old audit triggers and huge text can slow extraction badly | Work off a frozen copy with audit triggers off; load in large batches; rebuild indexes around the load | **Medium** |
| 9 | **Cutover must be a clean freeze** | Whole JC India system at the cutover moment | If JC India keeps changing during the load, data will split between the two systems | One rehearsed cutover window; the full practice run makes the real run predictable | **Medium** |

**Plain summary of impact:** the two biggest impacts are (a) we must **add a small column to PSS 2.0** to hold the old id, and (b) we must **fill in the "global" details** (company, currency, country) that JC India never captured. Everything else is careful data-cleaning — expected, and planned for.

---

## 5. Estimation — one month, with the reason for each number

**Team assumed:** 2 people (1 senior data/backend engineer + 1 support engineer). **Covers:** the remaining build + retesting the existing Contact import + a full practice run + production cutover. **Scope:** Contact, Family, Donation, Staff + their masters + custom fields.

**Why one month is realistic — the honest picture of what is done vs. left:**

| Part of the work | Status | Effect on the estimate |
|---|---|---|
| **Contact import** (the largest, hardest entity) | **Already built and working** | Only **retest/harden** remains — the big build cost is already spent |
| **Donations import** | To be built | Reuses the proven Contact pipeline, so faster than from scratch |
| **Families import** | To be built | Smaller and simpler than Contacts |
| **Staff import** | To be built | Small table, quick |
| **Masters / lookups + Purpose/Category/Group** | Purpose/Category/Group already exist in PSS 2.0 | Mostly match-and-map, not new build |

Because the heaviest piece is already done, the remaining work fits into **one month (about 4 working weeks) with 2 people working in parallel** — roughly **40 person-days**:

| # | Phase | Days | **Why it takes this long** |
|---|---|---|---|
| 0 | Setup & freeze | 2 | Restore a frozen copy of a very large database, switch off audit triggers, confirm server version, set up the work area — one-off but real. |
| 1 | Finalize field mapping (Families, Donations, Staff, masters) | 4 | Contact mapping is effectively done; this finalizes the remaining entities' columns, the broken-link handling, and the no-id cases. Less than before because Contacts — the widest table — is already mapped. |
| 2 | Add "old id" columns + id-map design | 2 | Small but critical schema change on the big tables, plus the id-map design that makes re-runs safe. |
| 3 | Masters + id map | 2 | Many small lookups, each needs a verified old→new map. Purpose/Category/Group are quick — they already exist. |
| 4 | **Retest & harden the existing Contact import** | 2 | The code exists; this proves it against the frozen JC India copy at full width and fixes anything that surfaces. |
| 5 | **Build Donations import** (biggest remaining item) | 5 | Donations are the highest-volume entity (10–15M) with split lines and pledges (`DONCODE` matching). It reuses the Contact pipeline but still needs its own transform and relationship logic. |
| 6 | **Build Families import** | 3 | Simpler than Contacts; fill company/country, record old FAMID→new id. |
| 7 | **Build Staff import** | 1 | Small table; loaded early so "created/collected by" links can be rebuilt. |
| 8 | Custom fields & pledges | 2 | The `DONCODE`-vs-`DONID` matching and the CustomFields JSON need care to avoid mis-attaching pledges. |
| 9 | Cleaning rules | 3 | Fill company/currency/country, fix dates, remove duplicates, set aside broken links — each rule written, tested, checked on real samples. |
| 10 | Balance-check harness | 3 | Count, money-total, relationship and sampling checks — this is how we *prove* correctness for sign-off. |
| 11 | Practice runs (small, then full volume) | 4 | The small run surfaces surprises early; the full-volume run reveals true timing and the rare problems that appear only at 30–50M rows. |
| 12 | Production cutover | 2 | The real run is fast because it was rehearsed; the time is in careful verification and the number-sequence fix. |
| | **Subtotal** | **35** | |
| | **Contingency (~15%)** | **~5** | Legacy data with no relationships always hides some surprises; a modest buffer keeps the one-month promise realistic. |
| | **Total** | **≈ 40 person-days** | **= about one month with a 2-person team.** |

### Calendar (what to plan for)

| Scenario | When it applies | Time |
|---|---|---|
| **Best case** | Contact import needs little rework; source data reasonably clean | **≈ 3 weeks** |
| **Realistic — plan to this** | Normal legacy data problems, one full practice cycle | **≈ 1 month (4 weeks)** |
| **Cautious** | Old/unknown server version or heavier data cleaning than expected | **≈ 5–6 weeks** |

**The one thing to understand about the timeline:** loading the data into PSS 2.0 takes only **a few hours** of machine time. The one month is the **mapping, building the remaining imports, cleaning, relationship-rebuilding, and balance-checking** — the work that guarantees contacts, families, donations and staff reconnect correctly and the donation totals match to the rupee. Skipping the practice runs or the balance checks is the main way a migration goes wrong after go-live, so those stay in the plan.

### What would change the estimate
- **The custom-field decision** for Family/Donation (Impact #5).
- **The condition of the source data** — the single biggest factor either way.
- **Adding more entities later** (Communications, Cases, etc.) adds time per entity — but each reuses this same proven engine, so they are cheaper.

---

## 6. Decisions we need from management

1. **Approve the purpose-built one-time migration approach** (not the old trigger tool). ✅ recommended
2. **Approve adding the small "old id" column** to Contacts / Families / Donations / Staff. ✅ recommended
3. **Decide the custom-field policy** for Family and Donation, where PSS 2.0 has no custom-field storage (add columns, or accept a documented drop for those specific fields). *(Donation Purpose/Category/Group are unaffected — already covered.)*
4. **Confirm the JC India source server version** and provide a **restorable backup**.
5. **Confirm the JC India company/tenant and base currency** to fill in during the load.

Once 1–5 are agreed, Phases 0–1 can begin immediately and will produce the detailed field-by-field mapping sheet the rest of the build works from.

---

*Prepared from a direct review of the PSS 1.0 database, the PSS 2.0 backend, and the existing migration SQL. We are happy to walk through any section in a meeting.*
