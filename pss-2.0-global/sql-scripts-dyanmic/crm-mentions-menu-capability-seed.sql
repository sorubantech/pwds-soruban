-- =============================================================================
-- PSS 2.0 — T-8 (G-2): Record Collaboration — Mentions menu + comment-moderation capability
--
-- Registers the tenant screen at /crm/mentions ("Mentions me" — every comment on any record
-- that named the signed-in user), and the one new capability the collaboration layer needs:
-- CRM_COMMENT_MANAGE, "delete another user's comment".
--
-- WHY CRM_COMMENT_MANAGE EXISTS AT ALL, since the modules already have DELETE capabilities:
-- deleting a donation is a different decision from deleting what someone said about it.
-- DeleteRecordComment allows the comment's AUTHOR unconditionally, and everybody else only
-- via CRM_COMMENT_MANAGE — a module-level DELETE grant deliberately does NOT open that door.
-- Widen this through the Access Control screen if the business asks; do not widen it by
-- editing this file after it is applied.
--
-- SCHEMA NOTE — do NOT qualify these with `app`:
--   auth."Modules" / "Menus" / "Capabilities" / "MenuCapabilities" / "Roles" / "RoleCapabilities"
--
-- TWO SEPARATE CHECKS, BOTH REQUIRED:
--   1. API authorization  — auth."RoleCapabilities" joining Role → Menu(MenuCode) → Capability.
--                           auth."MenuCapabilities" is NOT consulted by HasAccessAsync.
--   2. Sidebar rendering  — GetParentChildMenuHandler builds the nav from menus the user holds
--                           ISMENURENDER on. A menu with CRM_COMMENT_MANAGE but no ISMENURENDER
--                           grant is callable by URL and completely invisible in the nav.
--   auth."MenuCapabilities" is still seeded because it is what the role matrix enumerates —
--   omit it and these grants become unmanageable through the UI.
--
-- ISMENURENDER is NEVER inserted here; it is a base-app capability that already exists.
--
-- MenuUrl is '/crm/mentions', with a LEADING SLASH, matching the Next.js route at
-- app/[lang]/(core)/crm/mentions. It must not be shared with another menu: MenuUrl is how the
-- nav builder and the sidebar active-state matcher identify a row.
--
-- ROOT-LEVEL LEAF, deliberately. CRM_MENTIONS has ParentMenuId NULL and a MenuUrl, so
-- BuildMenuHierarchy emits it at the top of the CRM tree with LeastMenu = true (LeastMenu is
-- computed from ChildMenus.Count, not read from the column). Mentions is not a sub-area of
-- Contacts or Donations — it spans all four record types — so it has no natural parent.
--
-- WHO GETS WHAT:
--   ISMENURENDER on CRM_MENTIONS  → EVERY tenant role (CompanyId IS NOT NULL) + SUPERADMIN.
--     A mention is personal. Anyone who can be mentioned must be able to read their own
--     mentions, so this grant is universal rather than role-shaped. Roles created AFTER this
--     script runs do not get it — re-run this file (it is idempotent) or grant through the
--     Access Control screen.
--   CRM_COMMENT_MANAGE            → BUSINESSADMIN (per tenant) + SUPERADMIN only.
--
-- NO DDL. app."RecordComments" / app."RecordCommentMentions" come from an EF migration, which
-- is a separate, developer-created step — this script never creates tables.
--
-- SAFE TO RE-RUN. Idempotent throughout; no DDL.
-- =============================================================================

BEGIN;

-- ── 1. Menu — CRM_MENTIONS ───────────────────────────────────────────────────────────
-- Module is RESOLVED by ModuleCode rather than hardcoded to its GUID, so this lands correctly
-- in every environment. OrderBy 23 puts it after Intelligence (22), at the end of the CRM run.
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  'Mentions', 'CRM_MENTIONS',
  NULL,
  'solar:mention-circle-bold',
  (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'CRM'),
  '/crm/mentions',
  'Comments across contacts, donations, cases and grants that named you, newest first, with an unread filter.',
  23,
  true, 'Internal', true, now(), true, false
