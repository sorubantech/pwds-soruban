# Contact Import & Donation Import — plan

Status: **plan only, nothing built.** Scope: surface and correct Contact import and Donation
import on their respective screens.

---

## 1. What already exists (verified in the repo, not assumed)

Import is **not greenfield**. There is a complete, config-driven framework:

| Layer | Where |
| --- | --- |
| Registry of what can be imported | `import.ImportGridDefinitions` + `ImportGridFields` + `ImportGridChildRelations` |
| Per-grid validation | a PostgreSQL function named in `ImportGridDefinition.ValidationProcedure` |
| Per-grid execution | a PostgreSQL function named in `ImportGridDefinition.ImportProcedure` |
| Session lifecycle | `ImportSession` — upload → validate → schedule/start → progress → results |
| Real-time progress | `Hubs/ImportProgressHub.cs` + `use-import-signalr.ts` |
| Deferred/large runs | `ImportScheduledExecutionService` + `ImportScheduleRecoveryExtension` |
| UI | `components/custom-components/import-wizard/` (8 steps + session list/log/indicator) |
| Entry point on any grid | `data-table-general-toolbar.tsx` (advanced **and** flow) renders `DataTableImportOption` when `tableConfig.enableImport && capability.canImport` |

Both procedures are **required** on a definition — the code has no fallback. Registering an entity
means: seed one `ImportGridDefinitions` row + N `ImportGridFields` rows (+ child relations), ship the
two PG functions, and point a screen at the wizard.

### Contact — today

- Route: `src/app/[lang]/(core)/crm/contact/contactimport/page.tsx` → `<ImportPageConfig gridCode="CONTACT" />`
- Grid: `page-components/crm/contact/contact/index-page.tsx` sets `enableImport: true` **and**
  `importPath: "crm/contact/contactimport"` — the Import button on the Contacts grid works.
- Menu: **already seeded globally.** `Pss2.0_Global_Menus_List.sql:278` —
  `_seed_child_menu('Contact Import','CONTACTIMPORT','CRM_CONTACT','CRM','crm/contact/contactimport','solar:import-bold',5)`,
  with the full capability set (`READ, CREATE, MODIFY, DELETE, EXPORT, IMPORT, TOGGLE, ISMENURENDER`)
  granted to BUSINESSADMIN and ADMINISTRATOR by `_seed_menu_caps_full`. The URL matches the real
  route. Nothing to seed here.
- Capability: `ImportPageConfig` calls `useAccessCapability({ menuCode: gridCode })` — it passes the
  **grid** code as the **menu** code. See G2: those are not the same string for Contact.
- Functions: `sql-scripts-dyanmic/ContactImport-fn-validate.sql`, `-fn-execute.sql`,
  `-fn-get-staging-data.sql`.
- Duplicate detection already exists as `DuplicateContact-fn-detect.sql` / `-fn-merge.sql`.

### Donation — today

- Route: `src/app/[lang]/(core)/crm/donation/bulkdonation/page.tsx` → `BulkDonationPageConfig` →
  `<ImportPageConfig gridCode="BULKDONATION" />` — same generic wizard, different grid code.
- Registration: `sql-scripts-dyanmic/BulkDonationImport-seed.sql` — definition (`BULKDONATION`,
  EntityType `GlobalDonation`, target `fund.GlobalDonations`, `HasChildren = FALSE`,
  `import.validate_bulk_donation_data` / `import.execute_bulk_donation_import`, 10 MB / 10 000 rows)
  + 9 field templates.
- Functions: `BulkDonationImport-fn-validate.sql`, `-fn-execute.sql`.
- Menu: **already seeded globally and correctly.** `Pss2.0_Global_Menus_List.sql:300` —
  `_seed_child_menu('Bulk Upload','BULKDONATION','CRM_DONATION','CRM','crm/donation/bulkdonation','solar:upload-bold',9)`,
  full capabilities including `IMPORT`. The URL matches the route.
  The older `BulkDonation-Grid-seed.sql` (`MenuUrl = 'donation/bulkprocessing/bulkdonation'`, parent
  `BULKPROCESSING`) is **superseded** — the global seed opens with a bare
  `delete from auth."Menus"` and rebuilds the whole hierarchy, so whatever that per-screen script
  inserted is gone. It should be marked stale, not "fixed".
- Capability lookup works here **by coincidence**: grid code and menu code are both the literal
  string `BULKDONATION`.

---

## 2. Gaps — these are the actual work

### G1 — Contact import has **no registration seed** (blocking on any fresh environment)

There is no `ContactImport-seed.sql` anywhere in the repo. `BULKDONATION` has one; `CONTACT` does
not. The rows in `import.ImportGridDefinitions` / `ImportGridFields` for `CONTACT` exist only in
whichever database they were hand-inserted into. On a fresh DEV/UAT database or a new tenant, the
Contacts Import button opens a wizard that cannot resolve its grid.

