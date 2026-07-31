-- ═══════════════════════════════════════════════════════════════════════════════════════════════
--  FIX — Aram tenant (CompanyId 27) BUSINESSADMIN role (RoleId 21) has ZERO RoleCapabilities.
--
--  Root cause: ProvisionTenant Step 4a (SEED_CAPABILITIES / clone) is wrapped in
--              `if (templateCompanyId is int tId)`. No app."Companies" row has
--              CompanyCode = '__TEMPLATE__', so templateCompanyId resolved to NULL, the whole
--              clone block was skipped, and the run still reported SUCCEEDED. Step 3 likewise
--              took its zero-template fallback and created a bare BUSINESSADMIN role.
--
--  Effect:     CustomAuthorizeService.HasAccessAsync returns false for every menu, so
--              GetUserRoleModuleQuery throws UnauthorizedAccessException. ModuleQueries.cs
--              catches it and returns success:false/data:null, which the landing page renders
--              as "No modules available. Contact your administrator for access."
--
--  RUN PART A FIRST and read the output. Only run PART B if PART A picks the source role you
--  expect. Menus and Capabilities are GLOBAL (no CompanyId column), so RoleCapability rows copy
--  verbatim between tenants — only RoleId is remapped.
-- ═══════════════════════════════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────────────────────────────────
--  PART A — verification. Read all four result sets before running PART B.
-- ───────────────────────────────────────────────────────────────────────────────────────────────

-- A1. Every BUSINESSADMIN role in the system, ranked by capability count.
--     The source role for the backfill is the top row that is NOT RoleId 21.
SELECT r."RoleId",
       r."CompanyId",
       c."CompanyCode",
       c."CompanyName",
       count(rc.*) FILTER (WHERE rc."HasAccess" AND rc."IsDeleted" IS NOT TRUE) AS capability_grants,
       (SELECT count(*) FROM auth."RoleModules" rm
         WHERE rm."RoleId" = r."RoleId" AND rm."HasAccess"
           AND rm."IsActive" AND rm."IsDeleted" IS NOT TRUE)                    AS module_grants
FROM auth."Roles" r
LEFT JOIN app."Companies" c        ON c."CompanyId" = r."CompanyId"
LEFT JOIN auth."RoleCapabilities" rc ON rc."RoleId" = r."RoleId"
WHERE r."RoleCode" = 'BUSINESSADMIN'
  AND r."IsDeleted" IS NOT TRUE
GROUP BY r."RoleId", r."CompanyId", c."CompanyCode", c."CompanyName"
ORDER BY capability_grants DESC;

-- A2. Does the provisioning template company exist at all? (expected: zero rows = the bug)
SELECT "CompanyId", "CompanyCode", "CompanyName", "IsDeleted"
FROM app."Companies"
WHERE "CompanyCode" = '__TEMPLATE__';

-- A3. Which modules Aram's admin currently holds (expected: the 3 always-on ones only).
SELECT m."ModuleCode", m."ModuleName", rm."HasAccess", rm."IsActive"
FROM auth."RoleModules" rm
JOIN auth."Modules" m ON m."ModuleId" = rm."ModuleId"
WHERE rm."RoleId" = 21
ORDER BY m."OrderBy";

-- A4. Aram's plan entitlements — this is what gates the CRM / ORGANIZATION / REPORTAUDIT modules
--     in ProvisionTenant Step 4b. If no MODULE:* rows come back enabled, that is a SEPARATE gap
--     in the plan catalog seed, not something this script fixes.
SELECT s."SubscriptionId", s."Status", p."PlanCode", p."PlanName",
       pe."FeatureCode", pe."IsEnabled"
FROM billing."Subscriptions" s
JOIN billing."Plans" p            ON p."PlanId" = s."PlanId"
LEFT JOIN billing."PlanEntitlements" pe ON pe."PlanId" = p."PlanId" AND pe."IsDeleted" IS NOT TRUE
WHERE s."CompanyId" = 27
  AND s."IsDeleted" IS NOT TRUE
