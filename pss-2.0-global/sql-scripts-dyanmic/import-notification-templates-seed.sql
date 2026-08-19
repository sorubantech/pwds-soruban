-- =====================================================================================
-- P5 — Import lifecycle notifications — templates
-- -------------------------------------------------------------------------------------
-- Seeds one NOTIFICATIONCATEGORY MasterData row ('Import') and nine platform-owned
-- notify."NotificationTemplates" rows, one per trigger code ImportNotificationService emits.
--
-- The nine cover the whole lifecycle a user can see: started, validation finished (clean /
-- with errors), cancelled, completed (clean / with errors), and the three failure paths.
--
-- ── WHY THIS FILE EXISTS ─────────────────────────────────────────────────────────────
-- Scheduled imports are staying (management decision). A schedule that runs at 2 AM and
-- fails currently tells nobody: the only feedback path the import stack had was SignalR,
-- which reaches a browser sitting on the import screen right now — and at 2 AM that is
-- nobody. These templates are the other half of P5; without them the dispatcher loads no
-- template for 'import.*' and every dispatch is a silent no-op.
--
-- ── THESE ROWS DO DRIVE DISPATCH ─────────────────────────────────────────────────────
-- Unlike notification-trigger-templates-seed.sql (whose four rows are catalogue-only,
-- because those triggers use the DIRECT INotificationSender path), the import triggers go
-- through INotificationDispatcher — the TEMPLATE path. So on these rows, everything is
-- load-bearing:
--   • NotificationTitle / NotificationTemplateText ARE the text the user reads, after
--     {{Token}} substitution.
--   • RecipientTypeId / AudienceId / IncludeAdmins ARE the recipient resolution.
--   • ActionUrl IS the button target.
--   • EnableInApp = false genuinely stops delivery here (and hides the preference row).
-- Edit with that in mind.
--
-- ── RECIPIENTS ───────────────────────────────────────────────────────────────────────
-- RecipientType 'Initiated' → NotificationRecipientResolver takes
-- NotificationContext.InitiatedByUserId, which ImportNotificationService sets to the
-- ImportSession's uploading/scheduling user. Audience 'Staff' is the pool that narrowing
-- runs against. No bespoke recipient code exists anywhere in the import stack — this is
-- the whole of it.
--
-- IncludeAdmins is the "fall back to owning-module admins" requirement, and it is TRUE on
-- the three FAILURE triggers only:
--   • ImportNotificationService drops the initiator when that user has been deleted or
--     deactivated, leaving the admin union as the only recipient — which is exactly the
--     fallback that was asked for.
--   • Admins should see import failures regardless; they should NOT see every clean
--     success, which is why the two completion rows leave it FALSE.
-- The admin union reads the platform setting NOTIFY_ADMIN_ROLE_CODES. If that setting is
-- empty, IncludeAdmins adds nobody and a failure whose initiator is gone reaches no one —
-- see the VERIFY block at the bottom.
--
-- ── WHY 'completed_with_errors' IS ITS OWN TEMPLATE ──────────────────────────────────
-- Rather than one 'import.completed' row carrying a FailedRows token, or one row split by
-- TriggerConditionJson. Two reasons:
--   1. Per-trigger mutes are keyed on the trigger code, so a separate row is the only way a
--      user can keep clean-success notifications while muting partial ones (or the reverse).
--   2. NotificationDispatcher.EvaluateCondition PASSES when the referenced token is absent.
--      A condition-based split would therefore fire BOTH rows the moment a token name is
--      misspelled or a future code path omits it. The split is made in C# instead
--      (ImportNotificationService.ResolveTerminalTrigger, on ExecutionFailedRows), which is
--      why TriggerConditionJson is NULL on all nine rows below. Do not add conditions here.
--      import.validation_completed / _with_errors is split the same way, on InvalidRows.
--
-- ── import.cancelled — SEEDED, BUT ONLY DELIVERED TO A THIRD PARTY ───────────────────
-- This row previously did not exist, on the reasoning that 'Initiated' would only ever
-- notify the person who just pressed Cancel. That reasoning was wrong in the case that
-- actually matters: CancelImport records the CURRENT user as the actor precisely because
-- one staff member can cancel another's import. The uploader then lost their file with no
-- notice at all.
--
-- So the row exists, and the suppression moved into C#: ImportNotificationService skips the
-- dispatch when the canceller IS the session's initiator, and sends it when they are not.
-- {{CancelledBy}} names who stopped it. Nothing here needs to express that rule — do NOT
-- try to encode it as TriggerConditionJson (see EvaluateCondition, above).
--
-- ── import.started ───────────────────────────────────────────────────────────────────
-- Fires when the queue dispatcher gives the session the tenant's execution slot, not when
-- the user pressed Import. On a busy tenant those are hours apart, and for a scheduled run
-- the start is the middle of the night — which is the whole point of announcing it.
--
-- ── TOKENS AVAILABLE ─────────────────────────────────────────────────────────────────
-- {{SessionId}} {{GridName}} {{GridCode}} {{FileName}} {{TotalRows}} {{ImportedRows}}
-- {{FailedRows}} {{SkippedRows}} {{ValidRows}} {{InvalidRows}} {{WarningRows}}
-- {{StartedAt}} {{FinishedAt}} {{Duration}} {{ImportLink}}
-- plus {{FailureReason}} on the three failure rows and {{CancelledBy}} on the cancelled row.
-- The row counts are whatever is committed at dispatch time: {{ValidRows}}/{{InvalidRows}}/
-- {{WarningRows}} are the validation figures and are 0 before validation has run, so use
-- them only on the validation rows; {{ImportedRows}}/{{FailedRows}} are 0 until execution.
-- {{ImportLink}} is always RELATIVE (resolved from the grid's RequiredMenuCode → the menu's
-- MenuUrl, + ?sessionId=), never a host — the same row is read by every tenant on every
-- domain, so a hardcoded host would be wrong for all but one of them. It renders as an
-- empty string when the menu carries no route, which leaves the notification without a
-- button rather than with a link to nowhere.
--
-- PREREQUISITES:
--   1. PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/
--      seed_notificationtemplate_masterdata.sql — creates the NOTIFICATIONCATEGORY,
--      NOTIFICATIONPRIORITY, NOTIFICATIONRECIPIENTTYPE and NOTIFICATIONAUDIENCE
--      MasterDataTypes and their values ('Initiated', 'Staff', 'Normal', 'High'). If it has
--      not run, the JOINs below match nothing and this file inserts nothing — guarded, no
--      error, but also no notifications. Check the VERIFY block.
--
-- IDEMPOTENT: MasterDatas guarded on (type, DataValue); templates guarded on
-- NotificationTemplateCode, the UNIQUE-indexed column. Safe to re-run.
-- SAFE: additive only. No DROP, no UPDATE, no schema change.
-- =====================================================================================

