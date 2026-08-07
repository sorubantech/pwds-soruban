-- =====================================================================================
-- DEV ONLY — point every activation / set-password link at localhost
--        sett."OrganizationSettings" — PLATFORM_ACTIVATION_URL_TEMPLATE (platform-global)
-- -------------------------------------------------------------------------------------
-- ⚠ DO NOT APPLY TO A SHARED OR PRODUCTION DATABASE. This rewrites the link that every
--   invited platform operator AND every provisioned tenant administrator receives.
--
-- WHY
--
--   TenantActivationService.BuildActivationUrlAsync reads the platform-global setting
--   PLATFORM_ACTIVATION_URL_TEMPLATE and substitutes {SUBDOMAIN} / {LANG} / {TOKEN}.
--   ops-lead-deal-seed.sql seeds it with
--
--       https://{SUBDOMAIN}.peopleserve.app/{LANG}/activate?token={TOKEN}
--
--   and PlatformStaffHelper feeds {SUBDOMAIN} from PLATFORM_ADMIN_SUBDOMAIN (default
--   'admin'), so a platform-staff invitation mails
--   https://admin.peopleserve.app/en/activate?token=… — unreachable from a dev machine.
--   The invitee cannot set a password, and the account stays IsPendingInvitation forever.
--
-- WHAT THIS DOES
--
--   Sets CurrentValue on the ONE platform-global row (CompanyId IS NULL). The seeded
--   ParamDefaultValue is left untouched, and GetPlatformSettingAsync resolves
--   CurrentValue first — so reverting is "set CurrentValue back to NULL" (§3 below) and
--   the production pattern is never lost.
--
--   {SUBDOMAIN} is deliberately dropped from the dev pattern: there is no wildcard DNS on
--   a dev box, so admin.localhost / acme.localhost resolve to nothing. Every tenant and
--   the control plane share http://localhost:3000 locally.
--
--   /{LANG}/activate?token= is the real Next.js route — src/app/[lang]/(auth)/activate.
--   {LANG} is substituted from PLATFORM_DEFAULT_LANG ('en').
--
--   Change the port below if the frontend is not on 3000.
-- =====================================================================================


-- ── 1. Point the template at localhost ───────────────────────────────────────────────
UPDATE sett."OrganizationSettings"
SET "CurrentValue" = 'http://localhost:3000/{LANG}/activate?token={TOKEN}',
    "ModifiedBy"   = 2,
    "ModifiedDate" = now()
WHERE "CompanyId" IS NULL
  AND "ParamCode"  = 'PLATFORM_ACTIVATION_URL_TEMPLATE'
  AND "IsDeleted"  = FALSE;


-- ── 2. Verify — expect exactly one row, CurrentValue on localhost ────────────────────
SELECT "ParamCode", "ParamDefaultValue", "CurrentValue"
FROM sett."OrganizationSettings"
WHERE "CompanyId" IS NULL
  AND "ParamCode" IN ('PLATFORM_ACTIVATION_URL_TEMPLATE', 'PLATFORM_DEFAULT_LANG', 'PLATFORM_ADMIN_SUBDOMAIN')
  AND "IsDeleted" = FALSE
ORDER BY "ParamCode";

-- No row for PLATFORM_ACTIVATION_URL_TEMPLATE? ops-lead-deal-seed.sql has not been
-- applied. Apply it first, then re-run §1 — the code's own fallback is the appsettings
-- single host (Frontend:BaseUrl), which currently points at dev-psscorefe.peopleserve.app.


-- ── 3. REVERT — restore the seeded production pattern ────────────────────────────────
-- UPDATE sett."OrganizationSettings"
-- SET "CurrentValue" = NULL, "ModifiedBy" = 2, "ModifiedDate" = now()
-- WHERE "CompanyId" IS NULL
--   AND "ParamCode" = 'PLATFORM_ACTIVATION_URL_TEMPLATE'
--   AND "IsDeleted" = FALSE;


-- ── 4. Recovering an invitation whose mail went to an unreachable host ───────────────
-- Existing tokens stay valid (auth.PasswordResets, 24h). After §1, use "Resend invite"
-- on the platform staff row — ResendPlatformStaffInvite reuses the live token and
-- rebuilds the URL from this setting. To read a link out of the DB without mail, see
-- sql-scripts-dyanmic/ops-provision-fetch-activation-link.sql.
