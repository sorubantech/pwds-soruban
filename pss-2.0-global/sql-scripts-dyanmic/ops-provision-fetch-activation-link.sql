-- ─────────────────────────────────────────────────────────────────────────────────────────────
--  READ-ONLY. Fetch the live passwordless activation token for a freshly-provisioned tenant admin,
--  so you can build the activation link BY HAND when the welcome email (Step 9) didn't arrive.
--
--  The tenant admin has NO password — activation is entirely via this token. Step 9 emails it; if the
--  mail never lands (SMTP not configured / spam), nothing is broken — just build the link yourself.
--
--  HOW TO USE:
--    1. Edit v_admin_email (and optionally v_code) below.
--    2. Run it. Copy the TokenHash from the result.
--    3. Build the URL (see the note under the query) and open it in a browser to set the password.
-- ─────────────────────────────────────────────────────────────────────────────────────────────

\set the_email 'REPLACE_WITH_ADMIN_EMAIL'

SELECT  u."UserId",
        u."Email",
        u."CompanyId",
        c."CompanyCode",
        c."Subdomain",
        c."Status"          AS company_status,
        pr."TokenHash",             -- <<< copy this; URL-encode it in the link (see note)
        pr."ExpiresAt",
        pr."IsUsed",
        pr."CreatedAt"
FROM auth."Users" u
JOIN app."Companies" c         ON c."CompanyId" = u."CompanyId"
JOIN auth."PasswordResets" pr  ON pr."UserId"   = u."UserId"
WHERE u."Email" = :'the_email'
  AND pr."IsUsed" = false
  AND pr."ExpiresAt" > (now() AT TIME ZONE 'utc')
ORDER BY pr."CreatedAt" DESC
LIMIT 1;

-- ── Building the link ────────────────────────────────────────────────────────────────────────
--  The FE activation route is:   /{lang}/activate?token={TOKEN}      (lang is usually "en")
--
--  Full URL =  {Frontend base URL}/{lang}/activate?token={URL-ENCODED TokenHash}
--     e.g.     http://localhost:3000/en/activate?token=AbC%2Fd3%2B...
--
--  IMPORTANT: URL-encode the TokenHash before pasting — replace  +  with %2B,  /  with %2F,  =  with %3D.
--  If a platform setting PLATFORM_ACTIVATION_URL_TEMPLATE exists, that pattern (tokens {SUBDOMAIN},
--  {LANG}, {TOKEN}) is what Step 9 used instead of the Frontend base URL — check it to match the host:
--     SELECT "ParamCode", "ParamValue" FROM sett."OrganizationSettings"
--     WHERE "ParamCode" IN ('PLATFORM_ACTIVATION_URL_TEMPLATE', 'PLATFORM_DEFAULT_LANG');
-- ─────────────────────────────────────────────────────────────────────────────────────────────