BEGIN;

-- ── 1. The 'Import' notification category ────────────────────────────────────────────
-- DataValue is the load-bearing column: a category-level mute stores this string and the
-- delivery-side check compares it to the dispatched notification's Category. OrderBy 9
-- continues the existing sequence (System..Approval 1-6, Lead 7, Provisioning 8).
-- DataSetting follows the existing '#bg/#fg' convention; slate, to read as neutral
-- operational output rather than as an alert.
INSERT INTO sett."MasterDatas"(
    "MasterDataTypeId", "DataName", "DataValue", "Description", "OrderBy",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "DataSetting", "IsSystem")
SELECT t."MasterDataTypeId", v."DataName", v."DataValue", v."Description", v."OrderBy",
       2, now(), null, null, true, false, v."DataSetting", true
FROM sett."MasterDataTypes" t
CROSS JOIN (VALUES
    ('Import', 'Import', 'Data import lifecycle notifications (uploads and scheduled runs)', 9, '#e2e8f0/#475569')
) AS v("DataName", "DataValue", "Description", "OrderBy", "DataSetting")
WHERE t."TypeCode" = 'NOTIFICATIONCATEGORY'
  AND NOT EXISTS (
      SELECT 1 FROM sett."MasterDatas" m
      WHERE m."MasterDataTypeId" = t."MasterDataTypeId"
        AND m."DataValue" = v."DataValue");

