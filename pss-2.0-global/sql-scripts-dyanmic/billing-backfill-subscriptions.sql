-- =====================================================================================
-- P-02 T-A5 — Subscription backfill (every existing company gets an active subscription)
-- -------------------------------------------------------------------------------------
-- Gives every company that has NO active subscription a default CUSTOM / Active row, so the
-- entitlement resolver never fail-closes an existing live tenant during the enforcement
-- rollout. CUSTOM is chosen deliberately: all modules on, quotas unlimited (see plan seed)
-- => existing tenants keep working exactly as before until a real plan is assigned.
--
-- SCOPE: ALL non-deleted companies, INCLUDING the '__TEMPLATE__' shell (so a tenant cloned
--   from the template inherits an active subscription too). New tenants provisioned by
--   ProvisionTenantCommand (P-03) create their own subscription in step 2 and are naturally
--   skipped here by the active-subscription guard.
--
-- "Active" set = Status IN ('Trial','Active','PastDue') — matches the filtered UNIQUE index
--   on billing.Subscriptions(CompanyId). The guard below uses the same set, so this script
--   NEVER violates the one-active-subscription-per-company constraint.
--
-- IDEMPOTENT: guarded by NOT EXISTS on an active subscription per company. Re-running is a
--   no-op (once a company has an active row it is skipped).
-- SAFE: additive only. No DROP / UPDATE / schema change.
-- PREREQUISITE: run AFTER the P-02 migration AND AFTER billing-plan-catalog-seed.sql
--   (the CUSTOM plan row must exist).
-- =====================================================================================

BEGIN;

INSERT INTO billing."Subscriptions"
  ("CompanyId","PlanId","Status","StartDate","CurrentPeriodStart","CurrentPeriodEnd",
   "CreatedDate","IsActive","IsDeleted")
SELECT
  c."CompanyId",
  (SELECT p."PlanId" FROM billing."Plans" p WHERE p."PlanCode" = 'CUSTOM'),
  'Active',
  now(),
  now(),
  now() + interval '1 year',
  now(),
  true,
  false
FROM app."Companies" c
WHERE COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
    SELECT 1 FROM billing."Subscriptions" s
    WHERE s."CompanyId" = c."CompanyId"
      AND s."Status" IN ('Trial','Active','PastDue')
  );

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--   -- every non-deleted company should now have exactly one active subscription:
--   SELECT c."CompanyId", c."CompanyCode", count(s.*) AS active_subs
--   FROM app."Companies" c
--   LEFT JOIN billing."Subscriptions" s
--     ON s."CompanyId" = c."CompanyId" AND s."Status" IN ('Trial','Active','PastDue')
--   WHERE COALESCE(c."IsDeleted", false) = false
--   GROUP BY c."CompanyId", c."CompanyCode"
--   ORDER BY c."CompanyId";     -> active_subs = 1 for every row
-- =====================================================================================
