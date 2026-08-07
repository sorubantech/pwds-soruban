-- =====================================================================================
-- PROMPT-24 (T-A24) — Platform staff invitation: setting + email template
--        sett."OrganizationSettings"  — PLATFORM_ADMIN_SUBDOMAIN (platform-global)
--        notify."EmailTemplates"      — PLATFORM_STAFF_INVITATION
-- -------------------------------------------------------------------------------------
-- WHY THIS EXISTS
--
--   D4: platform staff could only be minted by hand-run SQL, which means either a
--   hand-written password hash (forbidden — logins are PBKDF2 with a per-user salt) or a
--   shared account. InvitePlatformStaffCommandHandler closes that: it creates the user
--   with IsPendingInvitation = true / MustChangePassword = true and NO usable credential,
--   mints a reset token through the existing activation service, and mails the link.
--
--   That mail needs two things this file seeds — somewhere to point the link (the admin
--   host) and something to send (the template).
--
-- READ BY
--   Base.Application/Business/OpsBusiness/PlatformStaff/PlatformStaffHelper.cs
--     • AdminSubdomainParamCode = 'PLATFORM_ADMIN_SUBDOMAIN'
--     • InviteTemplateCode      = 'PLATFORM_STAFF_INVITATION'
--
--   The link is built from PLATFORM_ACTIVATION_URL_TEMPLATE (already seeded by
--   ops-lead-deal-seed.sql) with {SUBDOMAIN} substituted from the row below — a platform
--   operator activates on the ADMIN host, never inside a customer's subdomain.
--
-- PLACEHOLDERS — every token in the body below MUST be one of these five, because
-- PlaceholderEngine renders an unknown token as an EMPTY STRING, silently, not as an error:
--   {{USER_NAME}}  {{LOGIN_HANDLE}}  {{ACTIVATION_LINK}}  {{EXPIRY_DATE}}  {{CURRENT_YEAR}}
--
-- ⚠ NO PASSWORD TOKEN, deliberately. This is why the invite does NOT reuse
--   USER_WELCOME_INVITE: that template is shared with SendUserInvite / ResetUserPassword /
--   BulkResetPasswords, all of which legitimately mail a temporary password, and
--   PlaceholderEngine has no {{#if}} support, so the password paragraph cannot be
--   suppressed per caller. For the same reason there are no {{#if}} / {{/if}} markers here.
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on its natural code key — re-running is
-- a no-op. Additive only: no DROP, no UPDATE, no schema change.
--
-- USER-OWNED: written here, applied by the user. Never executed from code.
-- PREREQUISITES: ops-platform-rbac-seed.sql (the PLATFORM module) and ops-lead-deal-seed.sql
--                (the PLATFORM setting group, the PLATFORMEMAIL category, and
--                 PLATFORM_ACTIVATION_URL_TEMPLATE) must have been applied first.
-- =====================================================================================

BEGIN;

-- ── 1. sett.OrganizationSettings — PLATFORM_ADMIN_SUBDOMAIN ───────────────────────────
--
-- CompanyId IS NULL: control-plane policy, not a tenant preference. The invite path runs
-- with no CurrentTenantId at all, and the read is .IgnoreQueryFilters() + CompanyId IS NULL.
--
-- CanUserOverride = FALSE: a tenant user must never shadow this with a UserSetting row —
-- that would redirect a platform operator's activation link into their own subdomain.
--
-- Change 'admin' below if the control-plane host in your environment is not
-- admin.<apex>. The value is substituted verbatim for {SUBDOMAIN}.
WITH g AS (
    SELECT "SettingGroupId"
    FROM sett."SettingGroups"
    WHERE "SettingGroupCode" = 'PLATFORM' AND "IsDeleted" = FALSE
    LIMIT 1
)
INSERT INTO sett."OrganizationSettings" (
    "CompanyId", "SettingGroupId", "ParamName", "ParamCode",
    "ParamDataType", "AllValues", "ParamDefaultValue", "CurrentValue",
    "Description", "CanUserOverride",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT
    NULL,
    g."SettingGroupId",
    'Platform Admin Subdomain',
    'PLATFORM_ADMIN_SUBDOMAIN',
    'STRING',
    NULL,
    'admin',
    NULL,                       -- CurrentValue NULL → ParamDefaultValue is the live value
    'Subdomain of the control-plane host. Substituted for {SUBDOMAIN} when building a platform staff activation link, so an operator activates on the admin host and never inside a customer workspace.',
    FALSE,
    2, now(), NULL, NULL, TRUE, FALSE
FROM g
WHERE NOT EXISTS (
    SELECT 1 FROM sett."OrganizationSettings" s
    WHERE s."CompanyId" IS NULL
      AND s."ParamCode" = 'PLATFORM_ADMIN_SUBDOMAIN'
      AND s."IsDeleted" = FALSE
);


-- ── 2. notify.EmailTemplates — PLATFORM_STAFF_INVITATION ──────────────────────────────
--
-- ModuleId  → the PLATFORM module, resolved by ModuleCode so the script is env-agnostic.
--             The helper reads ModuleId back OFF THIS ROW before calling the service, so
--             re-pointing the template at another module here cannot desynchronise it.
-- CompanyId → 3, the global reference row: notify."EmailTemplates"."CompanyId" is a
--             non-nullable FK, so even a platform template must name a company. The
--             service's lookup is EmailTemplateCode + ModuleId + IsActive with no CompanyId
--             predicate, so the value is bookkeeping only. Change 3 if that reference
--             company differs in your environment.
-- EmailCategoryId → PLATFORMEMAIL (!= 2 ⇒ the body is rendered from the EmailContent column),
--             which also keeps control-plane mail out of the tenant Email Template screen.
INSERT INTO "notify"."EmailTemplates"(
    "EmailTemplateCode", "EmailTemplateName", "EmailSubject", "EmailContent",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "ModuleId", "EmailCategoryId", "CompanyId")
SELECT
    'PLATFORM_STAFF_INVITATION',
    'Platform Staff Invitation',
    'Your PeopleServe control-plane access',
    '<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background-color:#f1f5f9;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f1f5f9;padding:32px 12px;">
    <tr><td align="center">
      <table role="presentation" width="600" cellpadding="0" cellspacing="0"
             style="width:600px;max-width:600px;background-color:#ffffff;border-radius:12px;
                    overflow:hidden;box-shadow:0 8px 24px rgba(15,23,42,0.08);
                    font-family:Helvetica,Arial,sans-serif;">

        <!-- Header -->
        <tr><td style="background-color:#0f172a;padding:36px 40px;text-align:center;">
          <div style="width:52px;height:52px;line-height:52px;margin:0 auto 12px auto;
                      border-radius:50%;background-color:rgba(255,255,255,0.14);
                      color:#ffffff;font-size:26px;font-weight:800;">&#128737;</div>
          <div style="font-size:12px;letter-spacing:3px;text-transform:uppercase;color:#94a3b8;font-weight:700;">
            Control Plane
          </div>
          <div style="font-size:24px;line-height:1.3;color:#ffffff;font-weight:800;margin-top:8px;">
            Set Up Your Operator Account
          </div>
        </td></tr>

        <!-- Body -->
        <tr><td style="padding:32px 40px 8px 40px;">
          <p style="margin:0 0 16px 0;font-size:15px;color:#0f172a;">Hello {{USER_NAME}},</p>
          <p style="margin:0 0 24px 0;font-size:14px;line-height:1.7;color:#475569;">
            You have been given access to the PeopleServe control plane. Choose your own
            password using the secure link below — we never send passwords by email, and your
            account cannot be used until you do.
          </p>

          <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                 style="background-color:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;">
            <tr><td style="padding:14px 20px;border-bottom:1px solid #e2e8f0;">
              <div style="font-size:11px;letter-spacing:1px;text-transform:uppercase;color:#475569;font-weight:700;">Sign In As</div>
              <div style="font-size:14px;color:#0f172a;font-weight:600;margin-top:4px;">{{LOGIN_HANDLE}}</div>
            </td></tr>
            <tr><td style="padding:14px 20px;">
              <div style="font-size:11px;letter-spacing:1px;text-transform:uppercase;color:#475569;font-weight:700;">Link Valid Until</div>
              <div style="font-size:14px;color:#0f172a;font-weight:600;margin-top:4px;">{{EXPIRY_DATE}}</div>
            </td></tr>
          </table>

          <!-- CTA -->
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:28px 0 8px 0;">
            <tr><td align="center">
              <a href="{{ACTIVATION_LINK}}"
                 style="display:inline-block;padding:14px 36px;background-color:#0f172a;color:#ffffff;
                        font-size:15px;font-weight:700;text-decoration:none;border-radius:8px;">
                Set My Password
              </a>
            </td></tr>
          </table>

          <p style="margin:16px 0 24px 0;font-size:12px;line-height:1.6;color:#94a3b8;text-align:center;">
            Button not working? Paste this address into your browser:<br>
            <span style="color:#0f172a;word-break:break-all;">{{ACTIVATION_LINK}}</span>
          </p>

          <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                 style="background-color:#fef3c7;border:1px solid #fcd34d;border-radius:10px;margin-bottom:24px;">
            <tr><td style="padding:14px 20px;font-size:13px;line-height:1.7;color:#78350f;">
              This account can see and act across every customer workspace. Do not share it,
              and do not reuse a password you use anywhere else.
            </td></tr>
          </table>

          <p style="margin:0 0 24px 0;font-size:13px;line-height:1.7;color:#475569;">
            If you were not expecting this email, tell your platform administrator — then
            ignore it. The link expires on its own and the account stays unusable until a
            password is set.
          </p>
        </td></tr>

        <!-- Footer -->
        <tr><td style="background-color:#0f172a;padding:20px 40px;text-align:center;">
          <p style="margin:0;font-size:12px;color:#94a3b8;">
            &copy; {{CURRENT_YEAR}} PeopleServe. This is an automated message — please do not reply.
          </p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>',
    2, now(), NULL, NULL, TRUE, FALSE,
    (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = 'PLATFORM'),
    (SELECT md."MasterDataId"
       FROM sett."MasterDatas" md
       JOIN sett."MasterDataTypes" mdt ON mdt."MasterDataTypeId" = md."MasterDataTypeId"
      WHERE mdt."TypeCode" = 'EMAILCATEGORY' AND md."DataValue" = 'PLATFORMEMAIL'
      LIMIT 1),
    3
WHERE NOT EXISTS (
    SELECT 1 FROM "notify"."EmailTemplates" WHERE "EmailTemplateCode" = 'PLATFORM_STAFF_INVITATION'
);


-- ── 3. Verification ───────────────────────────────────────────────────────────────────
-- Both should print exactly one row. A missing template means the invite command will
-- create the user and then fail to mail them — recoverable via "Resend invite", but noisy.
SELECT 'setting'  AS what, "ParamCode" AS code, "ParamDefaultValue" AS value
FROM sett."OrganizationSettings"
WHERE "CompanyId" IS NULL AND "ParamCode" = 'PLATFORM_ADMIN_SUBDOMAIN' AND "IsDeleted" = FALSE
UNION ALL
SELECT 'template' AS what, "EmailTemplateCode", "EmailSubject"
FROM "notify"."EmailTemplates"
WHERE "EmailTemplateCode" = 'PLATFORM_STAFF_INVITATION' AND "IsDeleted" = FALSE;

COMMIT;
