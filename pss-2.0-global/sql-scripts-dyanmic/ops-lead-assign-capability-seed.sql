-- =====================================================================================
-- P-21 — PLATFORM_LEAD_ASSIGN capability + role grants, and the PLATFORM_LEAD_ASSIGNED email template
-- -------------------------------------------------------------------------------------
-- WHY THIS EXISTS
-- Lead ownership now moves through exactly one door (AssignLeadCommand), and that door is guarded by
-- a SPLIT check the RBAC tables have to back:
--
--   [CustomAuthorize("PLATFORM_LEADS","PLATFORM_LEAD_VIEW")]   ← the attribute floor
--        → lets any lead viewer CLAIM an UNOWNED lead FOR THEMSELVES. This is the everyday act the
--          screen exists for; requiring an admin for it would make the pipeline unusable.
--   ICustomAuthorizeService.HasAccessAsync(…, "PLATFORM_LEAD_ASSIGN")  ← checked in the handler
--        → required to assign a lead to SOMEONE ELSE, to reassign a lead that already has an owner,
--          or to unassign one. Taking a deal off a colleague is a management act.
--
-- Without this script the handler check simply fails for everyone, so nobody can reassign — the
-- system stays SAFE but nobody can hand a lead over. Self-claim keeps working either way.
--
-- GRANTS — deliberately narrow:
--   PLATFORM_ADMIN — owns the pipeline; rebalances books when staff join or leave.
--   SUPERADMIN     — superset, mirrors every other platform seed.
--
-- PLATFORM_SALES is NOT granted (P-21 §⑨ Q1). A salesperson can already claim anything unowned; the
-- capability withheld here is the power to take an owned lead OFF a colleague, which is a manager's
-- call. Grant it to PLATFORM_SALES later by adding one VALUES row — the script is re-runnable.
--
-- CAPABILITY NUMBERING — the prompt's "capability id 89" is a misreading of the existing seeds: 86-95
-- are OrderBy values, not CapabilityIds (CapabilityId is a DB identity that no seed ever hardcodes),
-- and OrderBy 89 is already PLATFORM_DEAL_APPROVE. The PLATFORM_* block runs 86-95, then 96
-- PLATFORM_PLAN_VIEW, 97/98 BILLING_*, 100/101 PLATFORM_BILLING_*. This continues at 102.
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on the natural key — re-running is a no-op.
-- SAFE: additive only. No DROP, no UPDATE, no schema change.
-- PREREQUISITE: run AFTER
--   • the Add_LeadAssignment_And_AccountManager migration (§3.7 of P-21),
--   • ops-platform-rbac-seed.sql        — the PLATFORM module, the PLATFORM_LEADS menu, the roles,
--   • ops-lead-deal-seed.sql OR product-enquiry-notification-seed.sql — the EMAILCATEGORY /
--     PLATFORMEMAIL master-data row that section 3 resolves its EmailCategoryId from.
-- If the PLATFORMEMAIL row is missing, section 3 still inserts but with a NULL EmailCategoryId; the
-- mail then renders from a category-supplied layout instead of EmailContent. The VERIFY block below
-- catches it.
-- =====================================================================================

BEGIN;

-- ── 1. Capability ────────────────────────────────────────────────────────────────────────────
-- auth."Capabilities" has a UNIQUE index on (CapabilityName, IsActive), so the guard checks the
-- CONSTRAINED column (CapabilityName), not the code — same rule every other platform seed follows.
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT
  'Platform Assign Leads', 'PLATFORM_LEAD_ASSIGN',
  'Assign a lead to another user, reassign an owned lead, or unassign it. Claiming an unowned lead for yourself needs only PLATFORM_LEAD_VIEW.',
  true, 102,
  now(), true, false
WHERE NOT EXISTS (
  SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = 'Platform Assign Leads'
);