This is the single highest-priority item. It is also the one most likely to be missed, because it
works on the developer machine.

### G2 — The import wrapper checks the **grid** code against the **menu** table (Contact is denied)

`ImportPageConfig` (`pages/shared/import/index.tsx:26`) does:

```ts
const { capabilities, isReady, isLoading } = useAccessCapability({ menuCode: gridCode });
...
if (!capabilities.canImport && !capabilities.canRead) return <DefaultAccessDenied />;
```

`useAccessCapability` (`hooks/useInitialRendering/useCapability.ts:78`) filters the user's capability
rows with `itemMenuCode === menuCode`. An unknown menu code is **not** permissive — the filter
returns nothing, every flag stays `false`, `isReady` is `true`, and the wrapper renders
`DefaultAccessDenied`. Deny-by-default, which is the correct security posture and exactly why this
mismatch is fatal rather than cosmetic.

The contact route passes `gridCode="CONTACT"` (`index-page.tsx:28`). In the global seed there is no
menu with code `CONTACT` — the contact menus are `CRM_CONTACT` (parent), `ALLCONTACTS` (list) and
`CONTACTIMPORT` (the import screen itself). So on a global-seeded database **Contact Import renders
Access Denied for every user, including BUSINESSADMIN**, and the `IMPORT` capability that was
correctly granted on `CONTACTIMPORT` is never consulted.

Two things make this easy to miss:

- Donation is unaffected only because `BULKDONATION` happens to be both the grid code and the menu
  code. The bug is latent in the shared wrapper, not specific to Contact.
- The legacy per-screen `Contact-sqlscripts.sql:22` seeds `('All Contacts','CONTACT')`. A database
  where that script ran *after* the global seed has a `CONTACT` menu and the screen appears to work.
  Which seed ran last decides the behaviour — that is the definition of an environment-dependent
  defect, and it is why this must not be diagnosed from a developer machine.

**Related, same root cause, out of scope for this plan but worth recording:** `global_search.sql:70`
joins `auth."Menus" m ON 'CONTACT' = m."MenuCode"` to permission-check contact results. Under the
global seed that join matches nothing, so contacts silently drop out of global search. Same
hardcoded-legacy-menu-code assumption, different consumer.

### G3 — ~120 grids show an Import button that goes nowhere

`enableImport: true` was copied into roughly 120 `data-table.tsx` / `index-page.tsx` configs as part
of the boilerplate. Only **one** file in the whole frontend sets `importPath` (Contacts). Both
toolbars fall back to `` `/${lang}/import/${gridCode}` ``, and there is **no `import` segment under
`app/[lang]/(core)/`** — the segments are accesscontrol, billing, crm, general, no-access,
organization, reportaudit, setting. So every one of those buttons is a 404 for a user with the
`IMPORT` capability. Global Donations (`globaldonation/index-page.tsx:23`) is one of them.

### G4 — Dead legacy donation-import screen

`presentation/pages/crm/donation/importdonation.tsx` (+ `importdonations/importdonation-form.tsx`,
`shared/importdonation-schemas.ts`) is a PSS 1.0-style screen: parses XLSX in the browser, posts
`CREATE_PAYMENT_MODE_UPLOAD_MUTATION`, guards on a `IMPORTDONATION` menu code. It is exported from
`pages/crm/donation/index.ts` but **has no route** — nothing renders it. It bypasses the framework
entirely (no staging, no server-side validation, no session, no progress, no audit).

### G5 — Imported donations are financially incomplete

`BulkDonationImport-fn-execute.sql` inserts into `fund."GlobalDonations"` only. It does **not**:

- create a `GlobalDonationDistribution` row → an imported donation is invisible to every
  purpose/campaign/program funding rollup, which is computed as
  `Σ GlobalDonationDistribution.AllocatedAmount` by org-unit node;
- allocate a receipt number through NumberSequence — `ReceiptNumber` is whatever the spreadsheet
  says, nullable, and unchecked for collision with the generated series;
- set `BaseCurrencyId` from the company's base currency — it hardcodes
  `BaseCurrencyId = CurrencyId, ExchangeRate = 1.0`, which is silently wrong the moment a tenant
  imports a foreign-currency donation.

A donation import that lands money in the ledger but not in the attribution chain will be read as
"the dashboards are broken" the first time it is used at scale.

---

## 3. Plan

### Phase 1 — Make both imports reproducible (backend/SQL)

