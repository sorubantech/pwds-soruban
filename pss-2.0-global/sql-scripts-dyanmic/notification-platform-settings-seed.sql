-- =====================================================================================
-- PROMPT-22 (T-A24) — In-App Notification Service — platform-global notification settings
-- -------------------------------------------------------------------------------------
-- Seeds the four sett."OrganizationSettings" rows the notification engine reads at runtime.
--
-- PLATFORM rows, not tenant rows: CompanyId IS NULL. Every one of these is read through
-- LeadHelper.GetPlatformSettingAsync, which queries
--   IgnoreQueryFilters() → CompanyId IS NULL → ParamCode → IsDeleted != true
--   → SELECT CurrentValue ?? ParamDefaultValue
-- so CurrentValue is left NULL here and ParamDefaultValue governs until someone edits it.
-- Per-tenant reads filter CompanyId = :companyId and therefore never see these rows; no
-- tenant's Organization Settings screen picks them up.
--
-- They land in the existing hidden 'PLATFORM' settings group (created by
-- billing-platform-settings-seed.sql, IsVisibleInUI = false). The group insert is repeated
-- here, guarded, so this file can run standalone in a fresh environment.
--
-- ── EVERY ONE OF THESE HAS A CODE-SIDE FALLBACK ──────────────────────────────────────
-- Nothing here is load-bearing for the engine to START. Each reader falls back to a constant
-- when the row is missing, which is why the notification service compiles and runs before
-- this script is applied. What the rows buy you is changing the value without a deploy.
-- The ONE row whose absence changes behaviour rather than just the number is
-- NOTIFY_ADMIN_ROLE_CODES — see its note below.
--
-- ── WHAT IS DELIBERATELY *NOT* HERE ──────────────────────────────────────────────────
-- The inbox POLL INTERVAL and the badge cap are frontend constants, not settings rows. They
-- are read on every mount by a component that must render before any settings round-trip
-- could return, so a row here would be a setting nothing consults — worse than no setting,
-- because someone would eventually change it and expect the client to obey.
--
-- PREREQUISITE: run AFTER the PROMPT-22 EF migration
--   (PSS-2.0-ONBOARDING-PROMPT-22-MIGRATION-SPEC.md).
--
-- ⚠ RESTART THE API AFTER COMMIT if your environment caches the platform settings snapshot.
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on (ParamCode + CompanyId IS NULL) for
-- active rows, and the group by SettingGroupCode. Safe to re-run.
-- SAFE: additive only. No DROP, no UPDATE, no schema change.
-- =====================================================================================

BEGIN;

