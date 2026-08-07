-- ============================================================================
-- Tenant First-Login Setup Wizard — DisplayOrder re-order for existing tenants
--
-- WHY THIS EXISTS
--   The wizard catalog (Base.Infrastructure/Services/Setting/TenantSetupService.cs)
--   moved BRANDING up beside the other identity sections, so the order is now:
--       1 ORG_PROFILE_CONFIRM
--       2 ORG_LOCALE          (required)
--       3 BRANDING
--       4 EMAIL_SENDER
--       5 PAYMENT_GATEWAY
--       6 INVITE_TEAM
--       7 WHATSAPP_SENDER
--       8 SMS_SENDER
--
--   MaterialiseAsync now re-syncs DisplayOrder/IsRequired from the catalog on every
--   run — but it only runs for a tenant that has zero rows (provisioning, or the
--   save handler's self-heal). A tenant materialised BEFORE this change keeps its
--   old numbers forever and would render the section cards out of sequence.
--
--   This script closes that gap. Presentation metadata only: Status, CompletedDate,
--   SkippedDate and CompletedByUserId are never touched.
--
-- IDEMPOTENT — safe to run any number of times. The WHERE clause makes a second run
-- a no-op (0 rows), and rows already on the right order are not re-stamped.
--
-- Run once against each environment after deploying the wizard rework.
-- ============================================================================

BEGIN;

WITH catalog(task_code, display_order, is_required) AS (
    VALUES
        ('ORG_PROFILE_CONFIRM', 1, false),
        ('ORG_LOCALE',          2, true ),
        ('BRANDING',            3, false),
        ('EMAIL_SENDER',        4, false),
        ('PAYMENT_GATEWAY',     5, false),
        ('INVITE_TEAM',         6, false),
        ('WHATSAPP_SENDER',     7, false),
        ('SMS_SENDER',          8, false)
)
UPDATE sett."TenantSetupTasks" t
SET    "DisplayOrder" = c.display_order,
       "IsRequired"   = c.is_required,
       "ModifiedDate" = (now() AT TIME ZONE 'utc')
FROM   catalog c
WHERE  t."TaskCode" = c.task_code
  AND  t."IsDeleted" IS DISTINCT FROM true
  AND  (t."DisplayOrder" <> c.display_order OR t."IsRequired" <> c.is_required);

COMMIT;

-- ── Verification ────────────────────────────────────────────────────────────
-- RESULT 1 must return 0 rows: no live task row disagrees with the catalog.
--
-- WITH catalog(task_code, display_order, is_required) AS (
--     VALUES
--         ('ORG_PROFILE_CONFIRM', 1, false), ('ORG_LOCALE',      2, true ),
--         ('BRANDING',            3, false), ('EMAIL_SENDER',    4, false),
--         ('PAYMENT_GATEWAY',     5, false), ('INVITE_TEAM',     6, false),
--         ('WHATSAPP_SENDER',     7, false), ('SMS_SENDER',      8, false)
-- )
-- SELECT t."CompanyId", t."TaskCode", t."DisplayOrder", t."IsRequired"
-- FROM   sett."TenantSetupTasks" t
-- JOIN   catalog c ON c.task_code = t."TaskCode"
-- WHERE  t."IsDeleted" IS DISTINCT FROM true
--   AND  (t."DisplayOrder" <> c.display_order OR t."IsRequired" <> c.is_required);
--
-- RESULT 2 must return 0 rows: no live task row carries a code outside the catalog
-- (a stale code would render as an unknown card the FE has no section for).
--
-- SELECT DISTINCT "TaskCode"
-- FROM   sett."TenantSetupTasks"
-- WHERE  "IsDeleted" IS DISTINCT FROM true
--   AND  "TaskCode" NOT IN ('ORG_PROFILE_CONFIRM','ORG_LOCALE','BRANDING','EMAIL_SENDER',
--                           'PAYMENT_GATEWAY','INVITE_TEAM','WHATSAPP_SENDER','SMS_SENDER');
