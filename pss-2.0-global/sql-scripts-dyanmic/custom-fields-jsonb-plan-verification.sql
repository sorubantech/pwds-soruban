-- ============================================================================
-- Custom fields: QUERY PLAN VERIFICATION  (read-only, safe to re-run)
-- ============================================================================
-- Run AFTER the text -> jsonb migration and AFTER the index DDL emitted by
-- CustomFieldIndexPlanner has been applied.
--
-- Building an index and USING an index are different events. PostgreSQL matches
-- expression indexes STRUCTURALLY: an index over
--     jsonb_extract_path_text("CustomFields", 'flagIcon')
-- is not a candidate for a predicate written as
--     "CustomFields" ->> 'flagIcon'
-- even though the two are semantically identical. It is not a candidate for
-- lower(...) either. There is no error and no warning when this happens — the
-- index is simply built, maintained on every write, and never chosen. The only
-- way to know is to read the plan, which is what this script is for.
--
-- Nothing here modifies data. EXPLAIN ANALYZE does EXECUTE the statement, but
-- all three are SELECTs.
--
-- BEFORE YOU BELIEVE ANY OF IT: run ANALYZE. A table that has just been
-- rewritten by ALTER COLUMN ... TYPE has stale statistics, and stale statistics
-- produce a Seq Scan that has nothing to do with the index.
-- ============================================================================

ANALYZE corg."Contacts";

-- Substitute your own values before running:
--   :companyid   an existing tenant id with a meaningful row count
--   'flagIcon'   a key actually declared filterable for CONTACT / CONTACTS, i.e.
--                a sett."Fields"."FieldKey" whose sett."GridFields" row has
--                "ParentObject" = 'customFields' AND "IsFilterable" = true.
--                A key that is NOT declared has no index and MUST Seq Scan —
--                that is correct behaviour, not a failure of this test.
-- The index names below assume that key; the planner slugs them lower-case, so
-- key 'flagIcon' yields ix_contacts_cf_flagicon / ix_contacts_cfl_flagicon.


-- ---------------------------------------------------------------------------
-- 0. Confirm the indexes exist at all, and see their real names.
--    If a name below differs from what the probes expect, the key slug differs;
--    read the name from here rather than editing the planner.
-- ---------------------------------------------------------------------------
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'corg'
  AND tablename  = 'Contacts'
  AND indexdef ILIKE '%CustomFields%'
ORDER BY indexname;


-- ---------------------------------------------------------------------------
-- 1. FILTER — one declared key, equality, case-insensitive.
--
-- This mirrors what GridQueryBuilderHelper.BuildCustomFieldConditionCore emits
-- for { field: "CustomFields.flagIcon", operator: "equals", value: "IN" }:
-- lower() on both sides, plus the != null guard, plus the tenancy predicate.
--
--   GOOD    Index Scan using "ix_contacts_cfl_flagicon"
--           (or Bitmap Index Scan on the same, for a low-selectivity value)
--           Index Cond: (("CompanyId" = N) AND (lower(jsonb_extract_path_text(...)) = 'in'))
--           Buffers: shared hit <a few dozen>
--
--   BAD     Seq Scan on "Contacts"
--           Filter: ...
--           Rows Removed by Filter: <most of the table>
--           Buffers: shared hit/read <thousands>
--           -> the lower() index is missing, or its expression does not match
--              the emitted one character for character.
-- ---------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT c."ContactId", c."ContactCode", c."CustomFields"
FROM corg."Contacts" c
WHERE c."CompanyId" = :companyid
  AND c."IsDeleted" = false
  AND jsonb_extract_path_text(c."CustomFields", 'flagIcon') IS NOT NULL
  AND lower(jsonb_extract_path_text(c."CustomFields", 'flagIcon')) = lower('IN');


-- ---------------------------------------------------------------------------
-- 2. SORT — ORDER BY one declared key.
--
-- ApplySorting emits the RAW extraction, not lower(), because collation order
-- must be the user's. That is why each declared key gets two indexes: this probe
-- exercises the non-lower one, and it is the one that fails silently if someone
-- decides two indexes per key is extravagant and drops it.
--
--   GOOD    Index Scan using "ix_contacts_cf_flagicon"
--           and NO "Sort" node anywhere in the plan — the index supplies the
--           ordering. Buffers proportional to LIMIT, not to table size.
--
--   BAD     any plan containing
--               Sort  Sort Method: external merge  Disk: <n>kB
--           below a Seq Scan. The whole table was read, extracted per row and
--           sorted on disk to return 25 rows. This is the single most expensive
--           failure of the three, because it costs the full table on EVERY page
--           of the grid, not just the first.
-- ---------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT c."ContactId", c."ContactCode"
FROM corg."Contacts" c
WHERE c."CompanyId" = :companyid
  AND c."IsDeleted" = false
