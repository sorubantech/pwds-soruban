-- =====================================================================================
-- P-11 (T-A17) §②b — Plan term: set the FREE plan's trial window.
--
-- CONTEXT
--   `billing."Plans"."TrialDurationDays"` (nullable integer) is the ONE additive column §②b adds.
--     NULL  = RECURRING  — the plan renews on its BillingCycle and never expires on a date.
--     N     = TIME-BOXED — assignment starts the subscription as a Trial ending N days out, and
--                          EntitlementService fails closed the instant that passes.
--
--   Only FREE is time-boxed. PLAN_50K / PLAN_100K / CUSTOM stay NULL: they are paid, recurring
--   plans, and giving one a window would silently expire a paying tenant.
--
-- PREREQUISITE
--   The EF migration adding "TrialDurationDays" MUST be applied first (user-owned). This script
--   is a data patch only — it creates no schema.
--
-- IDEMPOTENT
--   Guarded on "TrialDurationDays" IS NULL, so re-running never overwrites a window an operator
--   has since changed on the /ops/plans screen.
--
-- ORDER: run AFTER billing-plan-catalog-seed.sql.
-- =====================================================================================

BEGIN;

UPDATE billing."Plans"
SET    "TrialDurationDays" = 14,
       "ModifiedDate"      = now()
WHERE  "PlanCode"          = 'FREE'
  AND  "TrialDurationDays" IS NULL
  AND  COALESCE("IsDeleted", false) = false;

COMMIT;

-- ── VERIFY ───────────────────────────────────────────────────────────────────────────
-- Expect FREE = 14 and every other plan NULL:
--   SELECT "PlanCode", "TrialDurationDays" FROM billing."Plans" ORDER BY "SortOrder";
--
-- Existing FREE subscriptions are NOT retro-fitted — TrialEndsOn is snapshotted at assignment,
-- so tenants already on FREE keep whatever term they were given. Re-assign them if the new
-- window should apply.