WHERE NOT EXISTS (SELECT 1 FROM auth."Menus" mn WHERE mn."MenuCode" = 'CRM_MENTIONS');

-- Repair an already-present row (url drift / soft-deleted / demoted to a non-leaf).
-- Guarded on the wrong values, so this is a no-op once the row is correct.
UPDATE auth."Menus"
   SET "MenuUrl"      = '/crm/mentions',
       "IsLeastMenu"  = true,
       "IsVisible"    = true,
       "IsActive"     = true,
       "IsDeleted"    = false,
       "ModifiedDate" = now()
 WHERE "MenuCode" = 'CRM_MENTIONS'
   AND ("MenuUrl" IS DISTINCT FROM '/crm/mentions'
        OR "IsLeastMenu" IS NOT TRUE
        OR "IsVisible"   IS NOT TRUE
        OR "IsActive"    IS NOT TRUE
        OR "IsDeleted"   IS TRUE);

-- ── 2. Capability — CRM_COMMENT_MANAGE ───────────────────────────────────────────────
-- The idempotency guard checks CapabilityName, NOT CapabilityCode: auth."Capabilities" carries
-- a UNIQUE index on (CapabilityName, IsActive), so the name is the constrained column.
-- IsSpecial = true: this is not part of the generic READ/CREATE/MODIFY grid family.
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT v.cap_name, v.cap_code, v.cap_desc, true, v.order_by, now(), true, false
FROM (VALUES
  ('Manage Record Comments', 'CRM_COMMENT_MANAGE',
   'Delete a comment written by another user on any record. The comment''s own author never needs this — they may always retract what they wrote. Deletes are soft: the comment stays in the feed as a tombstone with its author and timestamp intact.', 120)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ── 3. MenuCapabilities ──────────────────────────────────────────────────────────────
-- The role matrix builds its ROWS from menus that have >= 1 MenuCapability and skips any menu
-- whose capability list is empty. Without this block the menu exists and the backend enforces
-- the capability, but nobody could ever grant it through the UI.
INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", now(), true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" = 'CRM_MENTIONS'
  AND c."CapabilityCode" IN ('CRM_COMMENT_MANAGE','ISMENURENDER')
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
    SELECT 1 FROM auth."MenuCapabilities" mc
    WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- ── 4a. Role grants — ISMENURENDER on CRM_MENTIONS for EVERY tenant role ─────────────
-- No RoleCode VALUES list here on purpose: the grant is universal, so it is driven off the
-- Roles table itself. Tenant roles are CompanyId IS NOT NULL; SUPERADMIN is global and is
-- matched by RoleCode alone (section 4b).
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM auth."Roles" r
CROSS JOIN auth."Menus"        m
CROSS JOIN auth."Capabilities" c
WHERE r."CompanyId" IS NOT NULL
  AND r."IsDeleted" IS NOT TRUE
  AND m."MenuCode"        = 'CRM_MENTIONS'
  AND c."CapabilityCode"  = 'ISMENURENDER'
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
    SELECT 1 FROM auth."RoleCapabilities" rc
    WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
  );

