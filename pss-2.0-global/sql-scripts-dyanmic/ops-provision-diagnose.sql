-- ─────────────────────────────────────────────────────────────────────────────────────────────
--  READ-ONLY diagnostic for the "subdomain already taken / company code already exists" loop.
--  Nothing is modified. Edit the two variables, run all three SELECTs, and paste the full output.
--  These reveal exactly why the validator's "own company" exclusion is coming back empty:
--    - are there DUPLICATE live companies with the same subdomain/code?
--    - does a NON-ABANDONED run exist whose IdempotencyKey matches AND whose CompanyId is set?
--    - does that run's IdempotencyKey equal what the wizard/resume will recompute?
-- ─────────────────────────────────────────────────────────────────────────────────────────────

\set the_code    'REPLACE_WITH_COMPANYCODE'
\set the_subdomain 'REPLACE_WITH_SUBDOMAIN'

-- (1) EVERY company row for this code or subdomain — including soft-deleted. Duplicates here are the
--     prime suspect: two live rows with the same subdomain both trip the guard, excluding one is not enough.
SELECT "CompanyId", "CompanyCode", "Subdomain", "Status", "IsDeleted", "SourceLeadId", "CompanyName"
FROM app."Companies"
WHERE "CompanyCode" = :'the_code' OR "Subdomain" = :'the_subdomain'
ORDER BY "CompanyId";

-- (2) EVERY provisioning run whose key mentions this code, or that points at one of the above companies.
--     For the validator to pass, at least one row here must have: Status <> 'ABANDONED', CompanyId NOT NULL,
--     IsDeleted = false, and an IdempotencyKey equal to what the submit recomputes (see note below).
SELECT "RunId", "IdempotencyKey", "LeadId", "CompanyId", "Status", "IsDeleted",
       "Mode", "StartedOn", "CompletedOn"
FROM ops."TenantProvisioningRuns"
WHERE "IdempotencyKey" LIKE '%CODE:' || :'the_code'
   OR "CompanyId" IN (SELECT "CompanyId" FROM app."Companies"
                      WHERE "CompanyCode" = :'the_code' OR "Subdomain" = :'the_subdomain')
ORDER BY "RunId";

-- (3) The per-step state of those runs (so we can see which steps actually SUCCEEDED).
SELECT s."RunId", s."StepNumber", s."StepCode", s."Status", s."AttemptCount", s."ErrorMessage"
FROM ops."TenantProvisioningRunSteps" s
WHERE s."RunId" IN (
    SELECT "RunId" FROM ops."TenantProvisioningRuns"
    WHERE "IdempotencyKey" LIKE '%CODE:' || :'the_code'
       OR "CompanyId" IN (SELECT "CompanyId" FROM app."Companies"
                          WHERE "CompanyCode" = :'the_code' OR "Subdomain" = :'the_subdomain')
)
ORDER BY s."RunId", s."StepNumber";

-- NOTE on the key: the validator recomputes  LEAD:{leadId}|CODE:{code}  when the submit carries a LeadId,
-- otherwise  CODE:{code}.  Compare that against the IdempotencyKey column in query (2). If the run you
-- expect to be "own" has a different key string, the exclusion can never match it — that's case C.
