-- =====================================================================================
--  P-20 §④ step 5 — the internal alert raised when a stranger fills in the product page.
--
--  USER-OWNED: this file is written here and applied by the user. It is never executed from code.
--  PREREQUISITE: run AFTER ops-platform-rbac-seed.sql (the PLATFORM module) and
--                ops-lead-deal-seed.sql (the PLATFORM setting group + the PLATFORMEMAIL category).
--                Sections 1 and 2 below are guarded no-ops if those already ran.
--
--  WHAT THIS SEEDS
--    1. sett."MasterDatas"          — EMAILCATEGORY / PLATFORMEMAIL, only if ops-lead-deal-seed.sql
--                                     has not already created it.
--    2. sett."OrganizationSettings" — PLATFORM_LEAD_NOTIFICATION_EMAIL, the sales inbox.
--    3. notify."EmailTemplates"     — PLATFORM_LEAD_ENQUIRY_NOTIFICATION, the alert body.
--
--  WHO READS THEM
--  SubmitProductEnquiryHandler.NotifySalesAsync, immediately after the Lead row is committed. It
--  reads the recipient via LeadHelper.GetPlatformSettingAsync, resolves the ModuleId back OFF the
--  template row, and calls IEmailTemplateService.SendEmailByTemplateKeyAsync — the only path that
--  resolves ops."PlatformCommunicationProviders" for a tenant-less send. Both other composed-body
--  methods on that service demand a companyId, and there is no tenant on an anonymous submission.
--
--  THE ALERT IS BEST-EFFORT AND MUST STAY THAT WAY.
--  If section 2 is skipped, no recipient is configured and NO MAIL IS SENT — the enquiry is still
--  stored and the visitor still sees the thank-you. Same if this whole file is never applied: the
--  handler logs and swallows every failure. A mail outage must never cost us a lead. The consequence
--  is that nobody is notified, so leads sit unseen in /ops/leads until someone looks — set section 2
--  to a REAL monitored inbox before launch, and check /ops/leads regardless.
--
--  PLACEHOLDERS — the template may reference these twelve and nothing else. PlaceholderEngine
--  renders an unknown token as an EMPTY STRING, silently, so a typo here is invisible at runtime:
--    {{ORGANIZATION_NAME}} {{CONTACT_NAME}} {{CONTACT_EMAIL}} {{CONTACT_PHONE}} {{COUNTRY_NAME}}
--    {{INDUSTRY}} {{ORGANIZATION_SIZE}} {{WEBSITE}} {{NOTES}} {{SUBMITTED_AT}} {{LEAD_ID}}
--    {{CURRENT_YEAR}}
--  The handler supplies ALL twelve on every send, blank rather than missing, precisely because
--  PlaceholderEngine has NO {{#if}} support — a conditional block's BODY renders even when its
--  token is empty, so optional fields cannot be suppressed. Hence the layout below labels every
--  optional row unconditionally and simply shows it empty. Do NOT add {{#if}} markers to this file.
--
--  Idempotent: every INSERT is guarded on its natural code key. Additive only — no DROP, no UPDATE,
--  no schema change.
-- =====================================================================================

BEGIN;

-- ── 1. sett.MasterDatas — EMAILCATEGORY value PLATFORMEMAIL ─────────────────────────
-- Almost certainly already present from ops-lead-deal-seed.sql section 3; repeated here so this
-- file stands alone if that one is ever retired. EmailCategoryId != 2 makes EmailTemplateService
-- render the body from the EmailContent COLUMN rather than a file template.
INSERT INTO sett."MasterDatas"(
    "MasterDataTypeId", "DataName", "DataValue", "DataSetting",
    "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "IsSystem")
SELECT
    (SELECT "MasterDataTypeId" FROM sett."MasterDataTypes" WHERE "TypeCode" = 'EMAILCATEGORY'),
    'Platform Email', 'PLATFORMEMAIL', 'Platform Email',
    20,
    2, now(), NULL, NULL,
    TRUE, FALSE, TRUE
WHERE NOT EXISTS (
    SELECT 1
    FROM sett."MasterDatas" md
    JOIN sett."MasterDataTypes" mdt ON mdt."MasterDataTypeId" = md."MasterDataTypeId"
    WHERE mdt."TypeCode" = 'EMAILCATEGORY' AND md."DataValue" = 'PLATFORMEMAIL'
);


-- ── 2. sett.OrganizationSettings — PLATFORM_LEAD_NOTIFICATION_EMAIL ─────────────────
--
--  Platform-global (CompanyId IS NULL) because an anonymous submission has no tenant: at
--  NotifySalesAsync time CurrentTenantId is null, and LeadHelper.GetPlatformSettingAsync reads
--  with .IgnoreQueryFilters() + CompanyId IS NULL. Never fanned out per tenant.
--
--  CanUserOverride = FALSE: a tenant user must not be able to redirect the platform's own sales
--  alerts by shadowing this with a UserSetting row.
--
--  ⚠ CHANGE THE ADDRESS BELOW BEFORE APPLYING. The default is a placeholder and mail sent to it
--  goes nowhere. A single address is intentional — the handler passes it as EmailDto.ToEmail, one
--  recipient. Use a distribution list if more than one person should see enquiries.
--
--  Blank or absent ⇒ the handler logs "No PLATFORM_LEAD_NOTIFICATION_EMAIL configured", sends
--  nothing, and returns success. The lead is stored either way.
WITH g AS (
    SELECT "SettingGroupId"
    FROM sett."SettingGroups"
    WHERE "SettingGroupCode" = 'PLATFORM' AND "IsDeleted" = FALSE
    LIMIT 1
),
codes(param_code, param_name, data_type, default_value, description) AS (
    VALUES
        ('PLATFORM_LEAD_NOTIFICATION_EMAIL',
         'Platform Lead Notification Email',
         'STRING',
         'sales@pwdatasolutions.com',
         'Inbox that receives the alert when an anonymous visitor submits the product page enquiry form. Blank or absent means no alert is sent; the lead is still stored.')
)
INSERT INTO sett."OrganizationSettings" (
    "CompanyId", "SettingGroupId", "ParamName", "ParamCode",
    "ParamDataType", "AllValues", "ParamDefaultValue", "CurrentValue",
    "Description", "CanUserOverride",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT
    NULL,                       -- platform-global: no tenant owns this
    g."SettingGroupId",
    c.param_name,
    c.param_code,
    c.data_type,
    NULL,
    c.default_value,
    NULL,                       -- CurrentValue NULL → ParamDefaultValue is the live value
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


-- ── 3. notify.EmailTemplates — PLATFORM_LEAD_ENQUIRY_NOTIFICATION ───────────────────
--
--  ModuleId  → the PLATFORM module, resolved by ModuleCode so the file is environment-agnostic.
--              NotifySalesAsync reads ModuleId back OFF THIS ROW before calling the service, so
--              re-pointing the template at a different module here cannot desynchronise the lookup.
--  CompanyId → 3, the global reference row. notify."EmailTemplates"."CompanyId" is a non-nullable
--              FK to Company, so even a platform template must name one; the service's lookup is
--              EmailTemplateCode + ModuleId + IsActive with no CompanyId predicate, so the value is
--              bookkeeping only. Change 3 if that reference company differs in your environment.
--
--  This is an INTERNAL email — it is read by our own sales team, never by the prospect. Hence the
--  dense label/value layout, the raw LeadId, and the direct link into the control plane. The
--  prospect receives nothing at all from this flow; the page's own success state is their receipt.
INSERT INTO "notify"."EmailTemplates"(
    "EmailTemplateCode", "EmailTemplateName", "EmailSubject", "EmailContent",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "ModuleId", "EmailCategoryId", "CompanyId")
SELECT
    'PLATFORM_LEAD_ENQUIRY_NOTIFICATION',
    'Platform Lead Enquiry Notification',
    'New product enquiry — {{ORGANIZATION_NAME}}',
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
        <tr><td style="background-color:#0f766e;padding:28px 40px;">
          <div style="font-size:11px;letter-spacing:3px;text-transform:uppercase;color:#99f6e4;font-weight:700;">
            Inbound Lead
          </div>
          <div style="font-size:22px;line-height:1.3;color:#ffffff;font-weight:800;margin-top:6px;">
            {{ORGANIZATION_NAME}}
          </div>
          <div style="font-size:12px;color:#99f6e4;margin-top:6px;">
            Submitted {{SUBMITTED_AT}} &nbsp;&middot;&nbsp; Lead #{{LEAD_ID}}
          </div>
        </td></tr>

        <!-- Who -->
        <tr><td style="padding:28px 40px 8px 40px;">
          <div style="font-size:11px;letter-spacing:1px;text-transform:uppercase;color:#0f766e;font-weight:700;margin-bottom:12px;">
            Contact
          </div>
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="font-size:14px;color:#0f172a;">
            <tr>
              <td style="padding:8px 0;width:170px;color:#64748b;font-size:13px;">Name</td>
              <td style="padding:8px 0;font-weight:600;">{{CONTACT_NAME}}</td>
            </tr>
            <tr>
              <td style="padding:8px 0;color:#64748b;font-size:13px;">Email</td>
              <td style="padding:8px 0;font-weight:600;">
                <a href="mailto:{{CONTACT_EMAIL}}" style="color:#0f766e;text-decoration:none;">{{CONTACT_EMAIL}}</a>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 0;color:#64748b;font-size:13px;">Phone</td>
              <td style="padding:8px 0;font-weight:600;">{{CONTACT_PHONE}}</td>
            </tr>
          </table>
        </td></tr>

        <!-- Organisation -->
        <tr><td style="padding:20px 40px 8px 40px;">
          <div style="font-size:11px;letter-spacing:1px;text-transform:uppercase;color:#0f766e;font-weight:700;margin-bottom:12px;">
            Organisation
          </div>
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                 style="font-size:14px;color:#0f172a;background-color:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;">
            <tr>
              <td style="padding:12px 18px;width:170px;color:#64748b;font-size:13px;border-bottom:1px solid #e2e8f0;">Country</td>
              <td style="padding:12px 18px;font-weight:600;border-bottom:1px solid #e2e8f0;">{{COUNTRY_NAME}}</td>
            </tr>
            <tr>
              <td style="padding:12px 18px;color:#64748b;font-size:13px;border-bottom:1px solid #e2e8f0;">Sector</td>
              <td style="padding:12px 18px;font-weight:600;border-bottom:1px solid #e2e8f0;">{{INDUSTRY}}</td>
            </tr>
            <tr>
              <td style="padding:12px 18px;color:#64748b;font-size:13px;border-bottom:1px solid #e2e8f0;">Size</td>
              <td style="padding:12px 18px;font-weight:600;border-bottom:1px solid #e2e8f0;">{{ORGANIZATION_SIZE}}</td>
            </tr>
            <tr>
              <td style="padding:12px 18px;color:#64748b;font-size:13px;">Website</td>
              <td style="padding:12px 18px;font-weight:600;word-break:break-all;">{{WEBSITE}}</td>
            </tr>
          </table>
        </td></tr>

        <!-- What they said -->
        <tr><td style="padding:20px 40px 8px 40px;">
          <div style="font-size:11px;letter-spacing:1px;text-transform:uppercase;color:#0f766e;font-weight:700;margin-bottom:12px;">
            Message
          </div>
          <div style="font-size:14px;line-height:1.7;color:#334155;background-color:#f8fafc;
                      border-left:3px solid #0f766e;border-radius:0 8px 8px 0;padding:14px 18px;
                      white-space:pre-wrap;">{{NOTES}}</div>
        </td></tr>

        <!-- What happens next -->
        <tr><td style="padding:24px 40px 32px 40px;">
          <p style="margin:0;font-size:13px;line-height:1.7;color:#475569;">
            This enquiry is stored as lead <strong>#{{LEAD_ID}}</strong> with status <strong>NEW</strong>.
            Nothing has been provisioned — no workspace, no user account, no subscription. Open it in
            the control plane under Platform &rsaquo; Leads to qualify it.
          </p>
        </td></tr>

        <!-- Footer -->
        <tr><td style="background-color:#0f172a;padding:18px 40px;text-align:center;">
          <p style="margin:0;font-size:12px;color:#94a3b8;">
            &copy; {{CURRENT_YEAR}} PeopleServe &middot; automated internal notification, do not reply.
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
    SELECT 1 FROM "notify"."EmailTemplates" WHERE "EmailTemplateCode" = 'PLATFORM_LEAD_ENQUIRY_NOTIFICATION'
);

COMMIT;


-- =====================================================================================
--  VERIFY (run after COMMIT):
--
--   -- 1. The recipient is configured, and is a REAL monitored inbox:
--   SELECT "ParamCode", COALESCE("CurrentValue","ParamDefaultValue") AS live_value
--     FROM sett."OrganizationSettings"
--    WHERE "ParamCode" = 'PLATFORM_LEAD_NOTIFICATION_EMAIL' AND "CompanyId" IS NULL;
--
--   -- 2. The template exists AND resolved both its FKs (a NULL ModuleId means the PLATFORM module
--   --    is missing — run ops-platform-rbac-seed.sql, then delete this row and re-run this file):
--   SELECT "EmailTemplateCode","ModuleId","EmailCategoryId","IsActive"
--     FROM "notify"."EmailTemplates"
--    WHERE "EmailTemplateCode" = 'PLATFORM_LEAD_ENQUIRY_NOTIFICATION';
--
--   -- 3. No conditional markers slipped into the body (PlaceholderEngine cannot process them):
--   SELECT "EmailTemplateCode" FROM "notify"."EmailTemplates"
--    WHERE "EmailTemplateCode" = 'PLATFORM_LEAD_ENQUIRY_NOTIFICATION'
--      AND "EmailContent" LIKE '%{{#%';
--   -- expect 0 rows.
--
--   -- 4. End to end — POST the anonymous mutation with no Authorization header, then confirm the
--   --    lead landed and the alert arrived:
--   --      mutation { submitProductEnquiry(input: { organizationName: "Test Org", contactName: "Test",
--   --        contactEmail: "test@example.com", countryId: 1, consentGiven: true,
--   --        csrfToken: "test" }) { data { success message } } }
--   SELECT "LeadId","CompanyName","ContactEmail","Source","Status","ConsentedAt","ConsentIpAddress"
--     FROM ops."Leads" ORDER BY "LeadId" DESC LIMIT 5;
--   -- expect Source = INBOUND, Status = NEW, ConsentedAt populated.
--   -- Remember the 24h duplicate window: re-submitting the same address appends to the SAME NEW
--   -- lead's Notes and sends NO second alert. Use a fresh address to test the alert twice.
-- =====================================================================================