ORDER BY pe."FeatureCode";


-- ───────────────────────────────────────────────────────────────────────────────────────────────
--  PART B — backfill. Clones RoleCapabilities from the richest OTHER BUSINESSADMIN role onto
--  RoleId 21. Idempotent: the NOT EXISTS guard means re-running inserts nothing new.
--
--  Wrapped in a transaction with a row-count notice so you can ROLLBACK if the number looks wrong.
-- ───────────────────────────────────────────────────────────────────────────────────────────────
BEGIN;

WITH source_role AS (
    SELECT rc."RoleId"
    FROM auth."RoleCapabilities" rc
    JOIN auth."Roles" r ON r."RoleId" = rc."RoleId"
    WHERE r."RoleCode" = 'BUSINESSADMIN'
      AND r."IsDeleted" IS NOT TRUE
      AND r."RoleId" <> 21
      AND rc."IsDeleted" IS NOT TRUE
    GROUP BY rc."RoleId"
    ORDER BY count(*) DESC
    LIMIT 1
)
INSERT INTO auth."RoleCapabilities"
    ("RoleId", "MenuId", "CapabilityId", "HasAccess",
     "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT 21,
       src."MenuId",
       src."CapabilityId",
       src."HasAccess",
       NULL,
       now() AT TIME ZONE 'UTC',
       NULL,
       NULL,
       TRUE,
       FALSE
FROM auth."RoleCapabilities" src
JOIN source_role sr ON sr."RoleId" = src."RoleId"
WHERE src."IsDeleted" IS NOT TRUE
  AND NOT EXISTS (
        SELECT 1
        FROM auth."RoleCapabilities" tgt
        WHERE tgt."RoleId" = 21
          AND tgt."MenuId" = src."MenuId"
          AND tgt."CapabilityId" = src."CapabilityId"
          AND tgt."IsDeleted" IS NOT TRUE
  );

-- Post-check. Expect capability_grants to match the source role's count from A1, and at least one
-- MODULE/READ row — that single row is what unblocks the landing page.
SELECT count(*) AS capability_grants
FROM auth."RoleCapabilities"
WHERE "RoleId" = 21 AND "HasAccess" AND "IsDeleted" IS NOT TRUE;

SELECT m."MenuCode", cap."CapabilityCode", rc."HasAccess"
FROM auth."RoleCapabilities" rc
JOIN auth."Menus" m         ON m."MenuId" = rc."MenuId"
JOIN auth."Capabilities" cap ON cap."CapabilityId" = rc."CapabilityId"
WHERE rc."RoleId" = 21
  AND m."MenuCode" = 'MODULE'
  AND cap."CapabilityCode" IN ('READ', 'DROPDOWN');

COMMIT;
-- ROLLBACK;  -- use this instead of COMMIT if the counts above look wrong


-- ───────────────────────────────────────────────────────────────────────────────────────────────
--  PART C — OPTIONAL. Only if A1 shows the source tenant also cloned non-BUSINESSADMIN roles that
--  Aram is missing, or if A3/A4 show module grants you expected to be present. Left commented:
--  the module gate is entitlement-driven by design, so widening it here would mask a plan-seed gap.
-- ───────────────────────────────────────────────────────────────────────────────────────────────
-- INSERT INTO auth."RoleModules" ("RoleId", "ModuleId", "HasAccess", "CreatedDate", "IsActive", "IsDeleted")
-- SELECT 21, m."ModuleId", TRUE, now() AT TIME ZONE 'UTC', TRUE, FALSE
-- FROM auth."Modules" m
-- WHERE m."ModuleCode" IN ('CRM', 'ORGANIZATION', 'REPORTAUDIT')
--   AND NOT EXISTS (SELECT 1 FROM auth."RoleModules" rm
--                    WHERE rm."RoleId" = 21 AND rm."ModuleId" = m."ModuleId");
