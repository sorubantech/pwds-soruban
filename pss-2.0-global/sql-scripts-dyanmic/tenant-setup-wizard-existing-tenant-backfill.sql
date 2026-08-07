-- Existing tenants predate the setup wizard. Mark them completed so the
-- first-login gate never ambushes them. New tenants are stamped NULL at
-- provisioning and are the only ones the wizard should ever catch.
UPDATE app."Companies"
SET    "SetupWizardCompletedDate" = now(),
       "SetupWizardVersion"       = 1
WHERE  "SetupWizardCompletedDate" IS NULL;

-- RESULT 1 — expect 0 rows after the update.
SELECT COUNT(*) AS companies_still_null
FROM   app."Companies"
WHERE  "SetupWizardCompletedDate" IS NULL;

-- RESULT 2 — expect the table to exist and be empty on a fresh install.
SELECT COUNT(*) AS tenant_setup_task_rows
FROM   sett."TenantSetupTasks";
