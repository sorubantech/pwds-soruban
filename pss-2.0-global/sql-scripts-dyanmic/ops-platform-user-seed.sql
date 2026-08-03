-- =============================================================================
-- P-19 Phase 2 / step 0 — mint ONE platform staff user (PLATFORM_ADMIN)
-- =============================================================================
-- WHY THIS SCRIPT EXISTS
--   ops-platform-rbac-seed.sql creates the PLATFORM module, its menus, its
--   capabilities and the five PLATFORM_* roles — and deliberately stops there.
--   Nothing in the product mints a platform user today (a proper "platform
--   staff admin" screen is a later prompt), so without this script there is
--   nobody who can pass the new host gate on the platform host.
--
-- IDENTITY MODEL (P-19 §11.4 — decided, no new table)
--   A platform staff member is an ordinary auth."Users" row with
--       "CompanyId" IS NULL
--   holding at least one auth."UserRoles" row whose auth."Roles"."CompanyId"
--   IS NULL. The NULL CompanyId on the user alone is NOT the discriminator —
--   the role link is. This script sets both, consistently.
--
--   The user must hold PLATFORM roles and NOTHING ELSE (P-19 §12.8 invariant:
--   a user is either platform staff or tenant staff, never both). This script
--   asserts that at the end.
--
-- PASSWORD
--   Logins are PBKDF2 (Rfc2898DeriveBytes + SHA512, random per-user salt) — see
--   Base.Application/Extensions/AuthExtensions.cs. That CANNOT be produced in
--   plain SQL (pgcrypto has no PBKDF2-SHA512 KDF at the digest width we use),
--   so this script COPIES "PasswordHash"/"PasswordSalt" from an existing user
--   you name in the config block below. The new account is created with
--   "MustChangePassword" = true, so the first login forces a reset.
--
--   ALTERNATIVE, if you would rather not copy a hash: set
--   :source_username to any existing account anyway (the bytes are only a
--   placeholder), then immediately drive the account through the normal
--   forgot-password / reset flow before handing it over. Either way the
--   copied credential must never be the credential that stays in use.
--
-- IDEMPOTENT: safe to re-run. Re-running does not reset the password of an
-- account that already exists, and does not duplicate the role link.
--
-- APPLY MANUALLY. Do not wire into automated migrations.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ─── CONFIG — edit these three values before running ─────────────────────────
--   platform_username : the login for the new platform administrator.
--   platform_email    : contact address for the same.
--   source_username   : an EXISTING active user whose password hash/salt is
--                       copied as the temporary credential (see PASSWORD above).
--                       Must already exist or the script aborts.
CREATE TEMP TABLE _cfg AS
SELECT
    'platform.admin'::text          AS platform_username,
    'platform.admin@peopleserve.com'::text AS platform_email,
    'CHANGE_ME_SOURCE_USER'::text   AS source_username;

-- ─── Guard: the source user must exist ───────────────────────────────────────
DO $$
DECLARE v_source text;
BEGIN
    SELECT source_username INTO v_source FROM _cfg;

    IF NOT EXISTS (
        SELECT 1 FROM auth."Users" u
        WHERE u."UserName" = v_source AND u."IsDeleted" = false
    ) THEN
        RAISE EXCEPTION
            'Source user "%" not found in auth."Users". Edit the _cfg block at the top of this script and set source_username to an existing account whose password hash may be copied as the temporary credential.',
            v_source;
    END IF;
END $$;

-- ─── Guard: the PLATFORM_ADMIN platform role must exist ──────────────────────
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM auth."Roles" r
        WHERE r."RoleCode" = 'PLATFORM_ADMIN'
          AND r."CompanyId" IS NULL
          AND r."IsDeleted" = false
    ) THEN
        RAISE EXCEPTION
            'Role PLATFORM_ADMIN (CompanyId IS NULL) not found. Apply sql-scripts-dyanmic/ops-platform-rbac-seed.sql first.';
    END IF;
END $$;

-- ─── 1. The user row ─────────────────────────────────────────────────────────
-- CompanyId stays NULL: this account belongs to the platform, not to a tenant.
-- UserTypeId is a required FK; we take the internal/staff type when one is
-- recognisable by code, else the lowest-id type, so this works on any estate.
INSERT INTO auth."Users" (
    "UserName",
    "AlternateUserName",
    "PasswordHash",
    "PasswordSalt",
    "UserTypeId",
    "CompanyId",
    "Email",
    "AuthenticationMethod",
    "IsTwoFactorEnabled",
    "MustChangePassword",
    "IsAllBranchesAccess",
    "DataAccessLevel",
    "IsLocked",
    "FailedLoginCount",
    "IsPendingInvitation",
    "CreatedBy",
    "CreatedDate",
    "IsActive",
    "IsDeleted"
)
SELECT
    c.platform_username,
    c.platform_username,
    src."PasswordHash",
    src."PasswordSalt",
    COALESCE(
        (SELECT ut."UserTypeId" FROM auth."UserTypes" ut
          WHERE ut."UserTypeCode" IN ('STAFF', 'INTERNAL', 'EMPLOYEE', 'ADMIN')
            AND ut."IsDeleted" = false
          ORDER BY ut."UserTypeId" LIMIT 1),
        (SELECT ut."UserTypeId" FROM auth."UserTypes" ut
          WHERE ut."IsDeleted" = false
          ORDER BY ut."UserTypeId" LIMIT 1)
    ),
    NULL,                    -- CompanyId — platform staff belong to no tenant
    c.platform_email,
    'EMAIL_PASSWORD',
    false,
    true,                    -- MustChangePassword — first login forces a reset
    false,
    'OWN_BRANCH',
    false,
    0,
    false,
    NULL,
    NOW() AT TIME ZONE 'UTC',
    true,
    false