-- ── 4b. Role grants — SUPERADMIN, and CRM_COMMENT_MANAGE for BUSINESSADMIN ───────────
-- SUPERADMIN is matched by RoleCode alone (it is global, CompanyId IS NULL) and is never
-- overwritten — the NOT EXISTS guard below leaves any existing row exactly as it is.
-- BUSINESSADMIN is per-tenant, so this grants it once for every tenant that has the role.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('SUPERADMIN',    'ISMENURENDER'),
  ('SUPERADMIN',    'CRM_COMMENT_MANAGE'),
  ('BUSINESSADMIN', 'CRM_COMMENT_MANAGE')
) AS v(role_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode"       = v.role_code AND r."IsDeleted" IS NOT TRUE
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code  AND COALESCE(c."IsDeleted", false) = false
JOIN auth."Menus"        m ON m."MenuCode"       = 'CRM_MENTIONS'
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

-- No other role gets CRM_COMMENT_MANAGE. Moderating what a colleague wrote about a beneficiary
-- is an administrative act, not a caseworker one.

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--
--   -- Menu exists as a root-level leaf in the CRM module (expect 1 row):
--   SELECT "MenuCode","MenuUrl","ParentMenuId","ModuleId","OrderBy","IsLeastMenu","IsVisible"
--   FROM   auth."Menus" WHERE "MenuCode" = 'CRM_MENTIONS';
--   -- Zero rows means the CRM module lookup found nothing. MenuUrl must read /crm/mentions,
--   -- ParentMenuId must be NULL and IsLeastMenu true.
--
--   -- No other menu claims the same path (expect exactly 1 row):
--   SELECT "MenuCode" FROM auth."Menus"
--   WHERE  "MenuUrl" = '/crm/mentions' AND COALESCE("IsDeleted", false) = false;
--
--   -- Capability exists (expect 1, IsSpecial true):
--   SELECT "CapabilityCode","CapabilityName","IsSpecial","OrderBy" FROM auth."Capabilities"
--   WHERE  "CapabilityCode" = 'CRM_COMMENT_MANAGE';
--
--   -- MenuCapabilities registered (expect 2 — CRM_COMMENT_MANAGE, ISMENURENDER):
--   SELECT c."CapabilityCode"
--   FROM   auth."MenuCapabilities" mc
--   JOIN   auth."Menus" m        ON m."MenuId"       = mc."MenuId"
--   JOIN   auth."Capabilities" c ON c."CapabilityId" = mc."CapabilityId"
--   WHERE  m."MenuCode" = 'CRM_MENTIONS' ORDER BY c."CapabilityCode";
--
--   -- Who can do what (expect every tenant role + SUPERADMIN on ISMENURENDER, and only
--   -- SUPERADMIN + each tenant's BUSINESSADMIN on CRM_COMMENT_MANAGE):
--   SELECT c."CapabilityCode", r."RoleCode", r."CompanyId"
--   FROM   auth."RoleCapabilities" rc
--   JOIN   auth."Roles" r        ON r."RoleId"       = rc."RoleId"
--   JOIN   auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--   JOIN   auth."Menus" m        ON m."MenuId"       = rc."MenuId"
--   WHERE  m."MenuCode" = 'CRM_MENTIONS' AND rc."HasAccess"
--   ORDER BY c."CapabilityCode", r."RoleCode";
--
--   -- ①  Menus that carry a capability but no ISMENURENDER grant (EXPECT 0):
--   SELECT count(*) FROM (
--     SELECT m."MenuId"
--     FROM   auth."Menus" m
--     JOIN   auth."MenuCapabilities" mc ON mc."MenuId" = m."MenuId"
--     WHERE  m."MenuCode" = 'CRM_MENTIONS'
--     GROUP BY m."MenuId"
--     HAVING NOT EXISTS (
--       SELECT 1 FROM auth."RoleCapabilities" rc
--       JOIN   auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--       WHERE  rc."MenuId" = m."MenuId" AND c."CapabilityCode" = 'ISMENURENDER' AND rc."HasAccess"
--     )
--   ) q;
--   -- Non-zero means the screen is reachable by URL but invisible in the nav.
--
--   -- ②  MenuCapabilities rows pointing at a non-existent menu (EXPECT 0):
--   SELECT count(*) FROM auth."MenuCapabilities" mc
--   WHERE  NOT EXISTS (SELECT 1 FROM auth."Menus" m WHERE m."MenuId" = mc."MenuId");
--
--   -- Confirm NO comment rows were created by this script (expect 0):
--   SELECT count(*) FROM app."RecordComments";
--   -- This errors with "relation does not exist" until the EF migration for
--   -- app."RecordComments" / app."RecordCommentMentions" has been applied.
-- =====================================================================================
