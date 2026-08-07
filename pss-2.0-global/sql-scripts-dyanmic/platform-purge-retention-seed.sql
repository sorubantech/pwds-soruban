-- =====================================================================================
-- P-DATA-PURGE §⑤ — the four retention/purge settings, PLATFORM-scoped.
--
-- Read by DataPurgeHelper via IPlatformSettingsService. Every read passes its own fallback, so an
-- unseeded database still WORKS — it just uses the shipped constants. This file exists so the
-- numbers are visible and changeable by ops without a deployment.
--
--   PURGE_LEAD_STALE_DAYS               90  — a lead untouched this long is offered as a cleanup
--                                             candidate. "Offered", never deleted: nothing on this
--                                             feature deletes anything without a human clicking.
--   PURGE_TENANT_STALE_DAYS             30  — how long a tenant may sit in a non-live state
--                                             (failed/abandoned provisioning) before it is listed.
--   PURGE_HARD_DELETE_COOLING_OFF_DAYS  30  — the undo window. Stamped onto the purge row AT DELETE
--                                             TIME, so lowering this value can never shorten a
--                                             window already running: an operator who deleted under
--                                             a 30-day promise keeps their 30 days.
--   PURGE_CANDIDATE_LIST_MAX_ROWS      500  — hard cap on the candidate query. A review screen that
--                                             tries to render every stale row in a large database
--                                             times out and shows nothing at all, which is worse
--                                             than showing the first 500 with a "capped" notice.
--
-- CompanyId IS NULL is the platform scope — the documented reservation on
-- sett.OrganizationSettings. Per-tenant queries filter CompanyId = :companyId and so cannot see
-- these; no tenant's Organization Settings screen will render them.
--
-- CurrentValue is NULL on purpose so ParamDefaultValue governs until ops changes a value.
-- CanUserOverride = false: retention policy is the platform's, not a tenant's.
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on (ParamCode + CompanyId IS NULL) for live
-- rows. SAFE: additive only, no UPDATE, no DELETE, no schema change.
--
-- PREREQUISITE: billing-platform-settings-seed.sql (or any earlier run of this file) created the
--   'PLATFORM' SettingGroup. Part A recreates it if absent, so this file also stands alone.
--
-- ⚠ RESTART THE API AFTER COMMIT. PlatformSettingsService caches the platform snapshot per scope;
--   a running instance will not see these rows until it restarts.
-- =====================================================================================

BEGIN;

-- ── PART A — the PLATFORM settings group (hidden from tenant UI) ─────────────────────
INSERT INTO sett."SettingGroups"(
    "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT 'Platform', 'PLATFORM', '🛠', false, 99, 2, now(), null, null, true, false
WHERE NOT EXISTS (
    SELECT 1 FROM sett."SettingGroups" g
    WHERE g."SettingGroupCode" = 'PLATFORM' AND g."IsDeleted" = false
);

-- ── PART B — the four purge settings ────────────────────────────────────────────────
INSERT INTO sett."OrganizationSettings"(
    "CompanyId", "SettingGroupId", "ParamName", "ParamCode", "ParamDataType",
    "AllValues", "ParamDefaultValue", "CurrentValue", "Description", "CanUserOverride",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT
    NULL,
    sg."SettingGroupId",
    v.param_name,
    v.param_code,
    v.data_type,
    NULL,
    v.default_value,
    NULL,
    v.description,
    false,
    2, now(), null, null, true, false
FROM (VALUES
    ('PURGE_LEAD_STALE_DAYS', 'Purge Lead Stale Days', 'NUMBER', '90',
     'Days of inactivity after which a lead appears in the Data cleanup candidate list. Listing only — nothing is deleted automatically.'),
    ('PURGE_TENANT_STALE_DAYS', 'Purge Tenant Stale Days', 'NUMBER', '30',
     'Days a tenant may sit in a failed or abandoned provisioning state before it appears in the Data cleanup candidate list.'),
    ('PURGE_HARD_DELETE_COOLING_OFF_DAYS', 'Purge Hard Delete Cooling Off Days', 'NUMBER', '30',
     'How long a soft-deleted record must wait before it can be deleted permanently. Stamped at delete time, so changing this never shortens a window already running.'),
    ('PURGE_CANDIDATE_LIST_MAX_ROWS', 'Purge Candidate List Max Rows', 'NUMBER', '500',
     'Maximum rows the Data cleanup candidate list returns. The screen reports when the result was capped rather than silently showing a partial list.')
) AS v(param_code, param_name, data_type, default_value, description)
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
-- VERIFY (run after COMMIT):
--
--   SELECT s."ParamCode", s."ParamDataType", s."ParamDefaultValue", s."CurrentValue",
--          s."CanUserOverride", g."SettingGroupCode", g."IsVisibleInUI"
--   FROM   sett."OrganizationSettings" s
--   JOIN   sett."SettingGroups" g ON g."SettingGroupId" = s."SettingGroupId"
--   WHERE  s."CompanyId" IS NULL AND s."ParamCode" LIKE 'PURGE\_%' AND s."IsDeleted" = false
--   ORDER  BY s."ParamCode";
--   -- Expect exactly 4 rows, all CurrentValue NULL, all CanUserOverride false, group PLATFORM.
--
--   -- No tenant picked these up:
--   SELECT count(*) FROM sett."OrganizationSettings"
--    WHERE "CompanyId" IS NOT NULL AND "ParamCode" LIKE 'PURGE\_%' AND "IsDeleted" = false;
--   -- expect 0
-- =====================================================================================
