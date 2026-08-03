-- =====================================================================================
-- PROMPT-14 (T-A20) — Billing Gateway §5.5 — platform settings + ops RBAC seed
-- -------------------------------------------------------------------------------------
-- Seeds everything P-14 needs that is NOT a credential:
--   1. sett."OrganizationSettings"  — PLATFORM_GATEWAY_ENVIRONMENT + the three dunning settings
--   2. auth."Menus"                 — PLATFORM_BILLING (the ops gateway surface)
--   3. auth."Capabilities"          — PLATFORM_BILLING_VIEW + PLATFORM_BILLING_MANAGE
--   4. auth."MenuCapabilities"      — so Access Control can manage the grants
--   5. auth."RoleCapabilities"      — grants to PLATFORM_ADMIN / PLATFORM_FINANCE / SUPERADMIN
--   6. auth."Menus" + grants        — PLATFORM_WEBHOOK_LOGS, the second route, so the log
--                                     viewer is reachable from the navigation at all
--
-- ⚠ WHAT THIS SCRIPT DELIBERATELY DOES NOT INSERT
--   NO ops."PlatformPaymentGateways" rows. NO ops."PlatformGatewayCurrencies" rows.
--   Credentials are AES-GCM ciphertext derived from the running API's master key
--   (PaymentGateway:CredentialEncryptionKey) with a platform-scoped HKDF label. SQL cannot
--   produce that ciphertext, and a hand-inserted plaintext value would fail to decrypt at the
--   first charge — silently, at the worst possible moment. Configure gateways through the ops
--   UI (§7.2 UpsertPlatformPaymentGateway), which encrypts on the way in. Sandbox first.
--
--   The currency matrix is empty until someone fills it in, and the resolver FAILS CLOSED on an
--   empty matrix (§3.3). That is intended: until ops states which currencies a gateway actually
--   settles, no tenant can be charged in any currency. An empty matrix blocks a checkout;
--   a wrong matrix charges in a currency the gateway will later reject or reverse.
--
-- ── WHY GATEWAY_ENVIRONMENT IS A SETTING AND NOT A CONFIG FLAG ────────────────────────
--   It decides whether the next card entered is charged real money. It lives in the database,
--   scoped platform-wide (CompanyId IS NULL), so the switch is auditable and reversible without
--   a deploy — and so sandbox and production credentials can coexist as separate gateway rows
--   with only one environment live at a time (§9 acceptance: environment isolation).
--   Default 'sandbox'. Nothing here ever seeds 'production'.
--
-- ── WHY THE DUNNING NUMBERS ARE SETTINGS ──────────────────────────────────────────────
--   §6.5 is a commercial policy, not a constant. Fourteen days of grace is a decision someone
--   in finance will want to change per market without a release. SubscriptionRenewalService
--   reads all three every run; a change takes effect on the next nightly pass (after an API
--   restart, since the platform snapshot is cached).
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on the natural key. Safe to re-run.
-- SAFE: additive only. No DROP, no UPDATE, no schema change.
-- PREREQUISITE: run AFTER billing-platform-settings-seed.sql (needs the PLATFORM settings group)
--               and AFTER ops-platform-rbac-seed.sql (needs the PLATFORM_PLANS menu + roles).
--
-- ⚠ RESTART THE API AFTER COMMIT. PlatformSettingsService caches the platform snapshot; a
--   running instance will not see these rows until it restarts.
-- =====================================================================================

BEGIN;