1. **`ContactImport-seed.sql`** (new, `sql-scripts-dyanmic/`), mirroring `BulkDonationImport-seed.sql`
   1:1 in shape — idempotent, `WHERE NOT EXISTS` on every INSERT, PostgreSQL syntax (`NOW()`,
   double-quoted identifiers, `TRUE`/`FALSE`):
   - one `ImportGridDefinitions` row: `GridCode = 'CONTACT'` (must equal the string the route passes),
     `EntityType = 'Contact'`, `TargetSchema = 'corg'`, `TargetTable = 'Contacts'`,
     **`HasChildren = TRUE`**, `ValidationProcedure = 'import.validate_contact_data'`,
     `ImportProcedure = 'import.execute_contact_import'`, `DisplayOrder = 1`;
   - `ImportGridFields` rows for every column the existing validate/execute functions actually read —
     derive the list from `ContactImport-fn-validate.sql` / `-fn-execute.sql`, do not invent it;
   - `ImportGridChildRelations` rows for emails, phones and addresses, with the child columns marked
     via `ChildEntityType` / `ChildFieldType` / `IsPrimaryChildField` on the field rows (the pattern
     the field entity already supports).
   - Reconcile the two copies of the functions first: `sql-scripts-dyanmic/ContactImport-fn-*.sql`
     and `DatabaseScripts/Functions/import/{validate_contact_data,execute_contact_import}.sql` define
     the **same function names with the same signature** — the `sql-scripts-dyanmic` pair is the newer
     one (it carries grid-code and child-count handling the other lacks). Treat `sql-scripts-dyanmic`
     as authoritative, apply it last, and delete or clearly mark the `DatabaseScripts` copies as
     superseded so nobody re-applies the old body over the new one.

2. **No menu or capability work.** `Pss2.0_Global_Menus_List.sql` already seeds `CONTACTIMPORT` and
   `BULKDONATION` at the correct URLs with `IMPORT` granted to BUSINESSADMIN and ADMINISTRATOR. Add a
   header comment to `BulkDonation-Grid-seed.sql` marking it **superseded by the global seed — do not
   apply**, so nobody re-inserts the stale `donation/bulkprocessing/bulkdonation` URL. That is a
   comment only; it changes no data, which keeps this session's no-menu-data-change rule intact.

### Phase 2 — Surface import on the respective screens (frontend)

