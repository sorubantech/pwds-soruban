-- ============================================================================
-- P-19 Phase 2 §12.6 / §⑬ step 4 — platform roles land on the control plane
-- ----------------------------------------------------------------------------
-- Role.DefaultLandingUrl already exists and GetUserCredentialHandler already
-- resolves it into the token (primary role → lowest Role.OrderBy with a
-- non-null value → null, which CreateToken defaults to "masterdashboard").
-- Nothing has ever populated it for the PLATFORM_* roles, which is why Phase 1
-- needed the interim client-side branch in useAuth. Filling it here retires that
-- branch.
--
-- VALUE FORMAT: 'platform/dashboards' — NO leading slash, NO lang prefix.
-- The token carries a bare path; the frontend prepends /{lang}/. A leading
-- slash here yields '/en//platform/dashboards'.
--
-- SCOPE: platform roles only — CompanyId IS NULL. A tenant that happens to own a
-- role code starting with PLATFORM_ is not touched.
--
-- Idempotent: re-running changes nothing. Does NOT overwrite a value an operator
-- has already set to something else — only NULL/blank rows are filled.
--
-- Run AFTER ops-platform-rbac-seed.sql. Written, not run — apply it yourself.
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ── Guard: the platform roles must exist ────────────────────────────────────
DO $$
DECLARE
    v_missing int;
BEGIN
    SELECT count(*) INTO v_missing
    FROM (VALUES
        ('PLATFORM_SALES'),
        ('PLATFORM_IMPLEMENTATION'),
        ('PLATFORM_SUPPORT'),
        ('PLATFORM_FINANCE'),
        ('PLATFORM_ADMIN')
    ) AS expected(code)
    WHERE NOT EXISTS (
        SELECT 1 FROM auth."Roles" r
        WHERE r."RoleCode" = expected.code
          AND r."CompanyId" IS NULL
          AND COALESCE(r."IsDeleted", false) = false
    );

    IF v_missing > 0 THEN
        RAISE EXCEPTION
            '% platform role(s) missing. Run sql-scripts-dyanmic/ops-platform-rbac-seed.sql first.',
            v_missing;
    END IF;
END $$;

-- ── The seed ────────────────────────────────────────────────────────────────
UPDATE auth."Roles"
SET "DefaultLandingUrl" = 'platform/dashboards',
    "ModifiedDate"      = now()
WHERE "CompanyId" IS NULL
  AND COALESCE("IsDeleted", false) = false
  AND "RoleCode" IN (
      'PLATFORM_SALES',
      'PLATFORM_IMPLEMENTATION',
      'PLATFORM_SUPPORT',
      'PLATFORM_FINANCE',
      'PLATFORM_ADMIN'
  )
  AND COALESCE("DefaultLandingUrl", '') = '';

-- ── Verify ──────────────────────────────────────────────────────────────────
SELECT r."RoleCode", r."RoleName", r."OrderBy", r."DefaultLandingUrl"
FROM auth."Roles" r
WHERE r."CompanyId" IS NULL
  AND COALESCE(r."IsDeleted", false) = false
  AND r."RoleCode" LIKE 'PLATFORM_%'
ORDER BY r."OrderBy", r."RoleCode";

COMMIT;

-- ============================================================================
-- NOTE — SUPERADMIN is deliberately NOT seeded.
-- Its handler path returns early with DefaultLandingUrl = null by design, so it
-- keeps landing on masterdashboard. Support reaches the control plane through
-- PLATFORM_IMPERSONATE from the platform host, not by being redirected there.
-- ============================================================================
