-- =====================================================================================
-- P-05 T-B1/T-B6 — Lead & Deal platform policy + tenant-admin activation email seed
-- -------------------------------------------------------------------------------------
-- Everything the P-05 slice reads at runtime that is NOT already seeded elsewhere:
--
--   1. sett."SettingGroups"        — one PLATFORM group (hidden from the tenant Settings UI)
--   2. sett."OrganizationSettings" — 3 PLATFORM-GLOBAL rows (CompanyId IS NULL):
--        PLATFORM_DISCOUNT_APPROVAL_THRESHOLD_PCT  (default 15)
--        PLATFORM_ACTIVATION_URL_TEMPLATE          ({SUBDOMAIN}/{LANG}/{TOKEN} pattern)
--        PLATFORM_DEFAULT_LANG                     (default 'en')
--   3. sett."MasterDatas"          — EMAILCATEGORY value PLATFORMEMAIL (any id != 2 makes
--                                    EmailTemplateService render from the EmailContent COLUMN
--                                    rather than a file-backed EmailContentPath)
--   4. notify."EmailTemplates"     — TENANT_ADMIN_ACTIVATION, the PASSWORDLESS welcome email
--                                    sent by ProvisionTenantCommandHandler step 9
--
-- ALREADY SEEDED — DELIBERATELY NOT REPEATED HERE (see ops-platform-rbac-seed.sql, P-03 T-A9):
--   the PLATFORM module, the PLATFORM_LEADS menu, the capabilities PLATFORM_LEAD_VIEW /
--   PLATFORM_LEAD_EDIT / PLATFORM_LEAD_EXPORT / PLATFORM_DEAL_APPROVE, the 5 platform roles and
--   every D-Q7 RoleCapability grant. P-05 hangs its commands off exactly those codes
--   (reads → PLATFORM_LEADS + PLATFORM_LEAD_VIEW, writes → PLATFORM_LEAD_EDIT,
--    approve/reject → PLATFORM_DEAL_APPROVE) and introduces NO new menu or capability.
--
-- WHY THE SETTINGS ARE PLATFORM-GLOBAL (CompanyId IS NULL): these are control-plane policy, not
-- tenant preference. At submit/provision time the caller has no tenant (CurrentTenantId is null),
-- and LeadHelper.GetPlatformSettingAsync reads with .IgnoreQueryFilters() + CompanyId IS NULL.
-- They are NOT fanned out per tenant, unlike orgsettings-tax-exemption-number-seed.sql.
--
-- WHY A DEDICATED TEMPLATE AND NOT USER_WELCOME_INVITE: that template is shared with
-- SendUserInvite / ResetUserPassword / BulkResetPasswords, all of which legitimately mail a
-- temporary password, and PlaceholderEngine has NO {{#if}} support — an unknown token renders as
-- empty but a conditional block's BODY still renders, so the password paragraph cannot be
-- suppressed per caller. TENANT_ADMIN_ACTIVATION carries no password token at all.
-- For the same reason this template contains NO {{#if}} / {{/if}} markers anywhere.
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on its natural code key — re-running is a
-- no-op. Additive only: no DROP, no UPDATE, no schema change.
--
-- USER-OWNED: this file is written here and applied by the user. It is never executed from code.
-- PREREQUISITE: run AFTER ops-platform-rbac-seed.sql (the PLATFORM module must exist).
-- =====================================================================================

BEGIN;

-- ── 1. sett.SettingGroups — PLATFORM group ────────────────────────────────────────────────────
-- IsVisibleInUI = FALSE: these rows are control-plane policy and must never appear on a tenant's
-- Organization Settings screen. OrderBy 90 keeps it last if it is ever surfaced internally.
INSERT INTO sett."SettingGroups" (
    "SettingGroupName", "SettingGroupCode", "SettingGroupIcon",
    "IsVisibleInUI", "OrderBy",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT 'Platform Control Plane', 'PLATFORM', 'ph-buildings',
       FALSE, 90,
       NULL, now(), NULL, NULL, TRUE, FALSE
WHERE NOT EXISTS (
    SELECT 1 FROM sett."SettingGroups"
    WHERE "SettingGroupCode" = 'PLATFORM' AND "IsDeleted" = FALSE
);


-- ── 2. sett.OrganizationSettings — 3 platform-global rows ─────────────────────────────────────
--
--  PLATFORM_DISCOUNT_APPROVAL_THRESHOLD_PCT
--      Read by LeadHelper.GetDiscountApprovalThresholdAsync at SubmitCommercialTerm time.
--      DiscountPercent <= threshold  → DRAFT auto-transitions to APPROVED;
--      DiscountPercent >  threshold  → DRAFT transitions to PENDING_APPROVAL.
--      CurrentValue wins over ParamDefaultValue. When the row is absent the code falls back to
--      LeadHelper.DefaultDiscountThresholdPct (15m) — the fallback exists only so a fresh database
--      cannot auto-approve an unbounded discount; this row is the real policy.
--
--  PLATFORM_ACTIVATION_URL_TEMPLATE
--      Read by ProvisionTenantCommandHandler.BuildActivationUrlAsync (step 9). Tokens:
--      {SUBDOMAIN} {LANG} {TOKEN}. The path segment /activate?token= is the REAL Next.js route
--      (src/app/[lang]/(auth)/activate) minted by P-04 — it is not invented here.
--      Absent/blank ⇒ the single-host appsettings Frontend:BaseUrl is used instead (that value
--      already carries the /{lang} segment), so a single-host dev environment needs no row.
--      Adjust the apex domain below to the real tenant wildcard host before applying.
--
--  PLATFORM_DEFAULT_LANG
--      The {LANG} segment substituted into the pattern above. 'en' matches the Frontend:BaseUrl
--      default.
--
--  CanUserOverride = FALSE on all three: a tenant user must never shadow control-plane policy
--  with a UserSetting row.
WITH g AS (
    SELECT "SettingGroupId"
    FROM sett."SettingGroups"
    WHERE "SettingGroupCode" = 'PLATFORM' AND "IsDeleted" = FALSE
    LIMIT 1
),
codes(param_code, param_name, data_type, default_value, description) AS (
    VALUES
        ('PLATFORM_DISCOUNT_APPROVAL_THRESHOLD_PCT',
         'Platform Discount Approval Threshold Pct',
         'DECIMAL',
         '15',
         'Maximum discount percent a commercial term may carry and still auto-approve on submit. Above this the deal moves to PENDING_APPROVAL and needs PLATFORM_DEAL_APPROVE.'),

        ('PLATFORM_ACTIVATION_URL_TEMPLATE',
         'Platform Activation Url Template',
         'STRING',
         'https://{SUBDOMAIN}.peopleserve.app/{LANG}/activate?token={TOKEN}',
         'Pattern for the passwordless tenant-administrator activation link. Tokens: {SUBDOMAIN} {LANG} {TOKEN}. Blank falls back to the appsettings Frontend:BaseUrl single host.'),

        ('PLATFORM_DEFAULT_LANG',
         'Platform Default Lang',
         'STRING',
         'en',
         'Language segment substituted for {LANG} in the activation link.')
)
INSERT INTO sett."OrganizationSettings" (
    "CompanyId", "SettingGroupId", "ParamName", "ParamCode",
    "ParamDataType", "AllValues", "ParamDefaultValue", "CurrentValue",
    "Description", "CanUserOverride",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT
    NULL,                       -- platform-global: no tenant owns these
    g."SettingGroupId",
    c.param_name,
    c.param_code,
    c.data_type,
    NULL,
    c.default_value,
    NULL,                       -- CurrentValue left NULL → ParamDefaultValue is the live value
    c.description,
    FALSE,
    2, now(), NULL, NULL, TRUE, FALSE
FROM codes c
CROSS JOIN g
WHERE NOT EXISTS (
    SELECT 1 FROM sett."OrganizationSettings" s
    WHERE s."CompanyId" IS NULL
      AND s."ParamCode" = c.param_code
      AND s."IsDeleted" = FALSE
);


-- ── 3. sett.MasterDatas — EMAILCATEGORY value PLATFORMEMAIL ───────────────────────────────────
-- EmailCategoryId != 2 → EmailTemplateService renders the body from the EmailContent COLUMN.
-- A dedicated category (rather than reusing a tenant-facing one) keeps control-plane mail out of
-- the tenant Email Template screen's category filters.
INSERT INTO sett."MasterDatas"(
    "MasterDataTypeId", "DataName", "DataValue", "DataSetting",
    "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "IsSystem")
SELECT
    (SELECT "MasterDataTypeId" FROM sett."MasterDataTypes" WHERE "TypeCode" = 'EMAILCATEGORY'),
    'Platform Email',
    'PLATFORMEMAIL',
    'Platform Email',
    20,
    2, now(), NULL, NULL,
    TRUE, FALSE, TRUE
WHERE NOT EXISTS (
    SELECT 1
    FROM sett."MasterDatas" md
    JOIN sett."MasterDataTypes" mdt ON mdt."MasterDataTypeId" = md."MasterDataTypeId"
    WHERE mdt."TypeCode" = 'EMAILCATEGORY'
      AND md."DataValue" = 'PLATFORMEMAIL'
);


-- ── 4. notify.EmailTemplates — TENANT_ADMIN_ACTIVATION ────────────────────────────────────────
--
-- Sent by ProvisionTenantCommandHandler step 9 via
--   IEmailTemplateService.SendEmailByTemplateKeyAsync(dto, placeholders, 'TENANT_ADMIN_ACTIVATION', moduleId, true)
--
-- Placeholders supplied by step 9 — every token below MUST be one of these, because
-- PlaceholderEngine renders an unknown token as an EMPTY STRING (silent, not an error):
--   {{USER_NAME}}  {{COMPANY_NAME}}  {{SUBDOMAIN}}  {{ACTIVATION_LINK}}  {{EXPIRY_DATE}}  {{CURRENT_YEAR}}
--
-- NO PASSWORD ANYWHERE — the tenant administrator sets their own via the activation link, which
-- carries the live reset token minted in step 8 (read, never re-minted, so a resumed run is safe).
--
-- ModuleId  → the PLATFORM module (resolved by ModuleCode, env-agnostic). Step 9 reads ModuleId
--             back OFF THIS ROW before calling the service, so re-pointing the template at another
--             module here cannot desynchronise the lookup.
-- CompanyId → 3, the global reference row: notify."EmailTemplates"."CompanyId" is a non-nullable
--             FK to Company, so a "platform" template still has to name one. The service's lookup
--             is EmailTemplateCode + ModuleId + IsActive, with no CompanyId predicate, so the value
--             is bookkeeping only. Change 3 if that reference company differs in your environment.
INSERT INTO "notify"."EmailTemplates"(
    "EmailTemplateCode", "EmailTemplateName", "EmailSubject", "EmailContent",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "ModuleId", "EmailCategoryId", "CompanyId")
SELECT
    'TENANT_ADMIN_ACTIVATION',
    'Tenant Admin Activation',
    'Activate your {{COMPANY_NAME}} workspace',
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
        <tr><td style="background-color:#4338ca;padding:36px 40px;text-align:center;">
          <div style="width:52px;height:52px;line-height:52px;margin:0 auto 12px auto;
                      border-radius:50%;background-color:rgba(255,255,255,0.18);
                      color:#ffffff;font-size:26px;font-weight:800;">&#128274;</div>
          <div style="font-size:12px;letter-spacing:3px;text-transform:uppercase;color:#c7d2fe;font-weight:700;">
            Workspace Ready
          </div>
          <div style="font-size:24px;line-height:1.3;color:#ffffff;font-weight:800;margin-top:8px;">
            Activate Your Account
          </div>
        </td></tr>

        <!-- Body -->
        <tr><td style="padding:32px 40px 8px 40px;">
          <p style="margin:0 0 16px 0;font-size:15px;color:#0f172a;">Hello {{USER_NAME}},</p>
          <p style="margin:0 0 24px 0;font-size:14px;line-height:1.7;color:#475569;">
            The workspace for <strong>{{COMPANY_NAME}}</strong> has been set up and you have been
            made its administrator. Choose your own password using the secure link below — we never
            send passwords by email.
          </p>

          <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                 style="background-color:#eef2ff;border:1px solid #c7d2fe;border-radius:10px;">
            <tr><td style="padding:14px 20px;border-bottom:1px solid #c7d2fe;">
              <div style="font-size:11px;letter-spacing:1px;text-transform:uppercase;color:#3730a3;font-weight:700;">Workspace Address</div>
              <div style="font-size:14px;color:#0f172a;font-weight:600;margin-top:4px;">{{SUBDOMAIN}}</div>
            </td></tr>
            <tr><td style="padding:14px 20px;">
              <div style="font-size:11px;letter-spacing:1px;text-transform:uppercase;color:#3730a3;font-weight:700;">Link Valid Until</div>
              <div style="font-size:14px;color:#0f172a;font-weight:600;margin-top:4px;">{{EXPIRY_DATE}}</div>
            </td></tr>
          </table>

          <!-- CTA -->
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:28px 0 8px 0;">
            <tr><td align="center">
              <a href="{{ACTIVATION_LINK}}"
                 style="display:inline-block;padding:14px 36px;background-color:#4338ca;color:#ffffff;
                        font-size:15px;font-weight:700;text-decoration:none;border-radius:8px;">
                Set My Password
              </a>
            </td></tr>
          </table>

          <p style="margin:16px 0 24px 0;font-size:12px;line-height:1.6;color:#94a3b8;text-align:center;">
            Button not working? Paste this address into your browser:<br>
            <span style="color:#4338ca;word-break:break-all;">{{ACTIVATION_LINK}}</span>
          </p>

          <p style="margin:0 0 24px 0;font-size:13px;line-height:1.7;color:#475569;">
            If you were not expecting this email you can safely ignore it — the link expires on its
            own and no account is usable until a password is set.
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
    SELECT 1 FROM "notify"."EmailTemplates" WHERE "EmailTemplateCode" = 'TENANT_ADMIN_ACTIVATION'
);

-- ── 5. Lookup grants for the control-plane surface ───────────────────────────────────────────
--  S-02 (deal) and O-01 (wizard) need the Country and Currency pickers. Those resolvers are
--  [CustomAuthorize("COUNTRY","READ")] / ("CURRENCY","READ") — tenant-module menus that the P-03
--  platform RBAC seed does not grant, so a platform user would 403 on the dropdown even though
--  com.Countries / com.Currencies are global reference data.
--
--  This grants READ ONLY, and only to the three platform roles that actually open those screens.
--  No new menu, no new capability — just RoleCapability rows against menus that already exist.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_SALES',          'COUNTRY',  'READ'),
  ('PLATFORM_SALES',          'CURRENCY', 'READ'),
  ('PLATFORM_IMPLEMENTATION', 'COUNTRY',  'READ'),
  ('PLATFORM_IMPLEMENTATION', 'CURRENCY', 'READ'),
  ('PLATFORM_FINANCE',        'COUNTRY',  'READ'),
  ('PLATFORM_FINANCE',        'CURRENCY', 'READ'),
  ('PLATFORM_ADMIN',          'COUNTRY',  'READ'),
  ('PLATFORM_ADMIN',          'CURRENCY', 'READ')
) AS v(role_code, menu_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = v.role_code AND r."CompanyId" IS NULL
JOIN auth."Menus"        m ON m."MenuCode" = v.menu_code
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--
--   -- 8 lookup grants (COUNTRY/CURRENCY READ) on the 4 lead-facing platform roles
--   SELECT r."RoleCode", m."MenuCode", c."CapabilityCode"
--   FROM auth."RoleCapabilities" rc
--   JOIN auth."Roles" r ON r."RoleId" = rc."RoleId" AND r."CompanyId" IS NULL
--   JOIN auth."Menus" m ON m."MenuId" = rc."MenuId"
--   JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--   WHERE m."MenuCode" IN ('COUNTRY','CURRENCY') AND r."RoleCode" LIKE 'PLATFORM\_%'
--   ORDER BY r."RoleCode", m."MenuCode";
--
--
--   -- 3 platform-global settings, CompanyId IS NULL, in the hidden PLATFORM group
--   SELECT s."ParamCode", s."ParamDefaultValue", s."CurrentValue", g."SettingGroupCode"
--   FROM sett."OrganizationSettings" s
--   JOIN sett."SettingGroups" g ON g."SettingGroupId" = s."SettingGroupId"
--   WHERE s."CompanyId" IS NULL AND s."ParamCode" LIKE 'PLATFORM\_%' AND s."IsDeleted" = FALSE
--   ORDER BY s."ParamCode";
--
--   -- the activation template exists, is active, hangs off PLATFORM and has no password token
--   SELECT t."EmailTemplateCode", t."EmailSubject", m."ModuleCode", md."DataValue" AS category,
--          (t."EmailContent" ILIKE '%password%recovery%' OR t."EmailContent" LIKE '%{{TEMP_PASSWORD}}%') AS has_password_token
--   FROM notify."EmailTemplates" t
--   JOIN auth."Modules" m ON m."ModuleId" = t."ModuleId"
--   LEFT JOIN sett."MasterDatas" md ON md."MasterDataId" = t."EmailCategoryId"
--   WHERE t."EmailTemplateCode" = 'TENANT_ADMIN_ACTIVATION';
--
--   -- USER_WELCOME_INVITE must be UNTOUCHED by this script (row count and content unchanged)
--   SELECT count(*) FROM notify."EmailTemplates" WHERE "EmailTemplateCode" = 'USER_WELCOME_INVITE';
-- =====================================================================================
