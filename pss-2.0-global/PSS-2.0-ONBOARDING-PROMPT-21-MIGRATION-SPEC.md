# PROMPT-21 (§3.7) — Migration spec, user-owned

Backend code for lead ownership, assignment and account-manager continuity is complete and compiles
against the entity model below. **The migration has not been created.** Per standing policy the EF
migration is authored, run and committed by you, not by me. This file is the spec to author it from.

```
cd PSS_2.0_Backend/PeopleServe/Services/Base
dotnet build                                    # prove it compiles first
dotnet ef migrations add Add_LeadAssignment_And_AccountManager -p Base.Infrastructure -s Base.API
dotnet ef database update -p Base.Infrastructure -s Base.API
```

The EF configurations already encode every column type and index below, so a scaffolded migration
should match this spec without hand-editing. **Diff it against this list before applying.**

Everything here is **additive and nullable** — no existing row changes, no column is dropped, no
constraint is tightened on data that already exists. The migration is safe to apply to a populated
database, and safe to apply *before* the seed script.

---

## 1. `ops.LeadAssignments` — new table

One row per **ownership episode**: who was told to look after this prospect, by whom, and when that
stopped being true. `ops.Leads.OwnerUserId` stays the fast answer to "who owns it right now"; this
table is the trail behind that answer. `AssignLeadHandler` is the only writer and writes both in the
same `SaveChangesAsync`, so they cannot drift.

| Column | Type | Null | Why |
|---|---|---|---|
| `LeadAssignmentId` | `int` PK, identity always | no | — |
| `LeadId` | `int` FK → `ops."Leads"`, `ON DELETE RESTRICT` | no | An episode without a lead is meaningless. Restrict because a lead is soft-deleted, never removed, and its ownership history outlives any UI that hides it. |
| `AssignedToUserId` | `int` | no | The platform user who owned the lead for this episode. |
| `AssignedByUserId` | `int` | no | Who performed the assignment — stamped from the JWT `UserId` claim in the mutation layer, **never** from the request body. |
| `AssignedOn` | `timestamptz` | no | UTC instant the episode opened. |
| `UnassignedOn` | `timestamptz` | **yes** | UTC instant it closed. **NULL ⇒ this is the currently open episode.** |
| `Note` | `varchar(500)` | yes | Optional hand-over note ("covering while Sara is on leave"). |
| + `Entity` audit columns | | | `CreatedBy/CreatedDate/ModifiedBy/ModifiedDate/IsActive/IsDeleted` |

```sql
CREATE INDEX "IX_LeadAssignments_LeadId_UnassignedOn"
  ON ops."LeadAssignments" ("LeadId", "UnassignedOn");

CREATE INDEX "IX_LeadAssignments_AssignedToUserId_UnassignedOn"
  ON ops."LeadAssignments" ("AssignedToUserId", "UnassignedOn");
```

Those two are the only access paths that matter: "the open episode for this lead" (the detail
panel's history) and "the open episodes for this user" (the My Leads count).

**`AssignedToUserId` and `AssignedByUserId` are plain ints with NO foreign key**, deliberately.
`auth.Users` is tenant-scoped and platform users are resolved by claim, so a hard constraint here
would fight the tenant query filter. `AssignLeadHandler` verifies the target really is live platform
staff (`PlatformUserHelper.IsPlatformStaffAsync`) before it writes. This mirrors the existing
decision on `Lead.OwnerUserId` — do not "fix" one without the other.

**No partial unique index on `(LeadId) WHERE "UnassignedOn" IS NULL`, also deliberately.** The
at-most-one-open-episode invariant is enforced in code (close the open row, then insert the new one,
in one transaction). A DB-level constraint would make the backfill script below un-runnable against
any environment whose legacy data is imperfect — and imperfect legacy data is exactly what the
backfill exists to repair.

## 2. `ops.Leads` — 2 new columns

| Column | Type | Null | Why |
|---|---|---|---|
| `AssignedByUserId` | `int` | yes | Denormalised from the open episode so the grid's "Assigned By" column needs no join. |
| `AssignedOn` | `timestamptz` | yes | Denormalised likewise; drives the "assigned 6 days ago" age column. |

`OwnerUserId` and its index `IX_Leads_OwnerUserId` already exist from P-05 — EF will not re-emit
them. If the scaffolded migration *does* try to create that index, the database is behind; check
before applying.

Both columns are nullable because **a lead is born unowned**. `CreateLeadHandler` nulls all three
explicitly and `LeadRequestDto` no longer carries `OwnerUserId` at all, so ordinary Create/Update
cannot set ownership — `AssignLeadCommand` is the only door, which is what makes the history
complete.

## 3. `app.Companies` — 1 new column

| Column | Type | Null | Why |
|---|---|---|---|
| `AccountManagerUserId` | `int` | yes | The platform user who looks after this tenant. |

This is the **account-manager continuity** column — the business ask in one field: *"that particular
staff will communicate and maintain that lead **and onboarding** — everything should be that
person."* Copied from `Lead.OwnerUserId` by `ProvisionTenantHandler.StampLeadConversionAsync` at
conversion, and kept in step afterwards by `AssignLeadHandler` (a late owner change on a converted
lead follows across to the company).

Nullable because tenants provisioned before this existed have no account manager, and because a
tenant can be created without a lead at all. Plain int, no FK — same tenant-filter reasoning as §1.

Note the asymmetry, which is intentional: provisioning **never overwrites** a non-null
`AccountManagerUserId` (a resumed run must not drag a re-pointed tenant back to whoever originally
sold it), whereas an explicit reassignment **does**.

## 4. `ops.TenantProvisioningRuns` — 1 new column

| Column | Type | Null | Why |
|---|---|---|---|
| `OwnerUserId` | `int` | yes | The lead's owner at the moment the run was first created. |

Distinct from the existing `InitiatedByUserId`, and routinely a different person: an implementation
engineer presses the button on behalf of the salesperson who owns the relationship. Captured on
**first create only**, like `InitiatedByUserId`, so a run resumed months later still reports who
owned the deal when it was provisioned rather than whoever holds the lead today.

---

## After the migration

1. Apply `sql-scripts-dyanmic/ops-lead-assign-capability-seed.sql` — the `PLATFORM_LEAD_ASSIGN`
   capability, its grants to `PLATFORM_ADMIN` + `SUPERADMIN`, and the `PLATFORM_LEAD_ASSIGNED` email
   template. Until it runs, **nobody can reassign a lead**; self-claim of an unowned lead still works
   (it only needs `PLATFORM_LEAD_VIEW`).
2. Optionally apply `sql-scripts-dyanmic/lead-assignment-history-backfill.sql` — synthesises one open
   episode for every lead that already has an `OwnerUserId` but no `LeadAssignments` row. Without it
   those leads show a current owner and an empty history, which is accurate (we genuinely do not know
   who assigned them) but reads as a bug. Read that file's header before running it.
3. Re-check who holds `PLATFORM_LEAD_ASSIGN`. Per §⑨ Q1 the seed does **not** grant it to
   `PLATFORM_SALES` — a salesperson can claim anything unowned but cannot take an owned lead off a
   colleague. If that is the wrong call for your team, add one `VALUES` row to section 2 of the seed
   and re-run it; the script is idempotent.
