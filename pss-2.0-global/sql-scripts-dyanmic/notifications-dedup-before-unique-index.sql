-- ─────────────────────────────────────────────────────────────────────────────────────────────
-- Pre-migration cleanup for 20260820133106_Add_TenantEmailDomainRequest_PlatformEmailAccountAssignment
--
-- That migration creates two PARTIAL UNIQUE indexes on notify."Notifications":
--   UX_Notifications_Recipient_NoTemplate_SourceEntity (ToUserId, SourceEntityType, SourceEntityId)
--       WHERE "SourceEntityType" IS NOT NULL AND "NotificationTemplateId" IS NULL     AND "IsDeleted" IS NOT TRUE
--   UX_Notifications_Recipient_Template_SourceEntity   (ToUserId, NotificationTemplateId, SourceEntityType, SourceEntityId)
--       WHERE "SourceEntityType" IS NOT NULL AND "NotificationTemplateId" IS NOT NULL AND "IsDeleted" IS NOT TRUE
--
-- Existing rows already violate the first one (23505 on CREATE INDEX), because the notification
-- dispatcher wrote duplicates before the dedup rule existed. Postgres will not build a unique
-- index over data that already breaks it, so the duplicates must go first.
--
-- Resolution: keep the NEWEST row per key group (highest NotificationId) and soft-delete the rest.
-- Soft-delete, not DELETE — the index filter excludes IsDeleted IS TRUE, so flipping the flag is
-- enough to satisfy it while the history stays readable. Nothing is destroyed.
--
-- Run STEP 1 to see what would be affected, then STEP 2 to apply, then re-run update-database.
-- ─────────────────────────────────────────────────────────────────────────────────────────────

-- ── STEP 1 — INSPECT (read-only). Lists the duplicate groups and how many rows each will lose.
SELECT 'NoTemplate' AS index_group,
       "ToUserId", "SourceEntityType", "SourceEntityId",
       NULL::int AS "NotificationTemplateId",
       COUNT(*)  AS row_count,
       MAX("NotificationId") AS keeps_notificationid
FROM   notify."Notifications"
WHERE  "SourceEntityType" IS NOT NULL
  AND  "NotificationTemplateId" IS NULL
  AND  "IsDeleted" IS NOT TRUE
GROUP  BY "ToUserId", "SourceEntityType", "SourceEntityId"
HAVING COUNT(*) > 1

UNION ALL

SELECT 'Template' AS index_group,
       "ToUserId", "SourceEntityType", "SourceEntityId",
       "NotificationTemplateId",
       COUNT(*) AS row_count,
       MAX("NotificationId") AS keeps_notificationid
FROM   notify."Notifications"
WHERE  "SourceEntityType" IS NOT NULL
  AND  "NotificationTemplateId" IS NOT NULL
  AND  "IsDeleted" IS NOT TRUE
GROUP  BY "ToUserId", "NotificationTemplateId", "SourceEntityType", "SourceEntityId"
HAVING COUNT(*) > 1
ORDER  BY 1, 2, 3, 4;


-- ── STEP 2 — APPLY. Wrapped so both statements land together or not at all.
BEGIN;

-- 2a. Duplicates in the NO-TEMPLATE group.
UPDATE notify."Notifications" n
SET    "IsDeleted"    = TRUE,
       "ModifiedDate" = now()
WHERE  n."SourceEntityType" IS NOT NULL
  AND  n."NotificationTemplateId" IS NULL
  AND  n."IsDeleted" IS NOT TRUE
  AND  n."NotificationId" < (
         SELECT MAX(d."NotificationId")
         FROM   notify."Notifications" d
         WHERE  d."ToUserId"               = n."ToUserId"
           AND  d."SourceEntityType"       = n."SourceEntityType"
           AND  d."SourceEntityId" IS NOT DISTINCT FROM n."SourceEntityId"
           AND  d."NotificationTemplateId" IS NULL
           AND  d."IsDeleted" IS NOT TRUE
       );

-- 2b. Duplicates in the TEMPLATE group.
UPDATE notify."Notifications" n
SET    "IsDeleted"    = TRUE,
       "ModifiedDate" = now()
WHERE  n."SourceEntityType" IS NOT NULL
  AND  n."NotificationTemplateId" IS NOT NULL
  AND  n."IsDeleted" IS NOT TRUE
  AND  n."NotificationId" < (
         SELECT MAX(d."NotificationId")
         FROM   notify."Notifications" d
         WHERE  d."ToUserId"               = n."ToUserId"
           AND  d."NotificationTemplateId" = n."NotificationTemplateId"
           AND  d."SourceEntityType"       = n."SourceEntityType"
           AND  d."SourceEntityId" IS NOT DISTINCT FROM n."SourceEntityId"
           AND  d."IsDeleted" IS NOT TRUE
       );

COMMIT;


-- ── STEP 3 — VERIFY. Both queries must return zero rows before update-database will succeed.
SELECT "ToUserId", "SourceEntityType", "SourceEntityId", COUNT(*)
FROM   notify."Notifications"
WHERE  "SourceEntityType" IS NOT NULL AND "NotificationTemplateId" IS NULL AND "IsDeleted" IS NOT TRUE
GROUP  BY 1, 2, 3 HAVING COUNT(*) > 1;

SELECT "ToUserId", "NotificationTemplateId", "SourceEntityType", "SourceEntityId", COUNT(*)
FROM   notify."Notifications"
WHERE  "SourceEntityType" IS NOT NULL AND "NotificationTemplateId" IS NOT NULL AND "IsDeleted" IS NOT TRUE
GROUP  BY 1, 2, 3, 4 HAVING COUNT(*) > 1;
