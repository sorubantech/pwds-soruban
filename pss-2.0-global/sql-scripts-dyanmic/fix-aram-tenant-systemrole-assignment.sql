-- ═══════════════════════════════════════════════════════════════════════════════════════════════
--  FIX 2 — Aram tenant admin (UserId 171) is missing the baseline SYSTEMROLE UserRole row.
--
--  Why fix 1 (fix-aram-tenant-rolecapability-backfill.sql) was not enough:
--    CustomAuthorizeService UNIONs capabilities across ALL of a user's UserRoles. The baseline
--    grants every logged-in user needs (menu MODULE / READ, general lookup + dropdown queries)
--    live on the platform-owned SYSTEMROLE, NOT on the per-tenant BUSINESSADMIN role. Fix 1
--    cloned BUSINESSADMIN -> BUSINESSADMIN, so it copied a set that never contained MODULE/READ.
--
--    ProvisionTenant Step 8 (CREATE_ADMIN) creates exactly ONE UserRole row, pointing at the
--    tenant's BUSINESSADMIN. It never attaches SYSTEMROLE. Every tenant provisioned so far has
--    this gap, not just Aram.
--
--  Design note: SYSTEMROLE is platform-owned and must stay hidden from tenant admins:
--    IsSystem = true      -> UpdateRole allows only Description/ColorHex/DefaultLandingUrl
--                            AND the tenant query filter resolves it from every tenant
--    IsAssignable = false -> GetRoles hides it from every non-SuperAdmin
--    CompanyId  = NULL    -> not owned by any one tenant
--
--  RUN PART A FIRST. PART B assumes A1 returns exactly one SYSTEMROLE row.
-- ═══════════════════════════════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────────────────────────────────
--  PART A — verification
-- ───────────────────────────────────────────────────────────────────────────────────────────────

-- A1. The SYSTEMROLE row(s). Confirm the flags match the design note above.
SELECT "RoleId", "RoleName", "RoleCode", "CompanyId",
       "IsSystem", "IsAssignable", "IsActive", "IsDeleted"
FROM auth."Roles"
WHERE "RoleCode" = 'SYSTEMROLE';

-- A2. THE decisive query — every UserRole for the broken user vs the working one, side by side.
--     Expect: businessadmin@gmail.com has 2 rows (BUSINESSADMIN + SYSTEMROLE),
--             karthick004soruban@gmail.com has 1 (BUSINESSADMIN only).
SELECT u."UserId", u."Email", ur."CompanyId" AS userrole_company,
       r."RoleId", r."RoleCode", r."IsSystem", r."IsAssignable",
       ur."IsActive", ur."IsDeleted"
FROM auth."Users" u
JOIN auth."UserRoles" ur ON ur."UserId" = u."UserId"
JOIN auth."Roles" r      ON r."RoleId"  = ur."RoleId"
WHERE u."Email" IN ('karthick004soruban@gmail.com', 'businessadmin@gmail.com')
ORDER BY u."Email", r."RoleCode";

-- A3. Does SYSTEMROLE actually hold the MODULE/READ grant? This is the exact row
--     CustomAuthorizeService looks for when GetUserRoleModuleQuery is dispatched.
SELECT r."RoleCode", m."MenuCode", cap."CapabilityCode", rc."HasAccess",
       rc."IsActive", rc."IsDeleted"
FROM auth."RoleCapabilities" rc
JOIN auth."Roles" r          ON r."RoleId" = rc."RoleId"
JOIN auth."Menus" m          ON m."MenuId" = rc."MenuId"
JOIN auth."Capabilities" cap ON cap."CapabilityId" = rc."CapabilityId"
WHERE r."RoleCode" = 'SYSTEMROLE'
  AND m."MenuCode" = 'MODULE'
ORDER BY cap."CapabilityCode";

-- A4. Full baseline inventory of SYSTEMROLE — everything fix 1 could never have supplied.
SELECT m."MenuCode", cap."CapabilityCode", rc."HasAccess"
FROM auth."RoleCapabilities" rc
JOIN auth."Roles" r          ON r."RoleId" = rc."RoleId"
JOIN auth."Menus" m          ON m."MenuId" = rc."MenuId"
JOIN auth."Capabilities" cap ON cap."CapabilityId" = rc."CapabilityId"
WHERE r."RoleCode" = 'SYSTEMROLE'
  AND rc."IsDeleted" IS NOT TRUE
ORDER BY m."MenuCode", cap."CapabilityCode";


-- ───────────────────────────────────────────────────────────────────────────────────────────────
--  PART B — attach SYSTEMROLE to the Aram admin. Idempotent via NOT EXISTS.
--
--  CompanyId is set to 27 even though the ROLE is company-agnostic: auth."UserRoles" HAS a
--  CompanyId column, so it is tenant-filtered. Leaving it NULL would make the row invisible to
--  the very user it grants access to.
-- ───────────────────────────────────────────────────────────────────────────────────────────────
BEGIN;

INSERT INTO auth."UserRoles"
    ("UserId", "RoleId", "CompanyId",
     "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT 171,
       r."RoleId",
       27,
       NULL,
       now() AT TIME ZONE 'UTC',
       NULL,
       NULL,
       TRUE,
       FALSE
FROM auth."Roles" r
WHERE r."RoleCode" = 'SYSTEMROLE'
  AND r."IsDeleted" IS NOT TRUE
  AND NOT EXISTS (
        SELECT 1 FROM auth."UserRoles" ur
        WHERE ur."UserId" = 171
          AND ur."RoleId" = r."RoleId"
          AND ur."IsDeleted" IS NOT TRUE
  );

-- Post-check: expect 2 rows (BUSINESSADMIN + SYSTEMROLE).
SELECT ur."UserRoleId", r."RoleCode", ur."CompanyId", ur."IsActive"
FROM auth."UserRoles" ur
JOIN auth."Roles" r ON r."RoleId" = ur."RoleId"
WHERE ur."UserId" = 171 AND ur."IsDeleted" IS NOT TRUE;

COMMIT;
-- ROLLBACK;

--  After COMMIT: log OUT and back IN as karthick004soruban@gmail.com. The capability check runs
--  per request against the DB, but the landing page caches the module list in Apollo — a hard
--  reload or fresh session is the reliable way to see the change.


-- ───────────────────────────────────────────────────────────────────────────────────────────────
--  PART C — backfill EVERY tenant admin missing SYSTEMROLE, not just Aram.
--  Run this only after PART B proves the fix works for user 171.
-- ───────────────────────────────────────────────────────────────────────────────────────────────
-- BEGIN;
-- INSERT INTO auth."UserRoles"
--     ("UserId", "RoleId", "CompanyId", "CreatedDate", "IsActive", "IsDeleted")
-- SELECT DISTINCT ur."UserId", sys."RoleId", ur."CompanyId",
--        now() AT TIME ZONE 'UTC', TRUE, FALSE
-- FROM auth."UserRoles" ur
-- JOIN auth."Roles" r   ON r."RoleId" = ur."RoleId" AND r."RoleCode" = 'BUSINESSADMIN'
-- CROSS JOIN (SELECT "RoleId" FROM auth."Roles"
--              WHERE "RoleCode" = 'SYSTEMROLE' AND "IsDeleted" IS NOT TRUE LIMIT 1) sys
-- WHERE ur."IsDeleted" IS NOT TRUE
--   AND NOT EXISTS (
--         SELECT 1 FROM auth."UserRoles" x
--         WHERE x."UserId" = ur."UserId" AND x."RoleId" = sys."RoleId"
--           AND x."IsDeleted" IS NOT TRUE);
-- COMMIT;
