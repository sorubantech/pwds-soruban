-- =====================================================================================
-- Custom-field governance AUDIT — run BEFORE billing-custom-field-governance-quota-seed.sql
-- -------------------------------------------------------------------------------------
-- READ ONLY. No BEGIN/COMMIT, no writes. Safe to run against production.
--
-- Answers the only question that matters before seeding a ceiling: is any tenant ALREADY over
-- the number we are about to impose on their plan?
--
-- WHAT ENFORCEMENT ACTUALLY DOES WHEN A TENANT IS OVER A NEWLY LOWERED CEILING ------------
-- Read from the guard paths, not assumed:
--
--   • NOTHING happens to existing data. There is no sweep, no reconciliation job, no
--     deactivation pass. Fields already defined stay defined, stay visible, stay filterable,
--     and their data keeps rendering. The ceiling is checked ONLY on the write paths.
--
--   • CreateCustomFieldHandler counts the tenant's non-deleted FieldSource='Custom' rows and
--     refuses if that count is already >= the resolved MaxFields, throwing BadRequestException
--     (HTTP 400): "The limit of {n} custom fields has been reached. Delete a custom field that
--     is no longer in use, or raise the limit on the plan." So an over-ceiling tenant is frozen
--     at their current count until they delete something or the plan is raised. They are not
--     told they are over until they try.
--
--   • BulkUpdateGridConfigurationHandler applies the filterable budget PER GRID, after the
--     upserts are staged but before SaveChanges, and rejects the WHOLE PAYLOAD with a
--     BadRequestException if the resulting grid would exceed it. This is the sharper edge: a
--     tenant already over the filterable budget on one grid cannot save ANY change to that
--     grid's configuration — including a change that would reduce the count, and including
--     edits that have nothing to do with filtering — because the guard evaluates the resulting
--     state, not the delta. They must un-tick enough Filterable boxes in the same payload to
--     come back under, in one save.
--
--   • Both are 400s from the custom-field layer, NOT the billing 402 PLAN_QUOTA_EXCEEDED /
--     403 PLAN_FEATURE_NOT_ENTITLED channel, so no upgrade interstitial fires. The tenant sees
--     a plain validation error on the form.
--
--   It does NOT degrade gracefully in any automatic sense — but it also destroys nothing.
--   The correct reading is: lowering a ceiling below a tenant's current usage does not break
--   them, it locks them. That is survivable for CUSTOM_FIELDS and annoying for
--   CUSTOM_FIELDS_FILTERABLE. Query 2 below is the one to look at hardest.
-- =====================================================================================


-- ─────────────────────────────────────────────────────────────────────────────────────
-- 1. CUSTOM_FIELDS — definitions per company, and per entity within the company.
--
--    NOTE ON "PER ENTITY": enforcement is currently coarser than the option name
--    MaxFieldsPerEntity suggests — CreateCustomFieldHandler counts the tenant's custom fields
--    ACROSS ALL ENTITIES and compares that total to the ceiling. So the column that decides
--    pass/fail is CompanyTotal. The per-grid breakdown is included because it is what an
--    operator needs in order to advise a tenant on what to delete, and because if the count is
--    ever narrowed to per-entity this is the number that will start mattering.
--
--    sett."Fields" has no entity column of its own; a custom field reaches an entity through
--    sett."GridFields" -> sett."Grids". A field attached to no grid still counts against the
--    ceiling, and shows here as entity '(unattached)'.
-- ─────────────────────────────────────────────────────────────────────────────────────
WITH custom_fields AS (
    SELECT f."FieldId", f."CompanyId"
    FROM sett."Fields" f
    WHERE f."FieldSource" = 'Custom'
      AND COALESCE(f."IsDeleted", false) = false
),
-- One row per (company, entity, field). DISTINCT because a field attached to the same grid
-- twice must not be double counted.
field_entity AS (
    SELECT DISTINCT
           cf."CompanyId",
           cf."FieldId",
           COALESCE(g."GridCode", '(unattached)') AS "EntityGridCode"
    FROM custom_fields cf
    LEFT JOIN sett."GridFields" gf
           ON gf."FieldId" = cf."FieldId"
          AND COALESCE(gf."IsDeleted", false) = false
    LEFT JOIN sett."Grids" g
           ON g."GridId" = gf."GridId"
          AND COALESCE(g."IsDeleted", false) = false
),
-- The number enforcement actually compares against: DISTINCT fields, not summed per entity —
-- a field on three grids is still one definition.
company_total AS (
    SELECT "CompanyId", COUNT(DISTINCT "FieldId") AS "CompanyTotal"
    FROM field_entity
    GROUP BY "CompanyId"
),
entity_total AS (
    SELECT "CompanyId", "EntityGridCode", COUNT(DISTINCT "FieldId") AS "FieldsOnEntity"
    FROM field_entity
    GROUP BY "CompanyId", "EntityGridCode"
)
SELECT c."CompanyId",
       c."CompanyCode",
       c."CompanyName",
       COALESCE(p."PlanCode", '(no active subscription)') AS "PlanCode",
       et."EntityGridCode",
       et."FieldsOnEntity",
       ct."CompanyTotal"
FROM entity_total et
JOIN company_total ct
     ON ct."CompanyId" = et."CompanyId"
JOIN app."Companies" c
     ON c."CompanyId" = et."CompanyId"
LEFT JOIN billing."Subscriptions" s
     ON s."CompanyId" = c."CompanyId"
    AND COALESCE(s."IsDeleted", false) = false
    AND s."Status" IN ('Trial','Active','PastDue')
LEFT JOIN billing."Plans" p
     ON p."PlanId" = s."PlanId"
ORDER BY ct."CompanyTotal" DESC, c."CompanyId", et."EntityGridCode";