-- ── 2. Role → capability grants on the PLATFORM_LEADS menu ───────────────────────────────────
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT
  r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_ADMIN', 'PLATFORM_LEADS', 'PLATFORM_LEAD_ASSIGN'),
  ('SUPERADMIN',     'PLATFORM_LEADS', 'PLATFORM_LEAD_ASSIGN')
) AS v(role_code, menu_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = v.role_code AND r."CompanyId" IS NULL
JOIN auth."Menus"        m ON m."MenuCode" = v.menu_code
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

-- ── 3. notify.EmailTemplates — PLATFORM_LEAD_ASSIGNED ────────────────────────────────────────
--
-- Read by AssignLeadHandler.NotifyAsync, after the assignment has committed. It resolves ModuleId
-- back OFF THIS ROW and calls IEmailTemplateService.SendEmailByTemplateKeyAsync — the only path that
-- resolves ops."PlatformCommunicationProviders" for a tenant-less send. An assignment has no tenant,
-- so the composed-body methods (which all demand a companyId) are unusable here.
--
-- ONE template serves BOTH sides of a hand-over — the new owner and the person it was taken from —
-- switched by {{ACTION}} ("assigned to you" / "reassigned away from you"). Two templates would say
-- the same thing about the same event and drift apart the first time either is edited.
--
-- ModuleId  → the PLATFORM module by ModuleCode, so this file is environment-agnostic. If it cannot
--             resolve, NotifyAsync falls back to PSSCORE and then to any module — the alert still
--             sends, but fix the NULL rather than rely on that.
-- CompanyId → 3, the global reference row. "CompanyId" is a non-nullable FK to Company so even a
--             platform template must name one; the service looks up by Code + ModuleId + IsActive
--             with no CompanyId predicate, so the value is bookkeeping only.
-- EmailCategoryId → PLATFORMEMAIL (seeded by ops-lead-deal-seed.sql / product-enquiry-notification-
--             seed.sql). Anything other than 2 makes the service render from the EmailContent COLUMN
--             rather than a file template.
--
-- PLACEHOLDERS — exactly these thirteen, and nothing else. PlaceholderEngine renders an unknown
-- token as an EMPTY STRING, silently, so a typo here is invisible at runtime:
--   {{RECIPIENT_NAME}} {{ACTION}} {{LEAD_ID}} {{ORGANIZATION_NAME}} {{CONTACT_NAME}}
--   {{CONTACT_EMAIL}} {{CONTACT_PHONE}} {{LEAD_STATUS}} {{OWNER_NAME}} {{ASSIGNED_BY_NAME}}
--   {{ASSIGNMENT_NOTE}} {{ASSIGNED_AT}} {{CURRENT_YEAR}}
-- The handler supplies ALL thirteen on every send, blank rather than missing, because
-- PlaceholderEngine has NO {{#if}} support — a conditional block's BODY renders even when its token
-- is empty. Optional rows below are therefore labelled unconditionally and simply show empty. Do NOT
-- add {{#if}} markers to this file.
INSERT INTO "notify"."EmailTemplates"(
    "EmailTemplateCode", "EmailTemplateName", "EmailSubject", "EmailContent",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "ModuleId", "EmailCategoryId", "CompanyId")
SELECT
    'PLATFORM_LEAD_ASSIGNED',
    'Platform Lead Assignment Notification',
    'Lead {{ACTION}} — {{ORGANIZATION_NAME}}',
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
        <tr><td style="background-color:#1d4ed8;padding:28px 40px;">
          <div style="font-size:11px;letter-spacing:3px;text-transform:uppercase;color:#bfdbfe;font-weight:700;">
            Lead Ownership
          </div>
          <div style="font-size:22px;line-height:1.3;color:#ffffff;font-weight:800;margin-top:6px;">
            {{ORGANIZATION_NAME}}
          </div>
          <div style="font-size:12px;color:#bfdbfe;margin-top:6px;">
            {{ASSIGNED_AT}} &nbsp;&middot;&nbsp; Lead #{{LEAD_ID}}
          </div>
        </td></tr>

        <!-- What happened -->
        <tr><td style="padding:28px 40px 4px 40px;">
          <p style="margin:0;font-size:15px;line-height:1.7;color:#0f172a;">
            Hi {{RECIPIENT_NAME}},
          </p>
          <p style="margin:12px 0 0 0;font-size:15px;line-height:1.7;color:#334155;">
            The lead <strong>{{ORGANIZATION_NAME}}</strong> has been
            <strong>{{ACTION}}</strong> by {{ASSIGNED_BY_NAME}}.
            It now sits with <strong>{{OWNER_NAME}}</strong>.
          </p>
        </td></tr>

        <!-- Note from the assigner -->
        <tr><td style="padding:18px 40px 4px 40px;">
          <div style="font-size:11px;letter-spacing:1px;text-transform:uppercase;color:#1d4ed8;font-weight:700;margin-bottom:10px;">
            Note
          </div>
          <div style="font-size:14px;line-height:1.7;color:#334155;background-color:#f8fafc;
                      border-left:3px solid #1d4ed8;border-radius:0 8px 8px 0;padding:14px 18px;
                      white-space:pre-wrap;">{{ASSIGNMENT_NOTE}}</div>
        </td></tr>

        <!-- The prospect -->
        <tr><td style="padding:20px 40px 8px 40px;">
          <div style="font-size:11px;letter-spacing:1px;text-transform:uppercase;color:#1d4ed8;font-weight:700;margin-bottom:12px;">
            Prospect
          </div>
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                 style="font-size:14px;color:#0f172a;background-color:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;">
            <tr>
              <td style="padding:12px 18px;width:170px;color:#64748b;font-size:13px;border-bottom:1px solid #e2e8f0;">Contact</td>
              <td style="padding:12px 18px;font-weight:600;border-bottom:1px solid #e2e8f0;">{{CONTACT_NAME}}</td>
            </tr>
            <tr>
              <td style="padding:12px 18px;color:#64748b;font-size:13px;border-bottom:1px solid #e2e8f0;">Email</td>
              <td style="padding:12px 18px;font-weight:600;border-bottom:1px solid #e2e8f0;word-break:break-all;">
                <a href="mailto:{{CONTACT_EMAIL}}" style="color:#1d4ed8;text-decoration:none;">{{CONTACT_EMAIL}}</a>
              </td>
            </tr>
            <tr>
              <td style="padding:12px 18px;color:#64748b;font-size:13px;border-bottom:1px solid #e2e8f0;">Phone</td>
              <td style="padding:12px 18px;font-weight:600;border-bottom:1px solid #e2e8f0;">{{CONTACT_PHONE}}</td>
            </tr>
            <tr>
              <td style="padding:12px 18px;color:#64748b;font-size:13px;">Status</td>
              <td style="padding:12px 18px;font-weight:600;">{{LEAD_STATUS}}</td>
            </tr>
          </table>
        </td></tr>

        <!-- What to do -->
        <tr><td style="padding:24px 40px 32px 40px;">
          <p style="margin:0;font-size:13px;line-height:1.7;color:#475569;">
            Whoever owns a lead owns the whole relationship through it — the conversation, the deal and
            the onboarding that follows. Open it in the control plane under Platform &rsaquo; Leads.
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
    SELECT 1 FROM "notify"."EmailTemplates" WHERE "EmailTemplateCode" = 'PLATFORM_LEAD_ASSIGNED'
);

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--   -- The capability exists exactly once:
--   SELECT "CapabilityId","CapabilityCode","CapabilityName","OrderBy"
--     FROM auth."Capabilities" WHERE "CapabilityCode" = 'PLATFORM_LEAD_ASSIGN';
--
--   -- Who can reassign (expect ONLY PLATFORM_ADMIN and SUPERADMIN):
--   SELECT r."RoleCode"
--     FROM auth."RoleCapabilities" rc
--     JOIN auth."Roles" r        ON r."RoleId" = rc."RoleId"
--     JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--    WHERE c."CapabilityCode" = 'PLATFORM_LEAD_ASSIGN' AND rc."HasAccess" AND r."CompanyId" IS NULL
--    ORDER BY r."RoleCode";
--
--   -- The template exists and resolved BOTH FKs (a NULL ModuleId means the PLATFORM module is
--   -- missing; a NULL EmailCategoryId means PLATFORMEMAIL is — fix the prerequisite, DELETE this
--   -- row, then re-run this file):
--   SELECT "EmailTemplateCode","CompanyId","ModuleId","EmailCategoryId","IsActive"
--     FROM "notify"."EmailTemplates" WHERE "EmailTemplateCode" = 'PLATFORM_LEAD_ASSIGNED';
--
--   -- No conditional markers slipped into the body (PlaceholderEngine cannot process them):
--   SELECT "EmailTemplateCode" FROM "notify"."EmailTemplates"
--    WHERE "EmailTemplateCode" = 'PLATFORM_LEAD_ASSIGNED' AND "EmailContent" LIKE '%{{#%';
--   -- expect 0 rows.
-- =====================================================================================
