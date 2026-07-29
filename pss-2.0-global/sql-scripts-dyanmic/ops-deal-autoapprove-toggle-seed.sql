-- ============================================================================
-- ops-deal-autoapprove-toggle-seed.sql
-- P-05d / T-B9 — master ON/OFF switch for commercial-term auto-approval.
--
-- Adds one platform-global (CompanyId IS NULL) setting:
--   PLATFORM_DEAL_AUTO_APPROVE_ENABLED  (BOOLEAN, default 'true')
--
-- Semantics (enforced in SubmitCommercialTerm via LeadHelper.GetAutoApproveEnabledAsync):
--   true  → today's behaviour: a submitted deal auto-approves when
--           DiscountPercent <= PLATFORM_DISCOUNT_APPROVAL_THRESHOLD_PCT, else PENDING_APPROVAL.
--   false → auto-approval is disabled entirely: EVERY submitted deal goes to
--           PENDING_APPROVAL regardless of discount (even 0%) and needs a human
--           PLATFORM_DEAL_APPROVE decision.
--
-- To flip it OFF later (no re-seed needed):
--   UPDATE sett."OrganizationSettings"
--      SET "CurrentValue" = 'false', "ModifiedDate" = now(), "ModifiedBy" = 2
--    WHERE "CompanyId" IS NULL
--      AND "ParamCode" = 'PLATFORM_DEAL_AUTO_APPROVE_ENABLED'
--      AND "IsDeleted" = FALSE;
-- (Set back to 'true' to re-enable.)
--
-- Idempotent: re-running inserts nothing if the row already exists.
-- Apply after ops-lead-deal-seed.sql (needs the PLATFORM SettingGroup).
-- ============================================================================

WITH g AS (
    SELECT "SettingGroupId"
    FROM sett."SettingGroups"
    WHERE "SettingGroupCode" = 'PLATFORM' AND "IsDeleted" = FALSE
    LIMIT 1
)
INSERT INTO sett."OrganizationSettings" (
    "CompanyId", "SettingGroupId", "ParamName", "ParamCode",
    "ParamDataType", "AllValues", "ParamDefaultValue", "CurrentValue",
    "Description", "CanUserOverride",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT
    NULL,                       -- platform-global: no tenant owns this
    g."SettingGroupId",
    'Platform Deal Auto Approve Enabled',
    'PLATFORM_DEAL_AUTO_APPROVE_ENABLED',
    'BOOLEAN',
    'true,false',
    'true',                     -- default: auto-approval ON (current behaviour)
    NULL,                       -- CurrentValue NULL → ParamDefaultValue is the live value
    'Master switch for commercial-term auto-approval. true = auto-approve when discount is within '
    || 'PLATFORM_DISCOUNT_APPROVAL_THRESHOLD_PCT; false = every submitted deal requires manual '
    || 'PLATFORM_DEAL_APPROVE regardless of discount.',
    FALSE,
    2, now(), NULL, NULL, TRUE, FALSE
FROM g
-- Guard matches the unique index scope (global row = CompanyId IS NULL, any IsDeleted
-- state) so a soft-deleted leftover can't slip past the guard and then collide on
-- IX_OrganizationSettings_ParamCode_Global_Active. If a soft-deleted row exists,
-- reactivate it with an UPDATE instead of re-running this seed.
WHERE NOT EXISTS (
    SELECT 1 FROM sett."OrganizationSettings" s
    WHERE s."CompanyId" IS NULL
      AND s."ParamCode" = 'PLATFORM_DEAL_AUTO_APPROVE_ENABLED'
);