-- ─────────────────────────────────────────────────────────────────────────────────────
-- 2. CUSTOM_FIELDS_FILTERABLE — filterable custom columns per company PER GRID.
--
--    The ceiling is applied PER GRID, so the row that decides pass/fail is the WORST grid,
--    not the company total. Sorted worst-first.
--
--    ParentObject = 'customFields' is the marker that a GridField column is backed by a custom
--    field (ICustomFieldRegistry.ParentObject). Compared case-insensitively here because the
--    guard compares OrdinalIgnoreCase and hand-seeded rows may not match the exact casing.
-- ─────────────────────────────────────────────────────────────────────────────────────
SELECT c."CompanyId",
       c."CompanyCode",
       c."CompanyName",
       COALESCE(p."PlanCode", '(no active subscription)') AS "PlanCode",
       g."GridCode",
       COUNT(*) AS "FilterableCustomFields"
FROM sett."GridFields" gf
JOIN app."Companies" c
     ON c."CompanyId" = gf."CompanyId"
JOIN sett."Grids" g
     ON g."GridId" = gf."GridId"
    AND COALESCE(g."IsDeleted", false) = false
LEFT JOIN billing."Subscriptions" s
     ON s."CompanyId" = c."CompanyId"
    AND COALESCE(s."IsDeleted", false) = false
    AND s."Status" IN ('Trial','Active','PastDue')
LEFT JOIN billing."Plans" p
     ON p."PlanId" = s."PlanId"
WHERE COALESCE(gf."IsDeleted", false) = false
  AND COALESCE(gf."IsActive", true) = true
  AND COALESCE(gf."IsFilterable", false) = true
  AND LOWER(gf."ParentObject") = 'customfields'
GROUP BY c."CompanyId", c."CompanyCode", c."CompanyName", p."PlanCode", g."GridCode"
ORDER BY "FilterableCustomFields" DESC, c."CompanyId", g."GridCode";


-- ─────────────────────────────────────────────────────────────────────────────────────
-- 3. THE ACCEPTANCE CHECK — who would be over the PROPOSED ceilings on seed day.
--
--    Any row returned is a tenant that will be LOCKED (see the header) the moment the seed
--    runs. Expect zero rows; if not, either raise that plan's number in the seed file or
--    give that one company a billing.SubscriptionOverrides row before running it.
--
--    Proposed numbers are inlined here on purpose so this query stands alone and can be run
--    before the seed exists in the database. Keep them in step with the seed file if the
--    numbers change.
-- ─────────────────────────────────────────────────────────────────────────────────────
WITH proposed("PlanCode","MaxFields","MaxFilterable") AS (
    VALUES ('FREE', 10, 2),
           ('PLAN_50K', 50, 5),
           ('PLAN_100K', 150, 12),
           ('CUSTOM', 300, 25)
),
company_plan AS (
    SELECT c."CompanyId",
           c."CompanyCode",
           c."CompanyName",
           p."PlanCode"
    FROM app."Companies" c
    LEFT JOIN billing."Subscriptions" s
           ON s."CompanyId" = c."CompanyId"
          AND COALESCE(s."IsDeleted", false) = false
          AND s."Status" IN ('Trial','Active','PastDue')
    LEFT JOIN billing."Plans" p
           ON p."PlanId" = s."PlanId"
    WHERE COALESCE(c."IsDeleted", false) = false
),
field_counts AS (
    SELECT f."CompanyId", COUNT(*) AS "UsedFields"
    FROM sett."Fields" f
    WHERE f."FieldSource" = 'Custom'
      AND COALESCE(f."IsDeleted", false) = false
      AND f."CompanyId" IS NOT NULL
    GROUP BY f."CompanyId"
),
worst_grid AS (
    SELECT gf."CompanyId", MAX(cnt) AS "UsedFilterable"
    FROM (
        SELECT gf."CompanyId", gf."GridId", COUNT(*) AS cnt
        FROM sett."GridFields" gf
        WHERE COALESCE(gf."IsDeleted", false) = false
          AND COALESCE(gf."IsActive", true) = true
          AND COALESCE(gf."IsFilterable", false) = true
          AND LOWER(gf."ParentObject") = 'customfields'
          AND gf."CompanyId" IS NOT NULL
        GROUP BY gf."CompanyId", gf."GridId"
    ) gf
    GROUP BY gf."CompanyId"
)
SELECT cp."CompanyId",
       cp."CompanyCode",
       cp."CompanyName",
       COALESCE(cp."PlanCode", '(no active subscription)') AS "PlanCode",
       COALESCE(fc."UsedFields", 0)      AS "UsedFields",
       pr."MaxFields"                    AS "ProposedMaxFields",
       COALESCE(wg."UsedFilterable", 0)  AS "WorstGridFilterable",
       pr."MaxFilterable"                AS "ProposedMaxFilterable",
       CASE
         WHEN COALESCE(fc."UsedFields", 0) > pr."MaxFields"
          AND COALESCE(wg."UsedFilterable", 0) > pr."MaxFilterable" THEN 'OVER BOTH'
         WHEN COALESCE(fc."UsedFields", 0) > pr."MaxFields"          THEN 'OVER FIELDS'
         ELSE 'OVER FILTERABLE'
       END AS "Breach"
FROM company_plan cp
JOIN proposed pr ON pr."PlanCode" = cp."PlanCode"
LEFT JOIN field_counts fc ON fc."CompanyId" = cp."CompanyId"
LEFT JOIN worst_grid  wg ON wg."CompanyId" = cp."CompanyId"
WHERE COALESCE(fc."UsedFields", 0) > pr."MaxFields"
   OR COALESCE(wg."UsedFilterable", 0) > pr."MaxFilterable"
ORDER BY cp."CompanyId";
-- =====================================================================================
