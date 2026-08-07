-- ============================================================================
-- P-19 Phase 2 §12.8 — DETECTION: accounts that hold BOTH platform and tenant roles
-- ----------------------------------------------------------------------------
-- Read-only. Run it as part of the acceptance pass, and again after any bulk
-- role import.
--
-- "Platform staff" is decided by Role.CompanyId IS NULL — never by
-- User.CompanyId (§11.4). An account appearing here is refused on BOTH host
-- kinds by the login gate (reason HOST_MIXED_PLATFORM_TENANT_ROLES), so it can
-- log in nowhere. Expected result: ZERO rows.
--
-- Writes are now blocked at the source (PlatformTenantInvariantHelper, wired into
-- AssignUserRoles / BulkAssignRole / CreateUserRole / UpdateUserRole), so any row
-- returned here predates that guard and must be repaired by hand: decide which
-- kind the account is, deactivate the roles of the other kind.
-- ============================================================================

SELECT
    u."UserId",
    u."UserName",
    u."CompanyId"                                              AS "UserCompanyId",
    count(*) FILTER (WHERE r."CompanyId" IS NULL)              AS "PlatformRoleCount",
    count(*) FILTER (WHERE r."CompanyId" IS NOT NULL)          AS "TenantRoleCount",
    string_agg(r."RoleCode", ', ' ORDER BY r."RoleCode")        AS "Roles"
FROM auth."Users" u
JOIN auth."UserRoles" ur
  ON ur."UserId" = u."UserId"
 AND ur."IsActive" = true
 AND COALESCE(ur."IsDeleted", false) = false
JOIN auth."Roles" r
  ON r."RoleId" = ur."RoleId"
 AND COALESCE(r."IsDeleted", false) = false
WHERE COALESCE(u."IsDeleted", false) = false
GROUP BY u."UserId", u."UserName", u."CompanyId"
HAVING count(*) FILTER (WHERE r."CompanyId" IS NULL) > 0
   AND count(*) FILTER (WHERE r."CompanyId" IS NOT NULL) > 0
ORDER BY u."UserId";
