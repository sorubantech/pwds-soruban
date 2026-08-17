-- ============================================================================
-- Custom fields: text -> jsonb  MIGRATION CAST REFERENCE
-- ============================================================================
-- THIS SCRIPT IS NOT MEANT TO BE RUN. It is the exact DDL the EF migration must
-- emit, written out so it can be reviewed before it is generated, and so the
-- pre-flight audit and the normalisation script can be checked against the
-- statement they actually protect.
--
-- The migration itself is created by hand (migrationBuilder.Sql(...) — the
-- scaffolded AlterColumn will NOT produce the USING clause, and without USING
-- PostgreSQL refuses the type change outright with
--     42804: column "CustomFields" cannot be cast automatically to type jsonb
--     HINT: You might need to specify "USING \"CustomFields\"::jsonb".
--
-- Order of operations:
--   1. custom-fields-jsonb-preflight-audit.sql   (read-only; must show 0 blocking rows)
--   2. custom-fields-jsonb-normalise.sql         (only if step 1 found blocking rows)
--   3. the migration containing the statements below
--   4. custom-fields-jsonb-plan-verification.sql (after the indexes are created)
-- ============================================================================


-- ---------------------------------------------------------------------------
-- THE CAST
--
-- Three carrier tables, confirmed from the EF model rather than assumed: the
-- only entities mapping a CustomFields column are Contact, ContactEmailAddress
-- and Country (Base.Domain\Models\ContactModels\Contact.cs:45,
-- ContactEmailAddress.cs:14, SharedModels\Country.cs:33), and their
-- configurations now declare HasColumnType("jsonb").
-- ---------------------------------------------------------------------------

ALTER TABLE corg."Contacts"
    ALTER COLUMN "CustomFields" TYPE jsonb
    USING NULLIF(BTRIM("CustomFields"), '')::jsonb;

ALTER TABLE corg."ContactEmailAddresses"
    ALTER COLUMN "CustomFields" TYPE jsonb
    USING NULLIF(BTRIM("CustomFields"), '')::jsonb;

ALTER TABLE com."Countries"
    ALTER COLUMN "CustomFields" TYPE jsonb
    USING NULLIF(BTRIM("CustomFields"), '')::jsonb;


-- ---------------------------------------------------------------------------
-- WHAT THE USING CLAUSE DOES, TERM BY TERM
--
--   BTRIM(...)        strips leading/trailing whitespace. A value of '   ' would
--                     otherwise reach the cast as a non-empty string and raise
--                     22P02 (invalid input syntax for type json).
--   NULLIF(..., '')   turns the now-empty string into NULL. jsonb has no concept
--                     of an empty document; '' is not valid JSON, and NULL is the
--                     correct representation of "this row has no custom fields".
--                     This also covers rows that were '' before the BTRIM.
--   ::jsonb           parses. Anything that is not valid JSON raises here.
--
-- Values that were already NULL stay NULL — NULLIF and BTRIM are both
-- NULL-propagating, and casting NULL yields NULL.
--
--
-- THE TRANSACTION ABORTS ON THE FIRST ROW THAT STILL FAILS.
--
-- This is the property that matters operationally and it is worth stating
-- without hedging: ALTER TABLE ... USING rewrites the whole table as one
-- statement inside the migration's transaction. If ANY single row in ANY of the
-- three tables holds text that is not parseable as JSON, that row raises
--     22P02: invalid input syntax for type json
-- the statement aborts, the transaction rolls back, and the migration is
-- recorded as not applied. There is no partial application, no per-row skip, no
-- "continue on error" mode, and no way to see which row it was from the error
-- message alone — PostgreSQL reports the offending TEXT, not the primary key.
--
-- That is precisely why the pre-flight audit exists and why it must return zero
-- blocking rows before this runs. Finding the row afterwards, from a failed
-- deployment, is strictly harder than finding it beforehand from a SELECT.
--
-- Note the asymmetry the audit also reports: a value that parses but whose root
-- is not an OBJECT — a bare number, a string, "null", an array — will NOT abort
-- this cast. jsonb accepts all of those. Such rows migrate cleanly and then fail
-- their next save against CustomFieldDocumentValidator, which requires an object
-- root. They are a data-quality problem, not a migration blocker, and the audit
-- reports them separately for that reason.
--
--
-- LOCKING. This is a full table rewrite under ACCESS EXCLUSIVE — the table is
-- unreadable and unwritable for the duration. On a 500,000-row Contacts table
-- that is a maintenance window, not a rolling deploy. There is no CONCURRENTLY
-- form of ALTER COLUMN ... TYPE.
--
--
-- REVERSIBILITY. The Down migration is the trivial direction: jsonb casts back
-- to text without a USING clause, because every jsonb value has a text
-- representation.
--
--     ALTER TABLE corg."Contacts"
--         ALTER COLUMN "CustomFields" TYPE text;
--
-- It is not, however, byte-identical to what was there before. jsonb normalises
-- on write: key order is not preserved, duplicate keys are collapsed to the last
-- one, insignificant whitespace is dropped, and numbers are canonicalised. A
-- round trip therefore returns semantically equal but textually different JSON.
-- Nothing in this codebase depends on the textual form — the documents are only
-- ever read through JsonSerializer or jsonb_extract_path_text — but a Down
-- migration is not a byte-level undo and should not be described as one.
-- ---------------------------------------------------------------------------


-- ---------------------------------------------------------------------------
-- AFTERWARDS
--
-- The cast creates no indexes. Index DDL is emitted separately, from the
-- declared-filterable metadata, by CustomFieldIndexPlanner — it uses
-- CREATE INDEX CONCURRENTLY, which cannot run inside a transaction block and
-- therefore cannot live in an EF migration at all. Generate it, review it, run
-- each statement outside any BEGIN/COMMIT, then run
-- custom-fields-jsonb-plan-verification.sql to confirm the planner actually
-- chose the indexes rather than merely building them.
-- ---------------------------------------------------------------------------