FROM _cfg c
JOIN auth."Users" src
      ON src."UserName" = c.source_username
     AND src."IsDeleted" = false
WHERE NOT EXISTS (
    SELECT 1 FROM auth."Users" u
    WHERE u."UserName" = c.platform_username AND u."IsDeleted" = false
)
LIMIT 1;

-- ─── 2. The role link ────────────────────────────────────────────────────────
-- Both the user's CompanyId and the UserRole's CompanyId are NULL. The gate
-- (P-19 §12.2) reads UserRole rows, not User.CompanyId, so this row is what
-- actually grants the account access on the platform host.
INSERT INTO auth."UserRoles" (
    "UserId", "RoleId", "CompanyId",
    "CreatedBy", "CreatedDate", "IsActive", "IsDeleted"
)
SELECT
    u."UserId",
    r."RoleId",
    NULL,
    NULL,
    NOW() AT TIME ZONE 'UTC',
    true,
    false
FROM _cfg c
JOIN auth."Users" u
      ON u."UserName" = c.platform_username AND u."IsDeleted" = false
JOIN auth."Roles" r
      ON r."RoleCode" = 'PLATFORM_ADMIN' AND r."CompanyId" IS NULL AND r."IsDeleted" = false
WHERE NOT EXISTS (
    SELECT 1 FROM auth."UserRoles" ur
    WHERE ur."UserId" = u."UserId"
      AND ur."RoleId" = r."RoleId"
      AND ur."IsDeleted" = false
);

-- ─── 3. Primary role ─────────────────────────────────────────────────────────
-- GetUserCredentialHandler resolves the post-login landing URL from the primary
-- role first; without this the account falls through to the "lowest OrderBy
-- role with a non-null DefaultLandingUrl" branch, which also works but is less
-- predictable. Set it explicitly.
UPDATE auth."Users" u
SET "PrimaryRoleId" = r."RoleId",
    "ModifiedDate"  = NOW() AT TIME ZONE 'UTC'
FROM _cfg c, auth."Roles" r
WHERE u."UserName" = c.platform_username
  AND u."IsDeleted" = false
  AND u."PrimaryRoleId" IS NULL
  AND r."RoleCode" = 'PLATFORM_ADMIN'
  AND r."CompanyId" IS NULL
  AND r."IsDeleted" = false;

-- ─── 4. Invariant assertion (P-19 §12.8) ─────────────────────────────────────
-- The account must hold platform roles ONLY. A mixed user is rejected by the
-- host gate on BOTH host kinds — i.e. locked out entirely — so fail loudly here
-- rather than shipping an account that silently cannot log in anywhere.
DO $$
DECLARE v_mixed int;
BEGIN
    SELECT COUNT(*) INTO v_mixed
    FROM _cfg c
    JOIN auth."Users" u
          ON u."UserName" = c.platform_username AND u."IsDeleted" = false
    JOIN auth."UserRoles" ur
          ON ur."UserId" = u."UserId" AND ur."IsDeleted" = false AND ur."IsActive" = true
    JOIN auth."Roles" r
          ON r."RoleId" = ur."RoleId"
    WHERE r."CompanyId" IS NOT NULL;

    IF v_mixed > 0 THEN
        RAISE EXCEPTION
            'Platform user holds % tenant-scoped role(s). A user must be platform staff OR tenant staff, never both (P-19 §12.8). Aborting.',
            v_mixed;
    END IF;
END $$;

-- ─── 5. Result ───────────────────────────────────────────────────────────────
SELECT
    u."UserId",
    u."UserName",
    u."CompanyId"            AS user_company_id,   -- expect NULL
    u."MustChangePassword",                        -- expect true
    r."RoleCode",
    r."CompanyId"            AS role_company_id    -- expect NULL
FROM _cfg c
JOIN auth."Users" u
      ON u."UserName" = c.platform_username AND u."IsDeleted" = false
JOIN auth."UserRoles" ur
      ON ur."UserId" = u."UserId" AND ur."IsDeleted" = false
JOIN auth."Roles" r
      ON r."RoleId" = ur."RoleId";

DROP TABLE _cfg;

COMMIT;

-- =============================================================================
-- DETECTION QUERY (P-19 §12.8 / §⑭) — run separately, expect ZERO rows.
-- Any user holding BOTH a platform role and a tenant role is locked out by the
-- host gate on every host. Fix the data before enforcement is switched on.
-- =============================================================================
-- SELECT u."UserId", u."UserName", u."CompanyId"
-- FROM auth."Users" u
-- WHERE u."IsDeleted" = false
--   AND EXISTS (SELECT 1 FROM auth."UserRoles" ur JOIN auth."Roles" r ON r."RoleId" = ur."RoleId"
--               WHERE ur."UserId" = u."UserId" AND ur."IsActive" = true AND ur."IsDeleted" = false
--                 AND r."CompanyId" IS NULL)
--   AND EXISTS (SELECT 1 FROM auth."UserRoles" ur JOIN auth."Roles" r ON r."RoleId" = ur."RoleId"
--               WHERE ur."UserId" = u."UserId" AND ur."IsActive" = true AND ur."IsDeleted" = false
--                 AND r."CompanyId" IS NOT NULL);