ORDER BY jsonb_extract_path_text(c."CustomFields", 'flagIcon')
LIMIT 25;


-- ---------------------------------------------------------------------------
-- 3. GLOBAL SEARCH — prefix match across every declared key.
--
-- BuildCustomFieldSearchPredicate emits StartsWith, not Contains, and that is
-- load-bearing: LIKE 'term%' can use a B-tree, LIKE '%term%' cannot use one at
-- all. It ORs one clause per declared key, so with two declared keys the good
-- plan is a BitmapOr over the per-key lower() indexes.
--
-- text_pattern_ops is the other half. Under any non-C collation a DEFAULT
-- B-tree cannot answer LIKE 'term%' — the operator class is what makes the
-- prefix range provable — which is why the planner emits it on the lower()
-- index and why that index serves both this probe and probe 1.
--
--   GOOD    Bitmap Heap Scan on "Contacts"
--             -> BitmapOr
--                  -> Bitmap Index Scan on "ix_contacts_cfl_flagicon"
--                  -> Bitmap Index Scan on "ix_contacts_cfl_<otherkey>"
--
--   BAD     Seq Scan with a Filter containing both ~~ clauses.
--           If probe 1 was good and this one is not, the cause is almost always
--           the operator class: the index was created without text_pattern_ops,
--           so it serves equality and not prefix.
--
-- Replace 'otherKey' with a second declared key, or delete that OR branch if the
-- entity declares only one.
-- ---------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT c."ContactId", c."ContactCode"
FROM corg."Contacts" c
WHERE c."CompanyId" = :companyid
  AND c."IsDeleted" = false
  AND (
        (jsonb_extract_path_text(c."CustomFields", 'flagIcon') IS NOT NULL
         AND lower(jsonb_extract_path_text(c."CustomFields", 'flagIcon')) LIKE 'in%')
     OR (jsonb_extract_path_text(c."CustomFields", 'otherKey') IS NOT NULL
         AND lower(jsonb_extract_path_text(c."CustomFields", 'otherKey')) LIKE 'in%')
      );


-- ---------------------------------------------------------------------------
-- 4. Optional — the GIN containment index.
--
-- ix_contacts_customfields_gin (jsonb_path_ops) is not used by any of the three
-- probes above; the grid never issues a containment query. It is there for
-- ad-hoc operational queries and for future key-existence probes. Included so
-- that "the GIN index never appears in a plan" is understood as expected rather
-- than investigated as a fault.
--
--   GOOD    Bitmap Index Scan on "ix_contacts_customfields_gin"
--           Index Cond: ("CustomFields" @> '{"flagIcon": "IN"}'::jsonb)
--
-- Note jsonb_path_ops answers containment (@>) but NOT key existence (?). That
-- is the documented trade for its smaller size, and this codebase issues neither
-- from application code.
-- ---------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT c."ContactId"
FROM corg."Contacts" c
WHERE c."CustomFields" @> '{"flagIcon": "IN"}'::jsonb;


-- ---------------------------------------------------------------------------
-- READING THE RESULT
--
-- One line decides it, in every probe: the node directly above the table.
--   Index Scan / Index Only Scan / Bitmap Index Scan naming one of the
--   ix_contacts_cf_* / ix_contacts_cfl_* indexes  -> the index is being used.
--   Seq Scan                                      -> it is not.
--
-- Two honest caveats before declaring a Seq Scan a bug:
--
--   * On a SMALL table a Seq Scan is the correct plan and the planner is right.
--     Verify on data of production scale, or force the question temporarily with
--     SET enable_seqscan = off; — which proves the index is USABLE, not that it
--     is chosen. Reset it afterwards.
--   * A predicate matching most of the table is also correctly a Seq Scan.
--     Choose a selective value.
--
-- BUFFERS is the number that does not lie about cost. A good filter plan touches
-- tens of shared buffers; the Seq Scan equivalent touches thousands, and does so
-- per keystroke, per user, on every grid that carries the column.
-- ---------------------------------------------------------------------------
