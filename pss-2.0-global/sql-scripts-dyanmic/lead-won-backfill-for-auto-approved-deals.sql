-- ─────────────────────────────────────────────────────────────────────────────────────────────
--  Backfill: advance leads whose deal auto-approved BEFORE the code fix.
--
--  SubmitCommercialTerm used to set a term to APPROVED (discount <= threshold) without advancing
--  its lead, and ApproveCommercialTerm refuses any term that is not PENDING_APPROVAL — so those
--  leads are stranded at NEW/QUALIFIED with CanConvert = false and no in-app way forward.
--
--  The code now advances the lead in the auto-approve branch too (LeadHelper.TryAdvanceLeadToWonAsync),
--  so this script is a ONE-OFF for rows created before that build. Idempotent: re-running it is a
--  no-op once every affected lead is WON.
--
--  Run the SELECT first and eyeball the rows. Only then run the UPDATE.
-- ─────────────────────────────────────────────────────────────────────────────────────────────

-- 1) PREVIEW — which leads would move, and on the strength of which deal.
SELECT l."LeadId",
       l."CompanyName",
       l."Status"          AS "LeadStatus",
       t."CommercialTermId",
       t."ApprovalStatus",
       t."DiscountPercent",
       t."ApprovedOn",
       t."ApprovedByUserId"          -- NULL here = auto-approved by policy, no human signed it
FROM   ops."Leads" l
JOIN   ops."CommercialTerms" t ON t."LeadId" = l."LeadId"
WHERE  l."IsDeleted" IS DISTINCT FROM TRUE
  AND  t."IsDeleted" IS DISTINCT FROM TRUE
  AND  t."ApprovalStatus" = 'APPROVED'
  AND  l."Status" IN ('NEW', 'QUALIFIED')
  AND  l."ConvertedCompanyId" IS NULL
ORDER  BY l."LeadId";

-- 2) APPLY — advance exactly those leads. Mirrors the guards in TryAdvanceLeadToWonAsync:
--    live, not yet converted, still in the funnel, and holding at least one APPROVED deal.
--    ModifiedBy is deliberately left untouched — policy, not a person, made this call.
UPDATE ops."Leads" l
SET    "Status"       = 'WON',
       "ModifiedDate" = NOW() AT TIME ZONE 'UTC'
WHERE  l."IsDeleted" IS DISTINCT FROM TRUE
  AND  l."Status" IN ('NEW', 'QUALIFIED')
  AND  l."ConvertedCompanyId" IS NULL
  AND  EXISTS (
         SELECT 1
         FROM   ops."CommercialTerms" t
         WHERE  t."LeadId" = l."LeadId"
           AND  t."IsDeleted" IS DISTINCT FROM TRUE
           AND  t."ApprovalStatus" = 'APPROVED'
       );

-- 3) VERIFY — should return zero rows.
SELECT l."LeadId", l."CompanyName", l."Status"
FROM   ops."Leads" l
JOIN   ops."CommercialTerms" t ON t."LeadId" = l."LeadId"
WHERE  l."IsDeleted" IS DISTINCT FROM TRUE
  AND  t."IsDeleted" IS DISTINCT FROM TRUE
  AND  t."ApprovalStatus" = 'APPROVED'
  AND  l."Status" IN ('NEW', 'QUALIFIED')
  AND  l."ConvertedCompanyId" IS NULL;