3. **Decouple the RBAC menu code from the grid code in `ImportPageConfig`** — fixes G2, and it is the
   first thing to do because until it lands, Contact Import cannot be tested at all.

   ```ts
   interface ImportPageProps {
     gridCode: string;   // keys import.ImportGridDefinitions — the PG functions resolve off this
     menuCode?: string;  // keys auth.Menus for the RBAC check; defaults to gridCode
   }
   export function ImportPageConfig({ gridCode, menuCode }: ImportPageProps) {
     const { capabilities, isReady, isLoading } = useAccessCapability({ menuCode: menuCode ?? gridCode });
   ```

   Then `crm/contact/contactimport/page.tsx` passes
   `<ImportPageConfig gridCode="CONTACT" menuCode="CONTACTIMPORT" />`. Donation needs no change — the
   default preserves its current behaviour.

   **Recommendation, not an option list:** keep `GridCode = 'CONTACT'` in the registry and change the
   *capability* lookup, not the other way round. Renaming the grid code to `CONTACTIMPORT` would mean
   editing the `ImportGridDefinitions` row, both PG functions, the route and any staging data keyed on
   it — a wider blast radius to fix a narrower problem. The two identifiers address different tables
   (`import.ImportGridDefinitions` vs `auth.Menus`); conflating them was the defect, so the fix is to
   separate them, not to force them to agree.

   Also delete the stale comment block at `pages/shared/import/index.tsx:23-25` ("Backend needs a menu
   entry with menuCode IMPORT… use the gridCode as menuCode fallback") — it documents the assumption
   that caused this, and the menus it says are missing now exist.

4. **Donations screen → Bulk Donation wizard.** In
   `page-components/crm/donation/globaldonation/index-page.tsx`, add
   `importPath: "crm/donation/bulkdonation"` next to the existing `enableImport: true`. The Import
   button on the Global Donations grid then opens the same wizard the menu opens. No new component,
   no new route.

5. **Stop rendering Import where it cannot work.** In the three toolbars
   (`data-tables/advanced/data-table-general-toolbar.tsx`,
   `data-tables/flow/data-table-general-toolbar.tsx`,
   `data-tables/flow/data-table-header-toolbar.tsx`), change the gate from
   `tableConfig?.enableImport && capability.canImport` to additionally require `tableConfig?.importPath`,
   and delete the `` `/${lang}/import/${gridCode}` `` fallback in all three navigation handlers plus
   `data-table-general-options/data-table-import-option.tsx` (both copies).

   **Recommendation, not an option list:** do this rather than adding a catch-all
   `app/[lang]/(core)/import/[gridCode]/page.tsx`. A catch-all would turn 120 dead buttons into 120
   live buttons for grids that have no `ImportGridDefinition`, no validate function and no execute
   function — the user reaches a wizard that fails at step one, which is worse than no button. The
   presence of `importPath` is an explicit, reviewable statement that this grid has a real import
   behind it. It is three one-line changes and it makes the button truthful everywhere at once.
   Reverting the ~120 stray `enableImport: true` flags is then optional cleanup, not a prerequisite.

6. **Retire the legacy donation-import screen.** Delete
   `presentation/pages/crm/donation/importdonation.tsx`, its export line in
   `presentation/pages/crm/donation/index.ts`, `page-components/crm/donation/importdonations/`, and
   `page-components/crm/donation/shared/importdonation-schemas.ts`. Confirm
   `CREATE_PAYMENT_MODE_UPLOAD_MUTATION` has no other consumer before removing it; if the
   `IMPORTDONATION` menu code exists in `auth.Menus`, deactivate it in the same corrective script as
   item 2 (`IsActive = FALSE` / `ISMENURENDER = FALSE`, not a delete).

### Phase 3 — Make imported donations financially correct

7. Extend `BulkDonationImport-fn-execute.sql` and the seed's field list:
   - add a `donation_purpose_code` field (lookup → `sett.DonationPurposes`) and insert a matching
     `fund.GlobalDonationDistribution` row per donation, allocating the full amount to the resolved
     purpose's org-unit node; make the field required unless a tenant-level default purpose is
     configured, because a donation with no distribution is a donation that no dashboard will count;
   - resolve `BaseCurrencyId` and `ExchangeRate` from the company's base currency instead of
     hardcoding them, and compute `BaseCurrencyAmount` from the rate;
   - route `ReceiptNumber`: if the file supplies one, validate it for uniqueness within the company
     and reject the row on collision; if it does not, either leave it null or allocate through
     NumberSequence inside the same transaction — decide once and state it in the seed header. Do not
     leave a free-text receipt number colliding with the generated series.
   - Run all of this inside the existing execute-function transaction so a failed distribution rolls
     back its donation. Note the `Npgsql` retrying-execution-strategy rule if any of this is lifted
     into C#.

### Phase 4 — Verification (manual, by the user, no environment probing here)

- **First, and before anything else:** Contacts grid → Import → the wizard renders. If it still shows
  "Access Denied", the G2 fix did not land or the user has not re-logged in. Nothing downstream is
  testable until this passes.
- Fresh-DB run of `ContactImport-seed.sql` → Contacts grid → Import → template download lists the
  seeded fields and the child (email/phone/address) columns.
- A deliberately dirty file: bad email, missing required column, unresolvable country, duplicate
  contact → all four surface at the **validation** step with row numbers, none reach `corg.Contacts`.
- Donations grid → Import → same wizard as the menu → 10-row file → verify one
  `GlobalDonationDistribution` row per donation and the purpose/program rollups move by exactly the
  imported total.
- Re-run the same file → duplicate handling behaves as specified (reject vs warn), not silently
  double-posted.

---

## 4. Non-negotiables carried into this work

- **Validation is server-side.** The wizard's client-side checks are a convenience only; every rule
  that protects data (required, lookup resolution, duplicate, currency, amount sign, date range,
  receipt uniqueness) must be enforced in the validate function, because the GraphQL mutation can be
  called without the wizard.
- **Idempotent seeds**, PostgreSQL syntax, `WHERE NOT EXISTS` guards — this repo is Postgres, not SQL
  Server.
- No EF migration is required for any of the above (no schema change). If Phase 3 turns out to need a
  column, the **user** creates the migration.
- **No menu or capability DATA changes at all.** `Pss2.0_Global_Menus_List.sql` is the single
  authoritative source for the menu hierarchy and it already has what this work needs. Per-screen
  menu seeds (`Contact-sqlscripts.sql`, `BulkDonation-Grid-seed.sql`) are legacy and must not be
  re-applied — the global seed opens with a bare `delete from auth."Menus"`, so re-running one of them
  afterwards silently reintroduces menu codes the app no longer expects. That drift is the direct
  cause of G2.

## 5. Open decisions for the user

1. **Contact duplicate policy on import:** reject the row, warn and import anyway, or route to the
   existing `DuplicateContact-fn-detect` merge queue. The detect/merge functions already exist, so
   the third option is cheap — but it changes what "success" means in the results step.
2. **Donation purpose on import:** hard-require `donation_purpose_code` per row, or allow a
   tenant-level default purpose for files that do not carry one.
3. **Receipt numbering:** file-supplied only, generated only, or file-with-fallback.
4. Whether to sweep the ~120 stray `enableImport: true` flags now or leave them inert behind the
   `importPath` gate.
5. Whether to fix the `global_search.sql` hardcoded `'CONTACT'` menu-code join in this pass or track
   it as its own item. It is the same root cause but a different feature, and it is a one-line change
   inside a PG function the user would have to re-apply.