-- ── 1. The PLATFORM settings group (hidden from tenant UI) ───────────────────────────
-- Already present in any environment that ran billing-platform-settings-seed.sql. Repeated,
-- guarded, so this file does not depend on the order the P-1x seeds were applied in.
INSERT INTO sett."SettingGroups"(
    "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT 'Platform', 'PLATFORM', '🛠', false, 99, 2, now(), null, null, true, false
WHERE NOT EXISTS (
    SELECT 1 FROM sett."SettingGroups" g
    WHERE g."SettingGroupCode" = 'PLATFORM' AND g."IsDeleted" = false
);

-- ── 2. The four notification settings ────────────────────────────────────────────────
INSERT INTO sett."OrganizationSettings"(
    "CompanyId", "SettingGroupId", "ParamName", "ParamCode", "ParamDataType",
    "AllValues", "ParamDefaultValue", "CurrentValue", "Description", "CanUserOverride",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT
    NULL, sg."SettingGroupId",
    v.param_name, v.param_code, v.data_type, v.all_values, v.default_value, NULL,
    v.description, false,
    2, now(), null, null, true, false
FROM (VALUES
    -- Read by NotificationRecipientResolver.ResolveAdminRoleCodesAsync.
    --
    -- THE ONE ROW THAT CHANGES BEHAVIOUR BY BEING ABSENT: an unset value resolves to an EMPTY
    -- list, and IncludeAdmins then unions in NOBODY. That is the deliberate fail-safe direction
    -- (a missed courtesy copy is recoverable; a notification delivered to the wrong people is
    -- not) — but it means that until this row exists, "…and notify the admins" quietly notifies
    -- no one. Comma-separated; upper-cased by the reader, so casing here is cosmetic.
    ('NOTIFY_ADMIN_ROLE_CODES', 'Notify Admin Role Codes', 'TEXT', NULL,
     'ORGADMIN,BUSINESSADMIN',
     'Role codes treated as "the admins" when a notification asks to copy them. Comma-separated. Empty means no admin is ever auto-copied.'),

    -- Read by NotificationWriter (fallback constant 20). Recipient count above which the job
    -- header is flagged IsBulk. Today the flag is recorded and nothing branches on it — the
    -- Hangfire fan-out was descoped (§⑨ Q7) — so raising or lowering this changes only what a
    -- future async path will pick up, and what the audit trail calls a bulk run.
    ('NOTIFY_INLINE_THRESHOLD', 'Notify Inline Threshold', 'NUMBER', NULL,
     '20',
     'Recipient count at or above which a dispatch is recorded as bulk on the job header. Delivery is inline either way in this build.'),

    -- Read by NotificationRetentionService (fallback constant 90).
    ('NOTIFY_RETENTION_READ_DAYS', 'Notify Retention Read Days', 'NUMBER', NULL,
     '90',
     'Age in days at which an already-READ notification is soft-deleted. Unread notifications are never removed by this rule.'),

    -- Read by NotificationRetentionService (fallback constant 365).
    --
    -- This one HARD-deletes, read or not. Notification rows are disposable by design — nothing
    -- in the system treats a notification as the record of what happened; the record lives in the
    -- source entity and in NotificationJobs.TargetSnapshot. If that ever stops being true, this
    -- number is the thing that will have silently destroyed the evidence.
    ('NOTIFY_RETENTION_HARD_DAYS', 'Notify Retention Hard Days', 'NUMBER', NULL,
     '365',
     'Age in days at which a notification is permanently deleted regardless of read state. Must be greater than the read-retention window.')
) AS v(param_code, param_name, data_type, all_values, default_value, description)
CROSS JOIN sett."SettingGroups" sg
WHERE sg."SettingGroupCode" = 'PLATFORM'
  AND sg."IsDeleted" = false
  AND NOT EXISTS (
      SELECT 1 FROM sett."OrganizationSettings" s
      WHERE s."CompanyId" IS NULL
        AND s."ParamCode" = v.param_code
        AND s."IsDeleted" = false
  );

COMMIT;

-- =====================================================================================
-- VERIFY (run manually after COMMIT)
-- =====================================================================================
-- -- All four rows, platform-scoped, with the value the engine will actually read:
-- SELECT s."ParamCode", s."ParamDataType",
--        COALESCE(s."CurrentValue", s."ParamDefaultValue") AS effective_value
--   FROM sett."OrganizationSettings" s
--  WHERE s."CompanyId" IS NULL
--    AND s."ParamCode" LIKE 'NOTIFY\_%'
--    AND s."IsDeleted" = false
--  ORDER BY s."ParamCode";
--
-- -- Sanity: hard retention must exceed read retention, or rows are hard-deleted before they
-- -- are ever soft-deleted and the soft-delete rule becomes dead code.
-- SELECT (SELECT COALESCE("CurrentValue","ParamDefaultValue")::int FROM sett."OrganizationSettings"
--          WHERE "CompanyId" IS NULL AND "ParamCode" = 'NOTIFY_RETENTION_HARD_DAYS' AND "IsDeleted" = false)
--        >
--        (SELECT COALESCE("CurrentValue","ParamDefaultValue")::int FROM sett."OrganizationSettings"
--          WHERE "CompanyId" IS NULL AND "ParamCode" = 'NOTIFY_RETENTION_READ_DAYS' AND "IsDeleted" = false)
--        AS retention_ordering_ok;
--
-- -- The admin role codes must resolve to REAL roles, or IncludeAdmins silently copies nobody:
-- SELECT DISTINCT r."RoleCode", count(*) AS role_rows
--   FROM auth."Roles" r
--  WHERE upper(r."RoleCode") IN ('ORGADMIN','BUSINESSADMIN')
--  GROUP BY r."RoleCode";
-- =====================================================================================
