-- ============================================================================================
-- Import once-only notification — source-entity idempotency index
--
-- Purpose
--   One import session must produce at most ONE notification per recipient per template, no
--   matter how many of the nine terminal-status call sites in the import stack fire for it
--   (a retry, a resumed Hangfire job, a re-queued batch).
--
--   The PRIMARY guard is the pre-check in NotificationWriter.ApplySourceEntityDedupeAsync —
--   it drops already-notified recipients BEFORE staging, because the job header and all
--   per-recipient rows insert in one SaveChanges, so a 23505 raised by a single duplicate
--   would fail the whole batch and drop the legitimate rows alongside it.
--
--   THIS INDEX is the race backstop underneath that pre-check: two dispatches in the same
--   instant both see "not yet notified", and the index makes one of them lose. The loser's
--   23505 is caught in NotificationDispatcher and logged as already-delivered.
--
-- Shape notes
--   * PARTIAL — `WHERE "SourceEntityType" IS NOT NULL`. Every notification that does not carry
--     a source address (the overwhelming majority) is outside the index entirely, so this
--     constrains nothing that existed before and costs nothing to maintain for those rows.
--   * `"IsDeleted" IS NOT TRUE` — a soft-deleted notification must not block a fresh one, and
--     IsDeleted is nullable, so `= false` would exclude NULL rows from the index (bool is
--     three-valued here).
--   * COALESCE("NotificationTemplateId", -1) — in PostgreSQL NULLs are DISTINCT in a unique
--     index by default, so a NULL template id would let unlimited duplicates through. -1 is
--     safe: NotificationTemplateId is an identity FK and never negative.
--   * CONCURRENTLY is deliberately NOT used: it cannot run inside a transaction block, and
--     this script is written to be run as one statement by hand or through a migration.
--     notify."Notifications" locks briefly; run it off-peak on a large tenant.
--
-- Idempotent: safe to re-run. Delivered a second time as a migrationBuilder.Sql(...) body —
-- see section 2 of prompts/import_pipeline_ux_notification_plan.md. The user creates migrations.
-- ============================================================================================

-- Pre-flight: report any rows that would already violate the constraint. If this returns rows,
-- the CREATE INDEX below will fail — clear the duplicates first (keep the earliest per group).
-- ------------------------------------------------------------------------------------------
DO $$
DECLARE
    v_dupes INT;
BEGIN
    SELECT COUNT(*) INTO v_dupes
    FROM (
        SELECT n."ToUserId",
               COALESCE(n."NotificationTemplateId", -1) AS tmpl,
               n."SourceEntityType",
               n."SourceEntityId"
        FROM notify."Notifications" n
        WHERE n."SourceEntityType" IS NOT NULL
          AND n."IsDeleted" IS NOT TRUE
        GROUP BY 1, 2, 3, 4
        HAVING COUNT(*) > 1
    ) d;

    IF v_dupes > 0 THEN
        RAISE NOTICE 'Found % duplicate group(s). Soft-deleting all but the earliest row in each.', v_dupes;

        -- Keep the earliest NotificationId per group; soft-delete the rest. Soft, not hard:
        -- these are user-visible inbox rows and the history stays auditable.
        UPDATE notify."Notifications" n
        SET "IsDeleted" = TRUE
        WHERE n."NotificationId" IN (
            SELECT x."NotificationId"
            FROM (
                SELECT n2."NotificationId",
                       ROW_NUMBER() OVER (
                           PARTITION BY n2."ToUserId",
                                        COALESCE(n2."NotificationTemplateId", -1),
                                        n2."SourceEntityType",
                                        n2."SourceEntityId"
                           ORDER BY n2."NotificationId"
                       ) AS rn
                FROM notify."Notifications" n2
                WHERE n2."SourceEntityType" IS NOT NULL
                  AND n2."IsDeleted" IS NOT TRUE
            ) x
            WHERE x.rn > 1
        );
    ELSE
        RAISE NOTICE 'No duplicate source-entity notifications found.';
    END IF;
END $$;


-- The index itself.
-- ------------------------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS "UX_Notifications_Recipient_Template_SourceEntity"
    ON notify."Notifications" (
        "ToUserId",
        (COALESCE("NotificationTemplateId", -1)),
        "SourceEntityType",
        "SourceEntityId"
    )
    WHERE "SourceEntityType" IS NOT NULL
      AND "IsDeleted" IS NOT TRUE;


-- Supporting index for the writer's pre-check and the popup query.
-- The pre-check filters on (ToUserId, SourceEntityType, SourceEntityId); the popup query filters
-- on (ToUserId, PushedAt IS NULL) and orders by NotificationId DESC. The unique index above
-- serves the first; this partial one serves the second and keeps the badge-poll tick cheap.
-- ------------------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS "IX_Notifications_PendingPush"
    ON notify."Notifications" ("ToUserId", "NotificationId" DESC)
    WHERE "PushedAt" IS NULL
      AND "IsDeleted" IS NOT TRUE;


-- Verification
-- ------------------------------------------------------------------------------------------
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'notify'
  AND tablename  = 'Notifications'
  AND indexname IN (
      'UX_Notifications_Recipient_Template_SourceEntity',
      'IX_Notifications_PendingPush'
  );
