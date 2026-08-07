-- ═══════════════════════════════════════════════════════════════════════════════════════════════
--  Seed the shared system StaffCategory + backfill a Staff record for every tenant business admin.
--
--  Why: ProvisionTenant Step 8 (CREATE_ADMIN) created the admin's User + UserRoles and stopped.
--  The business admin IS a member of staff, so the tenant should start with exactly one app.Staffs
--  row — theirs. Step 5 (SEED_MASTERDATA) clones MasterDataTypes only, NOT StaffCategories, so a
--  fresh tenant has no category to file them under either.
--
--  Design — ONE platform-owned category for the whole installation, not one per tenant:
--      IsSystem  = TRUE   -> the global query filter ends in `|| IsSystem == true`, so the row
--                            resolves from inside every tenant
--      CompanyId = NULL   -> owned by the platform, not by any one tenant
--  Same shape as the SYSTEMROLE role. A per-tenant clone would instead leave every tenant with an
--  "Administrator" category they can rename or delete out from under provisioning.
--
--  The code fix lands in ProvisionTenant.EnsureAdminStaffRecordAsync (Step 8b), which resolves this
--  category by StaffCategoryCode = 'ADMINISTRATOR' and THROWS if it is absent. PART A of this
--  script is therefore a hard prerequisite for the next provisioning run.
--
--  RUN PART A FIRST, then PART B (verify), then PART C (backfill existing tenants).
-- ═══════════════════════════════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────────────────────────────────
--  PART A — the shared system category. Idempotent.
-- ───────────────────────────────────────────────────────────────────────────────────────────────
BEGIN;

INSERT INTO app."StaffCategories"
    ("StaffCategoryName", "StaffCategoryCode", "Description", "ColorHex", "OrderBy",
     "IsSystem", "CompanyId", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
     "IsActive", "IsDeleted")
SELECT 'Administrator', 'ADMINISTRATOR',
       'Platform-owned category for the tenant business administrator. Assigned automatically during tenant provisioning.',
       '#4F46E5', 0,
       TRUE, NULL, NULL, now() AT TIME ZONE 'UTC', NULL, NULL,
       TRUE, FALSE
WHERE NOT EXISTS (
    SELECT 1 FROM app."StaffCategories"
    WHERE "StaffCategoryCode" = 'ADMINISTRATOR'
      AND "CompanyId" IS NULL
      AND "IsDeleted" IS NOT TRUE);

COMMIT;


-- ───────────────────────────────────────────────────────────────────────────────────────────────
--  PART B — verification.
-- ───────────────────────────────────────────────────────────────────────────────────────────────

-- B1. The category. Expect exactly one row, IsSystem = true, CompanyId NULL.
SELECT "StaffCategoryId", "StaffCategoryName", "StaffCategoryCode",
       "IsSystem", "CompanyId", "IsActive", "IsDeleted"
FROM app."StaffCategories"
WHERE "StaffCategoryCode" = 'ADMINISTRATOR';

-- B2. Every business admin and whether they already have a Staff record.
--     Rows with staff_id IS NULL are what PART C creates.
SELECT c."CompanyId", c."CompanyCode", u."UserId", u."Email",
       s."StaffId" AS staff_id, s."StaffEmpId"
FROM auth."UserRoles" ur
JOIN auth."Roles" r     ON r."RoleId" = ur."RoleId" AND r."RoleCode" = 'BUSINESSADMIN'
JOIN auth."Users" u     ON u."UserId" = ur."UserId" AND u."IsDeleted" IS NOT TRUE
JOIN app."Companies" c  ON c."CompanyId" = u."CompanyId" AND c."IsDeleted" IS NOT TRUE
LEFT JOIN app."Staffs" s ON s."UserId" = u."UserId"
WHERE ur."IsDeleted" IS NOT TRUE
ORDER BY c."CompanyId", u."UserId";

-- B3. Guard — a tenant that somehow has TWO business admins. The design is one per tenant; PART C
--     would create a Staff row for each. Investigate before running PART C if this returns anything.
SELECT u."CompanyId", count(DISTINCT u."UserId") AS admin_count
FROM auth."UserRoles" ur
JOIN auth."Roles" r ON r."RoleId" = ur."RoleId" AND r."RoleCode" = 'BUSINESSADMIN'
JOIN auth."Users" u ON u."UserId" = ur."UserId" AND u."IsDeleted" IS NOT TRUE
WHERE ur."IsDeleted" IS NOT TRUE
GROUP BY u."CompanyId"
HAVING count(DISTINCT u."UserId") > 1;


-- ───────────────────────────────────────────────────────────────────────────────────────────────
--  PART C — backfill Staff for business admins provisioned before the code fix.
--
--  Notes on the columns this fills:
--    • StaffEmpId  — STF-NNNN, numbered per company continuing after any existing staff, exactly
--                    the shape CreateStaffHandler mints. Unique index is (CompanyId, StaffEmpId).
--    • Names       — ops."Leads"."ContactName" for the company the lead converted into; that row is
--                    the person's own record, captured by whoever worked the deal. auth."Users" has
--                    no name columns, so a tenant with no lead falls back to the email local part —
--                    EDIT those in the Staff screen afterwards; there is no better source.
--    • Mobile      — ops."Leads"."ContactPhone" when there is one AND no existing staff in that
--                    company already holds it; otherwise ''. See the warning at the bottom for what
--                    '' costs.
--    • UserId      — an ALTERNATE KEY on app."Staffs" (globally unique, not per company), which is
--                    why the NOT EXISTS below is a correctness guard, not a nicety.
--
--  Matches ProvisionTenant.EnsureAdminStaffRecordAsync, which prefers the lead's contact the same way.
-- ───────────────────────────────────────────────────────────────────────────────────────────────
BEGIN;

