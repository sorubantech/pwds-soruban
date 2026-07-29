-- ═════════════════════════════════════════════════════════════════════════════════════════════
--  SEED (idempotent) — default platform-level EMAIL provider
--
--  Inserts ONE default EMAIL provider into ops.PlatformCommunicationProviders so the platform's own
--  sends (provisioning welcome/activation email) resolve a real provider instead of silently using
--  the global appsettings key. Uses SendGrid — the same account you already send tenant mail with.
--
--  PREREQ: the Add_PlatformCommunicationProviders migration is applied (table exists).
--
--  ── FILL THESE TWO VALUES BEFORE RUNNING ────────────────────────────────────────────────────────
--    :sendgrid_api_key   — copy from appsettings  EmailSettings:SendGridApiKey   (starts "SG.")
--    :from_email         — copy from appsettings  EmailSettings:EmailFrom        (a VERIFIED sender)
--  The ProviderConfiguration JSON shape must match SendGridConfiguration { ApiKey, SandboxMode }.
--
--  Idempotent: re-running updates the existing default EMAIL row's key/from in place (no duplicate).
-- ═════════════════════════════════════════════════════════════════════════════════════════════

\set sendgrid_api_key 'SG.REPLACE_WITH_YOUR_SENDGRID_API_KEY'
\set from_email        'no-reply@REPLACE_WITH_YOUR_VERIFIED_DOMAIN'
\set from_name         'PeopleServe'

-- Insert the default EMAIL row only if one doesn't already exist (a partial unique index can't be an
-- ON CONFLICT target, so guard with NOT EXISTS — fully portable and idempotent).
INSERT INTO ops."PlatformCommunicationProviders"
    ("Channel", "ProviderType", "DisplayName", "ProviderConfiguration",
     "DefaultFromEmail", "DefaultFromName", "Priority", "IsDefault",
     "IsActive", "IsDeleted", "CreatedDate")
SELECT
     'EMAIL', 'SENDGRID', 'Platform SendGrid (transactional)',
     json_build_object('ApiKey', :'sendgrid_api_key', 'SandboxMode', false)::text,
     :'from_email', :'from_name', 1, true,
     true, false, (now() AT TIME ZONE 'utc')
WHERE NOT EXISTS (
    SELECT 1 FROM ops."PlatformCommunicationProviders"
    WHERE "Channel" = 'EMAIL' AND "IsDefault" = true AND "IsDeleted" = false
);

-- If a default EMAIL row already existed, refresh its key + sender in place (idempotent re-run).
UPDATE ops."PlatformCommunicationProviders"
   SET "ProviderConfiguration" = json_build_object('ApiKey', :'sendgrid_api_key', 'SandboxMode', false)::text,
       "DefaultFromEmail"      = :'from_email',
       "DefaultFromName"       = :'from_name',
       "ProviderType"          = 'SENDGRID',
       "IsActive"              = true,
       "IsDeleted"             = false,
       "ModifiedDate"          = (now() AT TIME ZONE 'utc')
 WHERE "Channel" = 'EMAIL' AND "IsDefault" = true AND "IsDeleted" = false;

-- Verify:
SELECT "PlatformCommunicationProviderId", "Channel", "ProviderType",
       "DefaultFromEmail", "IsDefault", "IsActive"
FROM ops."PlatformCommunicationProviders"
WHERE "Channel" = 'EMAIL';
