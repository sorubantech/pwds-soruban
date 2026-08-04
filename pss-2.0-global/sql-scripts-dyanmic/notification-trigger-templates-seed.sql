-- =====================================================================================
-- PROMPT-22 (T-A24) — In-App Notification Service — trigger catalogue templates
-- -------------------------------------------------------------------------------------
-- Seeds two NOTIFICATIONCATEGORY MasterData rows and four platform-owned
-- notify."NotificationTemplates" rows, one per trigger code the codebase actually emits.
--
-- ── WHY THIS FILE EXISTS AT ALL ──────────────────────────────────────────────────────
-- The notification preferences panel (GetNotificationPreferences) is built from the
-- TEMPLATES, overlaid with the user's mute rows — never from the rows alone. A preference
-- row IS a mute and absence means "deliver", so a rows-only panel would be empty for every
-- user who has not muted anything yet, which is exactly the user who wants to mute something.
--
-- Consequence: with no template rows, every single user — tenant and platform — opens
-- Settings → Notifications and sees "Nothing to configure yet", forever. Nothing errors,
-- nothing logs, notifications still deliver. The screen is just permanently blank. That is
-- the failure this file prevents, and it is the only thing this file does.
--
-- ── THESE ROWS DO NOT DRIVE DISPATCH ─────────────────────────────────────────────────
-- Read this before editing any of them. The four triggers below are sent through the DIRECT
-- path (INotificationSender.SendAsync), which carries its own Title/Body/Icon/ActionUrl in
-- code at the call site. It never loads a template. So:
--   • Editing NotificationTitle or NotificationTemplateText here changes NOTHING a user sees.
--   • Editing IconCode / ActionUrl / ActionLabel here changes NOTHING a user sees.
--   • Setting EnableInApp = false here does NOT stop delivery — it removes the row from the
--     preferences panel, which takes away the user's ability to mute it. The opposite of
--     what someone reaching for that switch intends.
-- What these rows ARE is the CATALOGUE: the list of trigger codes a user is allowed to mute,
-- and the category each one is filed under. Treat them as reference data, not as content.
--
-- ── WHY CategoryId IS SET AND NOT LEFT NULL ──────────────────────────────────────────
-- A category-level mute writes the category STRING (e.g. 'Lead') and the delivery-side check
-- compares it to NotificationRequest.Category, also a plain string set at the call site
-- (CreateLead.cs → Category = "Lead"). The panel gets its category from
-- template.Category.DataValue. Those three strings must be character-identical or the
-- category switch mutes something that never matches and the user hears the notification
-- they just turned off.
-- The existing NOTIFICATIONCATEGORY set (System/Donation/Contact/Campaign/Event/Approval)
-- has no 'Lead' and no 'Provisioning', so §1 adds them with DataValue spelled exactly as the
-- C# call sites spell it. Leaving CategoryId NULL instead would file all four under the FE's
-- 'General' fallback — a group whose category switch matches no dispatch at all.
--
-- ── SCOPE ────────────────────────────────────────────────────────────────────────────
-- CompanyId = NULL on all four: these are platform-owned rows, visible to every tenant
-- (LoadTemplatesAsync takes CompanyId IS NULL OR CompanyId = :companyId) and to the platform
-- inbox (which takes CompanyId IS NULL only). A tenant that later creates its own template
-- with the same TriggerEvent wins the title in the panel — that override is by design.
-- IsSystem = true marks them as not tenant-deletable.
--
-- PREREQUISITES:
--   1. the PROMPT-22 EF migration (PSS-2.0-ONBOARDING-PROMPT-22-MIGRATION-SPEC.md)
--   2. seed_notificationtemplate_masterdata.sql — creates the NOTIFICATIONCATEGORY and
--      NOTIFICATIONPRIORITY MasterDataTypes this file's subselects resolve against. If that
--      file has not run, §1 and §2 insert nothing (guarded, no error) and the panel stays empty.
--
-- IDEMPOTENT: MasterDatas guarded on (type, DataValue); templates guarded on
-- NotificationTemplateCode, which is the UNIQUE-indexed column — (NotificationTemplateCode,
-- IsActive) — so guarding on anything else would let a re-run collide on a column it did not
-- check. Safe to re-run.
-- SAFE: additive only. No DROP, no UPDATE, no schema change.
-- =====================================================================================

BEGIN;

-- ── 1. The two missing notification categories ───────────────────────────────────────
-- DataValue is the load-bearing column here, not DataName: it is what the mute rule stores
-- and what the dispatch-side Category string is compared against. 'Lead' and 'Provisioning'
-- are spelled to match CreateLead.cs / AssignLead.cs / ProvisionTenant.cs exactly.
-- DataSetting follows the existing rows' '#bg/#fg' convention.
INSERT INTO sett."MasterDatas"(
    "MasterDataTypeId", "DataName", "DataValue", "Description", "OrderBy",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "DataSetting", "IsSystem")
SELECT t."MasterDataTypeId", v."DataName", v."DataValue", v."Description", v."OrderBy",
       2, now(), null, null, true, false, v."DataSetting", true
FROM sett."MasterDataTypes" t
CROSS JOIN (VALUES
    ('Lead',         'Lead',         'Sales-lead notifications (platform CRM)',      7, '#e0f2fe/#0284c7'),
    ('Provisioning', 'Provisioning', 'Tenant provisioning and onboarding failures',  8, '#fee2e2/#dc2626')
) AS v("DataName", "DataValue", "Description", "OrderBy", "DataSetting")
WHERE t."TypeCode" = 'NOTIFICATIONCATEGORY'
  AND NOT EXISTS (
      SELECT 1 FROM sett."MasterDatas" m
      WHERE m."MasterDataTypeId" = t."MasterDataTypeId"
        AND m."DataValue" = v."DataValue");