WITH admins AS (
    SELECT DISTINCT u."UserId", u."CompanyId", u."Email", u."UserName"
    FROM auth."UserRoles" ur
    JOIN auth."Roles" r    ON r."RoleId" = ur."RoleId" AND r."RoleCode" = 'BUSINESSADMIN'
    JOIN auth."Users" u    ON u."UserId" = ur."UserId" AND u."IsDeleted" IS NOT TRUE
    JOIN app."Companies" c ON c."CompanyId" = u."CompanyId" AND c."IsDeleted" IS NOT TRUE
    WHERE ur."IsDeleted" IS NOT TRUE
      AND NOT EXISTS (SELECT 1 FROM app."Staffs" s WHERE s."UserId" = u."UserId")
),
-- One lead per converted company. A company converted from two leads (shouldn't happen) takes the
-- earliest by LeadId so the result is deterministic.
lead_contact AS (
    SELECT DISTINCT ON (l."ConvertedCompanyId")
           l."ConvertedCompanyId" AS company_id,
           NULLIF(btrim(l."ContactName"), '')  AS contact_name,
           NULLIF(btrim(l."ContactPhone"), '') AS contact_phone
    FROM ops."Leads" l
    WHERE l."ConvertedCompanyId" IS NOT NULL
      AND l."IsDeleted" IS NOT TRUE
    ORDER BY l."ConvertedCompanyId", l."LeadId"
),
numbered AS (
    SELECT a.*,
           'STF-' || lpad((
               COALESCE((SELECT count(*) FROM app."Staffs" s WHERE s."CompanyId" = a."CompanyId"), 0)
               + row_number() OVER (PARTITION BY a."CompanyId" ORDER BY a."UserId")
           )::text, 4, '0') AS staff_emp_id,
           COALESCE(lc.contact_name,
                    split_part(COALESCE(NULLIF(a."Email", ''), a."UserName"), '@', 1)) AS derived_name,
           CASE
               WHEN lc.contact_phone IS NOT NULL
                AND NOT EXISTS (SELECT 1 FROM app."Staffs" s
                                 WHERE s."CompanyId" = a."CompanyId"
                                   AND s."StaffMobileNumber" = lc.contact_phone
                                   AND s."IsDeleted" IS NOT TRUE)
               THEN left(lc.contact_phone, 200)
               ELSE ''
           END AS derived_phone
    FROM admins a
    LEFT JOIN lead_contact lc ON lc.company_id = a."CompanyId"
)
INSERT INTO app."Staffs"
    ("StaffName", "StaffEmpId", "StaffEmail", "StaffMobileNumber", "StaffCategoryId", "UserId",
     "FirstName", "LastName", "DisplayName", "JobTitle", "StaffStatus", "JoinDate",
     "CompanyId", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT left(n.derived_name, 200),
       n.staff_emp_id,
       left(COALESCE(NULLIF(n."Email", ''), n."UserName"), 200),
       n.derived_phone,
       (SELECT "StaffCategoryId" FROM app."StaffCategories"
         WHERE "StaffCategoryCode" = 'ADMINISTRATOR' AND "CompanyId" IS NULL
           AND "IsDeleted" IS NOT TRUE LIMIT 1),
       n."UserId",
       -- Same split as the C# helper: first token is the given name, everything after the first
       -- space is the surname, so "Anna Maria Rossi" keeps "Maria Rossi" intact. A one-word name
       -- leaves LastName '' — NOT NULL permits it, and inventing a surname would be worse.
       left(split_part(n.derived_name, ' ', 1), 100),
       left(COALESCE(NULLIF(substr(n.derived_name, strpos(n.derived_name, ' ') + 1), n.derived_name), ''), 100),
       left(n.derived_name, 200),
       'Business Administrator',
       'ACTIVE',
       (now() AT TIME ZONE 'UTC')::date,
       n."CompanyId",
       NULL, now() AT TIME ZONE 'UTC', NULL, NULL, TRUE, FALSE
FROM numbered n;

-- Post-check: re-run B2. Every business admin should now have a staff_id.

COMMIT;
-- ROLLBACK;


-- ═══════════════════════════════════════════════════════════════════════════════════════════════
--  ⚠ Known trap, pre-existing and NOT introduced by this script — read before creating staff.
--
--  app."Staffs" carries a unique index IX_Staffs_CompanyId_StaffMobileNumber_Active on
--  (CompanyId, StaffMobileNumber) filtered to IsDeleted = false, and StaffMobileNumber is NOT NULL.
--  Two phone-less staff in one company therefore collide on '' — that is true today, independent of
--  this change. What changes is WHO hits it: the admin row seeded here occupies the '' slot, so the
--  tenant's FIRST phone-less staff now trips it instead of the second.
--
--  Proper fix (schema, so it belongs in a migration you author): rebuild that index with
--  HasFilter("\"IsDeleted\" = false AND \"StaffMobileNumber\" <> ''") so blank phones are exempt
--  from uniqueness. Until then, give the admin a real mobile number on the Staff screen.
-- ═══════════════════════════════════════════════════════════════════════════════════════════════
