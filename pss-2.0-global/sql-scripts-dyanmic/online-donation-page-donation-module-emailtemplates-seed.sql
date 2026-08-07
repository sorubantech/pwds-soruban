-- ============================================================
-- Screen #10 Online Donation Page — DONATION module + Email Templates Seed
-- Feature: ISSUE-47b (PLAN67 revision, 2026-07-17)
--
-- Purpose:
--   The public donation flow (ConfirmOnlineDonation) issues a tax receipt email.
--   ISSUE-47b makes that email TEMPLATE-DRIVEN: the admin Comms tab lets staff pick
--   a curated DONATION-module EmailTemplate (COMM_RECEIPT / COMM_THANKYOU EAV codes),
--   and ConfirmOnlineDonation resolves the DONATION ModuleId at runtime by
--   ModuleCode == 'DONATION' (mirroring Grant's CRM-by-code pattern), then sends via
--   IEmailTemplateService.SendEmailByTemplateKeyForCompanyAsync. It NEVER reuses
--   Grant's CRM ModuleId. When no template is curated / seeded it falls back to a
--   hardcoded composed email — so this seed is what makes the template PATH live.
--
-- Seeds:
--   STEP 1 — auth.Modules            : get-or-create the DONATION module (defensive).
--   STEP 2 — sett.MasterDatas        : new EMAILCATEGORY value  →  DONATIONEMAIL
--                                       (any category != 2 makes the template render
--                                        from the EmailContent COLUMN, not a file).
--   STEP 3 — notify.EmailTemplates   : 2 default donor-facing templates
--                                        DONATION_RECEIPT   (receipt + PDF attachment)
--                                        DONATION_THANKYOU  (thank-you)
--   STEP 4 — verification (read-only).
--
-- Placeholder syntax: {{Token}} — tokens MUST match the ConfirmOnlineDonation
--   placeholder dictionary: {{DonorName}} {{FirstName}} {{LastName}}
--   {{ReceiptNumber}} {{Amount}} {{DonationAmount}} {{Email}}.
--   The receipt PDF is attached by the BE (emailDto.AttachmentPath) — NOT by the template.
--
-- Notes:
--   • DONATION module: the live DB already carries it (dozens of grid/menu seeds resolve
--     auth."Modules" WHERE "ModuleCode" = 'DONATION'). STEP 1 is a defensive get-or-create
--     so a fresh DB also gets a DONATION module; on the live DB the NOT EXISTS guard is a
--     harmless no-op and the existing ModuleId (and its Guid) are preserved.
--   • CompanyId = 3 (global reference row). Template lookup in EmailTemplateService is by
--     EmailTemplateCode + ModuleId + IsActive (company-agnostic), matching the Grant seed.
--   • Idempotent — WHERE NOT EXISTS guard on every INSERT; safe to re-run.
--   • PostgreSQL syntax: now(), double-quoted identifiers, TRUE/FALSE.
--   • USER-OWNED: I write this file; the user reviews and applies it. Run STEP 1→2→3→4.
-- ============================================================

BEGIN;

-- ============================================================
-- STEP 1 — auth.Modules — get-or-create the DONATION module
--   Fixed literal Guid used ONLY on a fresh DB where the row is absent; on the live DB
--   the NOT EXISTS guard skips this insert and the existing DONATION ModuleId stands.
--   ModuleCode='DONATION' is the stable key ConfirmOnlineDonation resolves at runtime.
-- ============================================================
INSERT INTO auth."Modules"(
    "ModuleId", "ModuleName", "ModuleCode", "ModuleUrl", "ModuleIcon", "Description",
    "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT
    'd0a7e5c2-4b31-4f8a-9c6e-1f2a3b4c5d6e'::uuid,
    'Donation', 'DONATION', 'crm/donation', 'solar:hand-money-bold',
    'Online donations, receipts and donor communication', 20,
    2, now(), null, null, TRUE, FALSE
WHERE NOT EXISTS (
    SELECT 1 FROM auth."Modules" WHERE "ModuleCode" = 'DONATION'
);


-- ============================================================
-- STEP 2 — sett.MasterDatas — new EMAILCATEGORY value: DONATIONEMAIL
--   EmailCategoryId != 2 → EmailTemplateService renders from the EmailContent COLUMN
--   (not a file-backed EmailContentPath). Mirrors the Grant seed's category approach.
-- ============================================================
INSERT INTO sett."MasterDatas"(
    "MasterDataTypeId", "DataName", "DataValue", "DataSetting",
    "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "IsSystem")
SELECT
    (SELECT "MasterDataTypeId" FROM sett."MasterDataTypes" WHERE "TypeCode" = 'EMAILCATEGORY'),
    'Donation Email',
    'DONATIONEMAIL',
    'Donation Email',
    12,
    2, now(), null, null,
    TRUE, FALSE, TRUE
WHERE NOT EXISTS (
    SELECT 1
    FROM sett."MasterDatas" md
    JOIN sett."MasterDataTypes" mdt ON mdt."MasterDataTypeId" = md."MasterDataTypeId"
    WHERE mdt."TypeCode" = 'EMAILCATEGORY'
      AND md."DataValue" = 'DONATIONEMAIL'
);


-- ============================================================
-- STEP 3 — notify.EmailTemplates — 2 donor-facing DONATION templates
--
-- ModuleId        → DONATION module (resolved by ModuleCode — NEVER CRM)
-- EmailCategoryId → EMAILCATEGORY.DONATIONEMAIL subquery (no hardcoded ID; != 2 → column body)
-- CompanyId       → 3 (global row — template lookup is by code + ModuleId + IsActive)
-- ============================================================

-- 3a. DONATION_RECEIPT
--     Sent by ConfirmOnlineDonation after a successful capture. The tax-receipt PDF is
--     attached by the BE (emailDto.AttachmentPath); this template is the covering message.
--     Default target of the admin Comms "Receipt email template" picker (COMM_RECEIPT).
-- ============================================================
INSERT INTO "notify"."EmailTemplates"(
    "EmailTemplateCode", "EmailTemplateName", "EmailSubject", "EmailContent",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "ModuleId", "EmailCategoryId", "CompanyId")
SELECT
    'DONATION_RECEIPT',
    'Donation Receipt',
    'Your donation receipt — {{ReceiptNumber}}',
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
        <tr><td style="background-color:#15803d;padding:36px 40px;text-align:center;">
          <div style="width:52px;height:52px;line-height:52px;margin:0 auto 12px auto;
                      border-radius:50%;background-color:rgba(255,255,255,0.18);
                      color:#ffffff;font-size:26px;font-weight:800;">&#10003;</div>
          <div style="font-size:12px;letter-spacing:3px;text-transform:uppercase;color:#bbf7d0;font-weight:700;">
            Receipt
          </div>
          <div style="font-size:24px;line-height:1.3;color:#ffffff;font-weight:800;margin-top:8px;">
            Thank You for Your Donation
          </div>
        </td></tr>

        <!-- Body -->
        <tr><td style="padding:32px 40px 8px 40px;">
          <p style="margin:0 0 16px 0;font-size:15px;color:#0f172a;">Dear {{DonorName}},</p>
          <p style="margin:0 0 24px 0;font-size:14px;line-height:1.7;color:#475569;">
            Thank you for your generous donation. Your official tax receipt is attached to this
            email as a PDF. A summary of your gift is below.
          </p>
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                 style="background-color:#f0fdf4;border:1px solid #bbf7d0;border-radius:10px;">
            <tr><td style="padding:14px 20px;border-bottom:1px solid #bbf7d0;">
              <div style="font-size:11px;letter-spacing:1px;text-transform:uppercase;color:#166534;font-weight:700;">Receipt Number</div>
              <div style="font-size:14px;color:#0f172a;font-weight:600;margin-top:4px;">{{ReceiptNumber}}</div>
            </td></tr>
            <tr><td style="padding:14px 20px;">
              <div style="font-size:11px;letter-spacing:1px;text-transform:uppercase;color:#166534;font-weight:700;">Amount</div>
              <div style="font-size:14px;color:#0f172a;font-weight:600;margin-top:4px;">{{Amount}}</div>
            </td></tr>
          </table>
        </td></tr>

        <!-- Footer -->
        <tr><td style="background-color:#0f172a;padding:20px 40px;text-align:center;margin-top:24px;">
          <p style="margin:0;font-size:12px;color:#94a3b8;">
            This is an automated message — please do not reply.
          </p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>',
    2, now(), null, null, TRUE, FALSE,
    (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = 'DONATION'),
    (SELECT md."MasterDataId"
       FROM sett."MasterDatas" md
       JOIN sett."MasterDataTypes" mdt ON mdt."MasterDataTypeId" = md."MasterDataTypeId"
      WHERE mdt."TypeCode" = 'EMAILCATEGORY' AND md."DataValue" = 'DONATIONEMAIL'
      LIMIT 1),
    3
WHERE NOT EXISTS (
    SELECT 1 FROM "notify"."EmailTemplates" WHERE "EmailTemplateCode" = 'DONATION_RECEIPT'
);


-- 3b. DONATION_THANKYOU
--     A softer thank-you variant (no receipt framing). Default target of the admin Comms
--     "Thank-you email template" picker (COMM_THANKYOU).
-- ============================================================
INSERT INTO "notify"."EmailTemplates"(
    "EmailTemplateCode", "EmailTemplateName", "EmailSubject", "EmailContent",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "ModuleId", "EmailCategoryId", "CompanyId")
SELECT
    'DONATION_THANKYOU',
    'Donation Thank-You',
    'Thank you for your donation',
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
        <tr><td style="background-color:#7c3aed;padding:36px 40px;text-align:center;">
          <div style="font-size:12px;letter-spacing:3px;text-transform:uppercase;color:#ddd6fe;font-weight:700;">
            With Gratitude
          </div>
          <div style="font-size:24px;line-height:1.3;color:#ffffff;font-weight:800;margin-top:10px;">
            Thank You, {{FirstName}}
          </div>
        </td></tr>

        <!-- Body -->
        <tr><td style="padding:32px 40px 8px 40px;">
          <p style="margin:0 0 16px 0;font-size:15px;color:#0f172a;">Dear {{DonorName}},</p>
          <p style="margin:0 0 24px 0;font-size:14px;line-height:1.7;color:#475569;">
            Your gift of <strong style="color:#7c3aed;">{{Amount}}</strong> makes a real difference.
            Thank you for standing with us — your generosity directly supports the people and
            causes we serve.
          </p>
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                 style="background-color:#faf5ff;border:1px solid #ddd6fe;border-radius:10px;">
            <tr><td style="padding:14px 20px;">
              <div style="font-size:11px;letter-spacing:1px;text-transform:uppercase;color:#6d28d9;font-weight:700;">Reference</div>
              <div style="font-size:14px;color:#0f172a;font-weight:600;margin-top:4px;">{{ReceiptNumber}}</div>
            </td></tr>
          </table>
        </td></tr>

        <!-- Footer -->
        <tr><td style="background-color:#0f172a;padding:20px 40px;text-align:center;margin-top:24px;">
          <p style="margin:0;font-size:12px;color:#94a3b8;">
            This is an automated message — please do not reply.
          </p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>',
    2, now(), null, null, TRUE, FALSE,
    (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = 'DONATION'),
    (SELECT md."MasterDataId"
       FROM sett."MasterDatas" md
       JOIN sett."MasterDataTypes" mdt ON mdt."MasterDataTypeId" = md."MasterDataTypeId"
      WHERE mdt."TypeCode" = 'EMAILCATEGORY' AND md."DataValue" = 'DONATIONEMAIL'
      LIMIT 1),
    3
WHERE NOT EXISTS (
    SELECT 1 FROM "notify"."EmailTemplates" WHERE "EmailTemplateCode" = 'DONATION_THANKYOU'
);


COMMIT;


-- ============================================================
-- STEP 4 — Verification queries (read-only — run to confirm seed)
-- ============================================================

-- 4a. Confirm a DONATION module exists (live DB row OR the fresh-DB fallback).
SELECT
    'STEP 4a — DONATION module' AS check,
    "ModuleId", "ModuleName", "ModuleCode", "ModuleUrl", "IsActive"
FROM auth."Modules"
WHERE "ModuleCode" = 'DONATION';

-- 4b. Confirm DONATIONEMAIL category seeded under EMAILCATEGORY.
SELECT
    'STEP 4b — EMAILCATEGORY value' AS check,
    md."MasterDataId", md."DataName", md."DataValue", md."IsActive"
FROM sett."MasterDatas" md
JOIN sett."MasterDataTypes" mdt ON mdt."MasterDataTypeId" = md."MasterDataTypeId"
WHERE mdt."TypeCode" = 'EMAILCATEGORY'
  AND md."DataValue" = 'DONATIONEMAIL';

-- 4c. Confirm both donation templates seeded and bound to the DONATION module.
SELECT
    'STEP 4c — Donation EmailTemplates' AS check,
    et."EmailTemplateId", et."EmailTemplateCode", et."EmailTemplateName",
    et."EmailSubject", m."ModuleCode" AS module, et."IsActive"
FROM "notify"."EmailTemplates" et
JOIN auth."Modules" m ON m."ModuleId" = et."ModuleId"
WHERE et."EmailTemplateCode" IN ('DONATION_RECEIPT', 'DONATION_THANKYOU')
ORDER BY et."EmailTemplateCode";

-- ============================================================
-- Placeholder tokens reference (must match ConfirmOnlineDonation dictionary):
--   DONATION_RECEIPT   → {{DonorName}} {{ReceiptNumber}} {{Amount}}
--   DONATION_THANKYOU  → {{DonorName}} {{FirstName}} {{Amount}} {{ReceiptNumber}}
--   (also available: {{LastName}} {{DonationAmount}} {{Email}})
-- The receipt PDF is attached by the BE (emailDto.AttachmentPath), not by the template.
-- ============================================================
-- END online-donation-page-donation-module-emailtemplates-seed.sql
-- ============================================================