-- ── 2. The four trigger templates ────────────────────────────────────────────────────
-- TriggerEvent values are grep-verified against the only four SendAsync call sites in the
-- codebase. If a fifth trigger ships without a row here it delivers fine and is simply
-- un-mutable — so add a row in the same commit as any new SendAsync.
--
--   lead.created        CreateLead.cs:128  and  SubmitProductEnquiry.cs:355 (anonymous path)
--   lead.assigned       AssignLead.cs:239
--   lead.reassigned     AssignLead.cs:264
--   provisioning.failed ProvisionTenant.cs:458
--
-- EnableInApp = true is mandatory: LoadTemplatesAsync filters on it, so a false row is
-- invisible to the panel. EnableEmail/WhatsApp/Push stay false — no email path is wired for
-- these four, and a true flag here would be a promise nothing keeps.
-- IncludeAdmins = false: the recipient set is decided at the call site (PlatformRoles), and
-- an admin union here would be read by a template path these triggers never take.
-- RecipientTypeId and AudienceId are left NULL for the same reason — the direct path resolves
-- its own audience; a value here would look authoritative and be ignored.
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
    NULL, NULL, false,
    v.action_url, v.action_label, NULL,
    2, now(), null, null, true, false
FROM (VALUES
    ('NOTIFY_LEAD_CREATED', 'Lead Created',
     'A new sales lead was captured, from the console or from the public product-enquiry form.',
     'lead.created', 'Lead', 'Normal',
     'New lead created', 'ph:user-plus', '#0284c7',
     '/ops/leads', 'Open lead'),

    ('NOTIFY_LEAD_ASSIGNED', 'Lead Assigned',
     'A lead was assigned an owner. Delivered to the new owner.',
     'lead.assigned', 'Lead', 'Normal',
     'Lead assigned to you', 'ph:user-switch', '#0284c7',
     '/ops/leads', 'Open lead'),

    ('NOTIFY_LEAD_REASSIGNED', 'Lead Reassigned',
     'An owned lead moved to a different owner. Delivered to both the outgoing and incoming owner.',
     'lead.reassigned', 'Lead', 'Normal',
     'Lead reassigned', 'ph:arrows-left-right', '#0284c7',
     '/ops/leads', 'Open lead'),

    -- Priority 'High', not 'Urgent', and the distinction is deliberate: NotificationWriter
    -- treats 'Urgent' as un-muteable, ignoring every preference row. A failed provisioning run
    -- is serious but it is not an override-the-user's-choice event, and marking it Urgent here
    -- would put a row in the panel whose switch silently does nothing.
    ('NOTIFY_PROVISIONING_FAILED', 'Provisioning Failed',
     'A tenant provisioning run stopped part-way. The run is resumable; this is the alert that it needs attention.',
     'provisioning.failed', 'Provisioning', 'High',
     'Tenant provisioning failed', 'ph:warning-octagon', '#dc2626',
     '/ops/tenants', 'Open tenant')
) AS v(tpl_code, tpl_title, tpl_text, trigger_event, category_value, priority_value,
       notif_title, icon_code, icon_color, action_url, action_label)
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
WHERE NOT EXISTS (
    SELECT 1 FROM notify."NotificationTemplates" t
    WHERE t."NotificationTemplateCode" = v.tpl_code
);

COMMIT;

-- =====================================================================================
-- VERIFY (run manually after COMMIT)
-- =====================================================================================
-- -- All four rows present, platform-scoped, with the category the panel will group them by:
-- SELECT t."NotificationTemplateCode", t."TriggerEvent", c."DataValue" AS category,
--        p."DataValue" AS priority, t."EnableInApp", t."CompanyId"
--   FROM notify."NotificationTemplates" t
--   LEFT JOIN sett."MasterDatas" c ON c."MasterDataId" = t."CategoryId"
--   LEFT JOIN sett."MasterDatas" p ON p."MasterDataId" = t."PriorityId"
--  WHERE t."NotificationTemplateCode" LIKE 'NOTIFY\_%'
--    AND t."IsDeleted" = false
--  ORDER BY t."NotificationTemplateCode";
--
-- -- EXPECT 4 rows, every one with a NON-NULL category. A NULL category here means
-- -- seed_notificationtemplate_masterdata.sql has not run and §1 inserted nothing —
-- -- the panel will file those triggers under 'General' and the category mute will match
-- -- no dispatch. Re-run that file, then this one.
--
-- -- Sanity: no template may be invisible to the panel (EnableInApp false or blank trigger):
-- SELECT count(*) AS invisible_rows
--   FROM notify."NotificationTemplates"
--  WHERE "NotificationTemplateCode" LIKE 'NOTIFY\_%'
--    AND "IsDeleted" = false
--    AND ("EnableInApp" = false OR coalesce("TriggerEvent",'') = '');   -- EXPECT 0
--
-- -- The two new categories, with their colour pair:
-- SELECT m."DataValue", m."DataName", m."DataSetting", m."OrderBy"
--   FROM sett."MasterDatas" m
--   JOIN sett."MasterDataTypes" t ON t."MasterDataTypeId" = m."MasterDataTypeId"
--  WHERE t."TypeCode" = 'NOTIFICATIONCATEGORY'
--    AND m."DataValue" IN ('Lead','Provisioning');                      -- EXPECT 2
-- =====================================================================================
