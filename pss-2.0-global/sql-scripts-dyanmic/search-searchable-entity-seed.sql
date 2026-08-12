-- =============================================================================
-- PSS 2.0 — T-11: Command Bar (⌘K) — switch record search ON for CONTACT
--
-- The record-search backend has been live and unreachable: `globalSearch` →
-- GlobalSearchHandler → SearchService → corg.global_search(...). Two things kept it
-- returning nothing at all, and this script fixes exactly those two:
--
--   1. auth."SearchableEntities" is EMPTY. The SQL guard reads
--        p_allowed_entity_types IS NULL OR e."EntityTypeCode" = ANY(p_allowed_entity_types)
--      and the handler passes an ARRAY, not NULL — an empty array is not NULL, so the
--      predicate is false for every row and every search silently returns zero results.
--      There is no "it works by default" state; the table has to be seeded.
--
--   2. The decorator menu 'SEARCHABLEENTITY' may not exist. DecoratorProperties.cs:73
--      resolves the globalSearch resolver's authorization to the LITERAL menu code
--      "SEARCHABLEENTITY". Without that menu row AND a READ grant on it, global search
--      403s for EVERY user — SUPERADMIN included. This is the single most common reason
--      the palette shows "Record search is unavailable right now."
--
-- SCHEMA NOTE — do NOT qualify these with `app`:
--   auth."Menus" / "Capabilities" / "Roles" / "RoleCapabilities" / "SearchableEntities"
--   public."EntityTypes"
--
-- SCOPE: CONTACT only, deliberately. corg.global_search currently indexes exactly one
-- entity — contacts (corg."Contacts".search_vector). Seeding a second entity type here
-- would advertise a destination the SQL function cannot search. Widening the function is
-- explicitly out of scope for T-11; when it is widened, add the entity rows here.
--
-- OPERATIONAL COUPLING — read this before deactivating a menu:
--   global_search.sql:70 inner-joins auth."Menus" ON 'CONTACT' = m."MenuCode" with
--   m."IsActive" = true. Deactivating or soft-deleting the CONTACT menu makes contacts
--   disappear from global search entirely, with no error and no log line — the join simply
--   matches nothing. The menu is also where the result URL comes from: the function builds
--   CONCAT(m."MenuUrl", '?mode=read&id=', <id>), so a wrong MenuUrl produces results that
--   navigate nowhere.
--
-- NO DDL. This script creates no tables, no columns, no indexes and no functions.
-- SOFT DELETE ONLY. Nothing here issues a DELETE, and no existing grant is revoked.
-- SUPERADMIN is never revoked and never overwritten.
--
-- SAFE TO RE-RUN. Idempotent throughout.
-- =============================================================================

BEGIN;

-- ── 1. Entity type — CONTACT ─────────────────────────────────────────────────────────
-- SearchService resolves the searchable set through public."EntityTypes", and
-- corg.global_search reads SchemaName/TableName from it. Guarded on EntityTypeCode,
-- which is the identifying column.
INSERT INTO public."EntityTypes"
  ("EntityTypeCode","EntityTypeName","SchemaName","TableName","CreatedDate","IsActive","IsDeleted")
SELECT 'CONTACT', 'Contact', 'corg', 'Contacts', now(), true, false
WHERE NOT EXISTS (
  SELECT 1 FROM public."EntityTypes" et WHERE et."EntityTypeCode" = 'CONTACT'
);

-- Repair an already-present row that drifted or was soft-deleted. Guarded on the wrong
-- values, so this is a no-op once the row is correct.
UPDATE public."EntityTypes"
   SET "EntityTypeName" = 'Contact',
       "SchemaName"     = 'corg',
       "TableName"      = 'Contacts',
       "IsActive"       = true,
       "IsDeleted"      = false,
       "ModifiedDate"   = now()
 WHERE "EntityTypeCode" = 'CONTACT'
   AND ("EntityTypeName" IS DISTINCT FROM 'Contact'
        OR "SchemaName"  IS DISTINCT FROM 'corg'
        OR "TableName"   IS DISTINCT FROM 'Contacts'
        OR "IsActive"    IS NOT TRUE
        OR "IsDeleted"   IS TRUE);

-- ── 2. Decorator menu — SEARCHABLEENTITY ─────────────────────────────────────────────
-- A DECORATOR menu, not a navigable screen: MenuUrl is NULL and IsVisible is false, so it
-- never appears in the rail or the context panel. It exists only to be the authorization
-- anchor the globalSearch resolver names. ModuleId is NULL for the same reason — it belongs
-- to no module; every module's users search.
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  'Global Search', 'SEARCHABLEENTITY',
  NULL,
  'ph:magnifying-glass',
  NULL,
  NULL,
  'Authorization anchor for the global record search resolver. Not a screen — it is never rendered in navigation. A role without READ on this menu cannot use the command bar''s Records section at all.',
  999,
  false, 'Internal', false, now(), true, false