-- ── 1. Platform settings ─────────────────────────────────────────────────────────────
-- CompanyId NULL = the platform scope IPlatformSettingsService reads. CanUserOverride false:
-- no tenant may change the environment they are charged in, or how long their own grace lasts.
-- CurrentValue NULL so ParamDefaultValue governs until ops writes a value through the UI.
INSERT INTO sett."OrganizationSettings"(
    "CompanyId", "SettingGroupId", "ParamName", "ParamCode", "ParamDataType",
    "AllValues", "ParamDefaultValue", "CurrentValue", "Description", "CanUserOverride",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT
    NULL, sg."SettingGroupId",
    v.param_name, v.param_code, v.data_type, v.all_values, v.default_value, NULL,
    v.description, false,
    2, now(), null, null, true, false
FROM (VALUES
    ('PLATFORM_GATEWAY_ENVIRONMENT', 'Platform Gateway Environment', 'SELECT',
     'sandbox,production',
     'sandbox',
     'Which set of platform gateway credentials is live. Switching to production means the next card entered is charged real money.'),
    ('BILLING_GRACE_PERIOD_DAYS', 'Billing Grace Period Days', 'NUMBER', NULL,
     '14',
     'Days between a subscription first failing to renew and access being suspended. Data is always retained; only access is gated.'),
    ('BILLING_DUNNING_RETRY_DAYS', 'Billing Dunning Retry Days', 'TEXT', NULL,
     '3,7',
     'Comma-separated day offsets, measured from the first failed renewal, at which the retry attempts are made. Default: retry on day 3, final attempt on day 7.'),
    ('BILLING_DUNNING_MAX_ATTEMPTS', 'Billing Dunning Max Attempts', 'NUMBER', NULL,
     '3',
     'Total charge attempts per unpaid cycle, including the first. Once exhausted the subscription waits out its grace period and is then suspended.')
) AS v(param_code, param_name, data_type, all_values, default_value, description)
CROSS JOIN sett."SettingGroups" sg
WHERE sg."SettingGroupCode" = 'PLATFORM'
  AND sg."IsDeleted" = false
  AND NOT EXISTS (
      SELECT 1 FROM sett."OrganizationSettings" s
      WHERE s."CompanyId" IS NULL
        AND s."ParamCode" = v.param_code
        AND s."IsDeleted" = false
  );

-- ── 2. Menu — PLATFORM_BILLING ───────────────────────────────────────────────────────
-- [CustomAuthorize("PLATFORM_BILLING", …)] matches on MenuCode, so this row is not decoration:
-- without it no grant can exist and every platform gateway query/mutation returns unauthorized.
--
-- Module and parent are RESOLVED FROM THE PLATFORM_PLANS MENU rather than hardcoded, so this
-- surface lands wherever the P-03 seed put the rest of the ops control plane, whatever that
-- environment named it. Zero rows from the VERIFY block means PLATFORM_PLANS is missing —
-- run ops-platform-rbac-seed.sql first.
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  'Billing & Gateways', 'PLATFORM_BILLING', p."ParentMenuId", 'ph-credit-card',
  p."ModuleId",
  '/platform/billing',
  'Platform payment gateway configuration, currency matrix and webhook traffic.',
  COALESCE(p."OrderBy", 0) + 5,
  true, 'Internal', true, now(), true, false
FROM auth."Menus" p
WHERE p."MenuCode" = 'PLATFORM_PLANS'
  AND NOT EXISTS (SELECT 1 FROM auth."Menus" m WHERE m."MenuCode" = 'PLATFORM_BILLING');

-- ── 3. Capabilities ──────────────────────────────────────────────────────────────────
-- Guarded on CapabilityName, the column carrying the UNIQUE (CapabilityName, IsActive) index.
-- OrderBy continues the PLATFORM_* block past 98 (BILLING_MANAGE from the P-13 tenant seed).
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT v.cap_name, v.cap_code, v.cap_desc, true, v.order_by, now(), true, false
FROM (VALUES
  ('Platform View Billing',   'PLATFORM_BILLING_VIEW',
   'View platform gateway configuration, the currency matrix and webhook logs (read-only, never credentials).', 100),
  ('Platform Manage Billing', 'PLATFORM_BILLING_MANAGE',
   'Configure platform payment gateways, set the currency matrix and switch between sandbox and production.', 101)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ── 4. MenuCapabilities ──────────────────────────────────────────────────────────────
-- Not consulted by HasAccessAsync, but it is what the Access Control screen enumerates — omit
-- it and these grants become invisible and unmanageable through the UI.
INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", now(), true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" = 'PLATFORM_BILLING'
  AND c."CapabilityCode" IN ('PLATFORM_BILLING_VIEW','PLATFORM_BILLING_MANAGE','ISMENURENDER')
  AND NOT EXISTS (
    SELECT 1 FROM auth."MenuCapabilities" mc
    WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- ── 5. Role grants ───────────────────────────────────────────────────────────────────
-- PLATFORM_* roles are GLOBAL (CompanyId IS NULL) — the join constrains that, unlike the
-- tenant-side BILLING seed where BUSINESSADMIN exists once per company.
--
-- MANAGE is narrow on purpose: only PLATFORM_ADMIN and SUPERADMIN can enter a credential or flip
-- the environment to production. PLATFORM_FINANCE and PLATFORM_SUPPORT get VIEW so they can read
-- a webhook log while triaging a failed payment without being able to repoint the merchant
-- account. ISMENURENDER is granted to everyone who holds VIEW, or the screen never appears.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_ADMIN',   'PLATFORM_BILLING_VIEW'),
  ('PLATFORM_ADMIN',   'PLATFORM_BILLING_MANAGE'),
  ('PLATFORM_ADMIN',   'ISMENURENDER'),
  ('SUPERADMIN',       'PLATFORM_BILLING_VIEW'),
  ('SUPERADMIN',       'PLATFORM_BILLING_MANAGE'),
  ('SUPERADMIN',       'ISMENURENDER'),
  ('PLATFORM_FINANCE', 'PLATFORM_BILLING_VIEW'),
  ('PLATFORM_FINANCE', 'ISMENURENDER'),
  ('PLATFORM_SUPPORT', 'PLATFORM_BILLING_VIEW'),
  ('PLATFORM_SUPPORT', 'ISMENURENDER')
) AS v(role_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = v.role_code AND r."CompanyId" IS NULL
                          AND r."IsDeleted" IS NOT TRUE
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
JOIN auth."Menus"        m ON m."MenuCode" = 'PLATFORM_BILLING'
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

-- ── 6. Menu — PLATFORM_WEBHOOK_LOGS ──────────────────────────────────────────────────
-- The webhook-log viewer is a SECOND route (/platform/webhook-logs) and nothing in sections 2–5
-- reaches it: PLATFORM_BILLING is a leaf pointing at /platform/billing, which the FE redirects to
-- /platform/gateways. Without this row the log viewer exists on disk and is unreachable from the
-- navigation — the only way in would be to type the URL.
--
-- ⚠ THIS ROW GRANTS NOTHING AT THE RESOLVER. GetPlatformWebhookLogs is decorated
--   [CustomAuthorize("PLATFORM_BILLING", …)] — authorization is still evaluated against the
--   PLATFORM_BILLING menu seeded in section 2. This row exists so the item RENDERS in the menu
--   tree; that is why ISMENURENDER is the grant that matters here. VIEW is mirrored alongside it
--   only so the Access Control screen shows a coherent pair rather than a lone render flag.
--   If §⑬ Known Issue 9 is ever fixed (the read-only screen should require _VIEW, not the write
--   capability), the fix is on the attribute in C# — not here.
--
-- Anchored on PLATFORM_BILLING so it lands as its sibling, one slot further down.
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  'Webhook Logs', 'PLATFORM_WEBHOOK_LOGS', p."ParentMenuId", 'ph-list-magnifying-glass',
  p."ModuleId",
  '/platform/webhook-logs',
  'Inbound gateway webhook traffic — delivery status, payload and replay diagnostics.',
  COALESCE(p."OrderBy", 0) + 1,
  true, 'Internal', true, now(), true, false
FROM auth."Menus" p
WHERE p."MenuCode" = 'PLATFORM_BILLING'
  AND NOT EXISTS (SELECT 1 FROM auth."Menus" m WHERE m."MenuCode" = 'PLATFORM_WEBHOOK_LOGS');

INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", now(), true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" = 'PLATFORM_WEBHOOK_LOGS'
  AND c."CapabilityCode" IN ('PLATFORM_BILLING_VIEW','ISMENURENDER')
  AND NOT EXISTS (
    SELECT 1 FROM auth."MenuCapabilities" mc
    WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- Same four roles as section 5, minus MANAGE — there is nothing to manage on a read-only screen.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_ADMIN',   'PLATFORM_BILLING_VIEW'),
  ('PLATFORM_ADMIN',   'ISMENURENDER'),
  ('SUPERADMIN',       'PLATFORM_BILLING_VIEW'),
  ('SUPERADMIN',       'ISMENURENDER'),
  ('PLATFORM_FINANCE', 'PLATFORM_BILLING_VIEW'),
  ('PLATFORM_FINANCE', 'ISMENURENDER'),
  ('PLATFORM_SUPPORT', 'PLATFORM_BILLING_VIEW'),
  ('PLATFORM_SUPPORT', 'ISMENURENDER')
) AS v(role_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = v.role_code AND r."CompanyId" IS NULL
                          AND r."IsDeleted" IS NOT TRUE
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
JOIN auth."Menus"        m ON m."MenuCode" = 'PLATFORM_WEBHOOK_LOGS'
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--
--   -- The four settings, platform-scoped (expect 4 rows, CurrentValue NULL, override false):
--   SELECT "ParamCode","ParamDataType","ParamDefaultValue","CurrentValue","AllValues","CanUserOverride"
--   FROM   sett."OrganizationSettings"
--   WHERE  "CompanyId" IS NULL AND "IsDeleted" = false
--     AND  "ParamCode" IN ('PLATFORM_GATEWAY_ENVIRONMENT','BILLING_GRACE_PERIOD_DAYS',
--                          'BILLING_DUNNING_RETRY_DAYS','BILLING_DUNNING_MAX_ATTEMPTS')
--   ORDER BY "ParamCode";
--   -- PLATFORM_GATEWAY_ENVIRONMENT must read 'sandbox'. If it reads 'production' on a fresh
--   -- install, stop and find out who changed it before anyone enters a card.
--
--   -- No tenant picked these up (expect 0):
--   SELECT count(*) FROM sett."OrganizationSettings"
--   WHERE "CompanyId" IS NOT NULL AND "IsDeleted" = false
--     AND ("ParamCode" LIKE 'BILLING_DUNNING%' OR "ParamCode" = 'PLATFORM_GATEWAY_ENVIRONMENT');
--
--   -- Both menus exist and sit beside PLATFORM_PLANS (expect 3 rows, same parent + module):
--   SELECT "MenuCode","MenuUrl","ParentMenuId","ModuleId","OrderBy","IsVisible"
--   FROM   auth."Menus"
--   WHERE  "MenuCode" IN ('PLATFORM_PLANS','PLATFORM_BILLING','PLATFORM_WEBHOOK_LOGS')
--   ORDER BY "OrderBy";
--   -- Only PLATFORM_PLANS returned means the menu insert found no anchor — run
--   -- ops-platform-rbac-seed.sql, then re-run this script.
--   -- PLATFORM_BILLING must read /platform/billing (the FE redirects it to /platform/gateways)
--   -- and PLATFORM_WEBHOOK_LOGS must read /platform/webhook-logs.
--
--   -- Both capabilities exist (expect 2):
--   SELECT "CapabilityCode","CapabilityName","OrderBy" FROM auth."Capabilities"
--   WHERE  "CapabilityCode" IN ('PLATFORM_BILLING_VIEW','PLATFORM_BILLING_MANAGE');
--
--   -- Who can do what (expect MANAGE on PLATFORM_ADMIN + SUPERADMIN ONLY):
--   SELECT r."RoleCode", c."CapabilityCode"
--   FROM   auth."RoleCapabilities" rc
--   JOIN   auth."Roles" r        ON r."RoleId" = rc."RoleId"
--   JOIN   auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--   JOIN   auth."Menus" m        ON m."MenuId" = rc."MenuId"
--   WHERE  m."MenuCode" = 'PLATFORM_BILLING' AND rc."HasAccess"
--   ORDER BY r."RoleCode", c."CapabilityCode";
--
--   -- Confirm NO gateway or currency rows were created by this script (expect 0 and 0):
--   SELECT count(*) FROM ops."PlatformPaymentGateways";
--   SELECT count(*) FROM ops."PlatformGatewayCurrencies";
--   -- Both stay 0 until someone configures a gateway through the ops UI. Until then the
--   -- resolver fails closed and no checkout can be attempted — which is the correct state
--   -- for a fresh environment.
-- =====================================================================================