-- ── 2. The nine import lifecycle templates ───────────────────────────────────────────
-- TriggerEvent values must match the constants on ImportNotificationService exactly.
--
-- Priority 'High' on the three failure rows, 'Normal' on everything else. Deliberately
-- NOT 'Urgent': NotificationWriter treats 'Urgent' as un-muteable, ignoring every preference
-- row. A failed import needs attention but does not warrant overriding a user's own choice —
-- and an Urgent row puts a switch in the preferences panel that silently does nothing.
--
-- EnableEmail/WhatsApp/Push stay false: no email path is wired for these triggers, and a
-- true flag here is a promise nothing keeps. Turn one on only alongside the sending path.
INSERT INTO notify."NotificationTemplates"(
    "NotificationTemplateTitle", "NotificationTemplateCode", "NotificationTemplateText",
    "IsSystem", "CompanyId", "CategoryId", "TriggerEvent", "TriggerConditionJson",
    "NotificationTitle", "IconCode", "IconColor", "PriorityId",
    "EnableInApp", "EnableEmail", "EnableWhatsApp", "EnablePush",
    "RecipientTypeId", "AudienceId", "IncludeAdmins",
    "ActionUrl", "ActionLabel", "LastTriggeredDate",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT
    v.tpl_title, v.tpl_code, v.tpl_text,
    true, NULL, cat."MasterDataId", v.trigger_event, NULL,
    v.notif_title, v.icon_code, v.icon_color, pri."MasterDataId",
    true, false, false, false,
    rcp."MasterDataId", aud."MasterDataId", v.include_admins,
    v.action_url, v.action_label, NULL,
    2, now(), null, null, true, false
FROM (VALUES
    -- ── progress ─────────────────────────────────────────────────────────────────────
    -- Sent when the dispatcher hands the session the tenant's execution slot. IncludeAdmins
    -- false: routine progress on someone else's file is not an admin's business.
    ('NOTIFY_IMPORT_STARTED', 'Import Started',
     '{{GridName}} import of {{FileName}} has started running. {{TotalRows}} row(s) are queued for import; you will be notified when it finishes.',
     'import.started', 'Import', 'Normal', false,
     '{{GridName}} import started', 'ph:play-circle', '#2563eb',
     '{{ImportLink}}', 'View progress'),

    -- Validation finished and the file is clean. This is the "your turn" message: nothing
    -- imports until someone comes back and confirms.
    ('NOTIFY_IMPORT_VALIDATION_COMPLETED', 'Import Validation Completed',
     'Validation of {{FileName}} finished with no errors. All {{ValidRows}} of {{TotalRows}} row(s) are ready to import ({{WarningRows}} row(s) carry warnings, which do not block the import). Open the import to start it.',
     'import.validation_completed', 'Import', 'Normal', false,
     '{{GridName}} file validated — ready to import', 'ph:shield-check', '#16a34a',
     '{{ImportLink}}', 'Start import'),

    -- Validation finished and found problems. Separate row so a user can mute the clean
    -- case and keep this one (per-trigger mutes are keyed on the trigger code).
    ('NOTIFY_IMPORT_VALIDATION_COMPLETED_WITH_ERRORS', 'Import Validation Completed With Errors',
     'Validation of {{FileName}} finished with errors. {{ValidRows}} of {{TotalRows}} row(s) are valid; {{InvalidRows}} row(s) must be fixed before they can be imported. Open the import to review them.',
     'import.validation_completed_with_errors', 'Import', 'Normal', false,
     '{{GridName}} file validated — {{InvalidRows}} row(s) need attention', 'ph:warning-diamond', '#d97706',
     '{{ImportLink}}', 'Review errors'),

    -- ── cancelled ────────────────────────────────────────────────────────────────────
    -- Dispatched ONLY when the canceller is not the initiator; see the header. Normal, not
    -- High: the import stopping is not an incident, it is someone's decision.
    ('NOTIFY_IMPORT_CANCELLED', 'Import Cancelled',
     'Your {{GridName}} import of {{FileName}} was cancelled by {{CancelledBy}}. {{ImportedRows}} of {{TotalRows}} row(s) had been imported before it stopped and have not been rolled back.',
     'import.cancelled', 'Import', 'Normal', false,
     '{{GridName}} import cancelled by {{CancelledBy}}', 'ph:prohibit', '#64748b',
     '{{ImportLink}}', 'View import'),

    -- ── success ──────────────────────────────────────────────────────────────────────
    ('NOTIFY_IMPORT_COMPLETED', 'Import Completed',
     '{{GridName}} import finished. {{ImportedRows}} of {{TotalRows}} rows were imported from {{FileName}} in {{Duration}} (started {{StartedAt}}, finished {{FinishedAt}}).',
     'import.completed', 'Import', 'Normal', false,
     '{{GridName}} import completed', 'ph:check-circle', '#16a34a',
     '{{ImportLink}}', 'View import'),

    -- ── success, but not clean ───────────────────────────────────────────────────────
    ('NOTIFY_IMPORT_COMPLETED_WITH_ERRORS', 'Import Completed With Errors',
     '{{GridName}} import finished with errors. {{ImportedRows}} of {{TotalRows}} rows were imported from {{FileName}}; {{FailedRows}} failed and {{SkippedRows}} were skipped. Duration {{Duration}} (finished {{FinishedAt}}). Open the import to review the failed rows.',
     'import.completed_with_errors', 'Import', 'Normal', false,
     '{{GridName}} import completed with {{FailedRows}} errors', 'ph:warning-circle', '#d97706',
     '{{ImportLink}}', 'Review failed rows'),

    -- ── failures ─────────────────────────────────────────────────────────────────────
    -- Covers every failure of an import that was actually running: the execution service,
    -- a batch command timeout (P3.3), a released tenant slot, and a lease reclaimed by the
    -- queue sweep after the worker process died.
    ('NOTIFY_IMPORT_FAILED', 'Import Failed',
     '{{GridName}} import from {{FileName}} failed after {{Duration}}. {{ImportedRows}} of {{TotalRows}} rows had been imported when it stopped. Reason: {{FailureReason}}',
     'import.failed', 'Import', 'High', true,
     '{{GridName}} import failed', 'ph:x-circle', '#dc2626',
     '{{ImportLink}}', 'View import'),

    -- Scheduled runs re-validate before executing, because the data or the validation rules
    -- may have changed since the file was uploaded. This is that check rejecting the run —
    -- nothing was imported.
    ('NOTIFY_IMPORT_SCHEDULE_VALIDATION_FAILED', 'Scheduled Import Validation Failed',
     'The scheduled {{GridName}} import of {{FileName}} was stopped before it started: re-validation rejected the file. Nothing was imported from its {{TotalRows}} rows. Reason: {{FailureReason}}',
     'import.schedule_validation_failed', 'Import', 'High', true,
     'Scheduled {{GridName}} import did not run', 'ph:calendar-x', '#dc2626',
     '{{ImportLink}}', 'Review import'),

    -- The end of the road: the schedule retried this session up to its attempt limit and it
    -- failed every time. Distinct from import.failed, which fires per attempt.
    ('NOTIFY_IMPORT_SCHEDULE_FAILED', 'Scheduled Import Permanently Failed',
     'The scheduled {{GridName}} import of {{FileName}} failed on every retry and will not be attempted again. Reason: {{FailureReason}} Please review the file and re-upload it.',
     'import.schedule_failed', 'Import', 'High', true,
     'Scheduled {{GridName}} import gave up', 'ph:calendar-slash', '#dc2626',
     '{{ImportLink}}', 'Re-upload file')
) AS v(tpl_code, tpl_title, tpl_text, trigger_event, category_value, priority_value,
       include_admins, notif_title, icon_code, icon_color, action_url, action_label)
JOIN sett."MasterDatas" cat
       ON cat."DataValue" = v.category_value
      AND cat."IsDeleted" = false
      AND cat."MasterDataTypeId" = (SELECT "MasterDataTypeId" FROM sett."MasterDataTypes"
                                     WHERE "TypeCode" = 'NOTIFICATIONCATEGORY')
JOIN sett."MasterDatas" pri
       ON pri."DataValue" = v.priority_value
      AND pri."IsDeleted" = false
      AND pri."MasterDataTypeId" = (SELECT "MasterDataTypeId" FROM sett."MasterDataTypes"
                                     WHERE "TypeCode" = 'NOTIFICATIONPRIORITY')
-- 'Initiated' → the session's uploading/scheduling user, via NotificationContext.
JOIN sett."MasterDatas" rcp
       ON rcp."DataValue" = 'Initiated'
      AND rcp."IsDeleted" = false
      AND rcp."MasterDataTypeId" = (SELECT "MasterDataTypeId" FROM sett."MasterDataTypes"
                                     WHERE "TypeCode" = 'NOTIFICATIONRECIPIENTTYPE')
-- 'Staff' → the pool the recipient type narrows against.
JOIN sett."MasterDatas" aud
       ON aud."DataValue" = 'Staff'
      AND aud."IsDeleted" = false
      AND aud."MasterDataTypeId" = (SELECT "MasterDataTypeId" FROM sett."MasterDataTypes"
                                     WHERE "TypeCode" = 'NOTIFICATIONAUDIENCE')
WHERE NOT EXISTS (
    SELECT 1 FROM notify."NotificationTemplates" t
    WHERE t."NotificationTemplateCode" = v.tpl_code
);

COMMIT;

-- =====================================================================================
-- VERIFY (run manually after COMMIT)
-- =====================================================================================
-- -- All nine rows present, platform-scoped, with category / priority / recipient wiring:
-- SELECT t."NotificationTemplateCode", t."TriggerEvent",
--        c."DataValue" AS category, p."DataValue" AS priority,
--        r."DataValue" AS recipient_type, a."DataValue" AS audience,
--        t."IncludeAdmins", t."EnableInApp", t."CompanyId", t."TriggerConditionJson"
--   FROM notify."NotificationTemplates" t
--   LEFT JOIN sett."MasterDatas" c ON c."MasterDataId" = t."CategoryId"
--   LEFT JOIN sett."MasterDatas" p ON p."MasterDataId" = t."PriorityId"
--   LEFT JOIN sett."MasterDatas" r ON r."MasterDataId" = t."RecipientTypeId"
--   LEFT JOIN sett."MasterDatas" a ON a."MasterDataId" = t."AudienceId"
--  WHERE t."TriggerEvent" LIKE 'import.%'
--    AND t."IsDeleted" = false
--  ORDER BY t."NotificationTemplateCode";
--
-- -- EXPECT 9 rows: started, validation_completed, validation_completed_with_errors,
-- -- cancelled, completed, completed_with_errors, failed, schedule_validation_failed,
-- -- schedule_failed. Every one must have category='Import', recipient_type='Initiated',
-- -- audience='Staff', TriggerConditionJson NULL, EnableInApp true, CompanyId NULL.
-- -- A NULL in any of those four FK columns means seed_notificationtemplate_masterdata.sql
-- -- has not run (or its DataValue spelling differs) — the JOIN dropped the row entirely, so
-- -- you would see FEWER than 9 rows rather than NULLs. Fewer than 9 = re-run that file first,
-- -- then this one. (An existing install that already had the original five will pick up the
-- -- four new rows on re-run; the guard is per-template-code, not all-or-nothing.)
--
-- -- IncludeAdmins must be TRUE on exactly the three failure triggers:
-- SELECT "TriggerEvent", "IncludeAdmins"
--   FROM notify."NotificationTemplates"
--  WHERE "TriggerEvent" LIKE 'import.%' AND "IsDeleted" = false
--  ORDER BY "IncludeAdmins" DESC, "TriggerEvent";
-- -- EXPECT true for import.failed / import.schedule_failed /
-- -- import.schedule_validation_failed; false for all six others.
--
-- -- The admin fallback is only real if this setting names roles. An empty value means
-- -- IncludeAdmins unions nobody, and a failure whose initiator has left the organisation
-- -- reaches no one at all:
-- SELECT "ParamCode", "ParamValue" FROM sett."OrganizationSettings"
--  WHERE "ParamCode" = 'NOTIFY_ADMIN_ROLE_CODES';                  -- EXPECT a non-empty value
--
-- -- The new category, with its colour pair:
-- SELECT m."DataValue", m."DataName", m."DataSetting", m."OrderBy"
--   FROM sett."MasterDatas" m
--   JOIN sett."MasterDataTypes" t ON t."MasterDataTypeId" = m."MasterDataTypeId"
--  WHERE t."TypeCode" = 'NOTIFICATIONCATEGORY' AND m."DataValue" = 'Import';   -- EXPECT 1
--
-- -- import.cancelled is now seeded (it was not, originally). Its "only when someone else
-- -- cancelled it" rule lives in ImportNotificationService, NOT in TriggerConditionJson:
-- SELECT count(*) FROM notify."NotificationTemplates"
--  WHERE "TriggerEvent" = 'import.cancelled'
--    AND "TriggerConditionJson" IS NULL;                                       -- EXPECT 1
-- =====================================================================================