WHERE NOT EXISTS (
  SELECT 1 FROM auth."Menus" mn WHERE mn."MenuCode" = 'SEARCHABLEENTITY'
);

-- Reactivate it if a previous cleanup soft-deleted it, and keep it out of the nav.
UPDATE auth."Menus"
   SET "IsVisible"    = false,
       "IsActive"     = true,
       "IsDeleted"    = false,
       "ModifiedDate" = now()
 WHERE "MenuCode" = 'SEARCHABLEENTITY'
   AND ("IsVisible" IS TRUE OR "IsActive" IS NOT TRUE OR "IsDeleted" IS TRUE);

-- ── 3. Role grants — READ on SEARCHABLEENTITY for every live role ────────────────────
-- No RoleCode VALUES list on purpose: searching records you can already open is not a
-- privileged act, and the results are permission-scoped server-side by the function itself
-- (INV-3 — the palette never offers a destination the rail would have hidden). So the grant
-- is driven off the Roles table and covers platform and tenant roles alike; SUPERADMIN falls
-- out of the same SELECT, matched by nothing but its own row.
--
-- The capability is matched on "CapabilityName" = 'Read', NOT on CapabilityCode:
-- auth."Capabilities" carries a UNIQUE index on (CapabilityName, IsActive), so the name is
-- the constrained, reliable column.
--
-- The NOT EXISTS guard means an existing row is LEFT EXACTLY AS IT IS — including a
-- deliberate HasAccess = false. Nothing here revokes, overwrites or deletes a grant, and
-- SUPERADMIN in particular is never touched once present. Roles created AFTER this script
-- runs do not get the grant: re-run this file (it is idempotent) or grant it through the
-- Access Control screen.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM auth."Roles" r
CROSS JOIN auth."Menus"        m
CROSS JOIN auth."Capabilities" c
WHERE r."IsDeleted" IS NOT TRUE
  AND r."IsActive"  IS NOT FALSE
  AND m."MenuCode"       = 'SEARCHABLEENTITY'
  AND c."CapabilityName" = 'Read'
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
    SELECT 1 FROM auth."RoleCapabilities" rc
    WHERE rc."RoleId"       = r."RoleId"
      AND rc."MenuId"       = m."MenuId"
      AND rc."CapabilityId" = c."CapabilityId"
  );

-- ── 4. Searchable entity — CONTACT → the CONTACT menu ────────────────────────────────
-- One row: the entity type that is indexed, and the menu whose MenuUrl becomes the result's
-- navigation target. The unique index is (EntityTypeId, MenuId, IsActive), so the guard is
-- on that triple rather than on the entity alone.
--
-- CapabilityId stays NULL — meaning "no capability beyond reaching the search itself". The
-- rows corg.global_search returns are already company-scoped and permission-scoped inside the
-- function; a per-entity capability here would be a second, redundant gate and is not what
-- the current function evaluates.
INSERT INTO auth."SearchableEntities"
  ("EntityTypeId","MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT et."EntityTypeId", m."MenuId", NULL, now(), true, false
FROM public."EntityTypes" et
CROSS JOIN auth."Menus" m
WHERE et."EntityTypeCode" = 'CONTACT'
  AND m."MenuCode"        = 'CONTACT'
  AND COALESCE(m."IsDeleted", false) = false
  AND NOT EXISTS (
    SELECT 1 FROM auth."SearchableEntities" se
    WHERE se."EntityTypeId" = et."EntityTypeId"
      AND se."MenuId"       = m."MenuId"
      AND se."IsActive"     = true
  );

COMMIT;

-- ── 5. Report — what this environment now looks like ─────────────────────────────────
-- Runs after COMMIT. Expect: at least one entity-type row (CONTACT), searchable_entities = 1,
-- and roles_with_search_read equal to the number of live roles in the environment.
--
-- searchable_entities = 0 is the failure to investigate first: it means the CONTACT MENU
-- (auth."Menus".MenuCode = 'CONTACT') was not found, so section 4 inserted nothing and record
-- search will keep returning no rows. Check that menu before touching anything else.
SELECT
  (SELECT count(*) FROM public."EntityTypes"
     WHERE COALESCE("IsDeleted", false) = false)                       AS entity_types_present,
  (SELECT string_agg("EntityTypeCode", ', ' ORDER BY "EntityTypeCode")
     FROM public."EntityTypes"
     WHERE COALESCE("IsDeleted", false) = false)                       AS entity_type_codes,
  (SELECT count(*) FROM auth."SearchableEntities"
     WHERE "IsActive" = true AND COALESCE("IsDeleted", false) = false) AS searchable_entities,
  (SELECT count(DISTINCT rc."RoleId")
     FROM auth."RoleCapabilities" rc
     JOIN auth."Menus"        m ON m."MenuId"       = rc."MenuId"
     JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
     WHERE m."MenuCode"       = 'SEARCHABLEENTITY'
       AND c."CapabilityName" = 'Read'
       AND rc."HasAccess"     = true
       AND COALESCE(rc."IsDeleted", false) = false)                    AS roles_with_search_read;
