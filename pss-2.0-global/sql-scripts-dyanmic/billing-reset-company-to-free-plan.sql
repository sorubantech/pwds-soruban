-- =====================================================================================
-- OPERATOR SCRIPT — reset ONE company's billing history and put it back on FREE / Active.
--
-- WHAT IT DOES (for the single CompanyId set in v_company_id, nothing else)
--   1. Hard-deletes that company's billing.InvoiceLines, SubscriptionPayments, Invoices,
--      SubscriptionOverrides and Subscriptions.
--   2. Inserts ONE fresh billing.Subscriptions row on the FREE plan with Status = 'Active'.
--
-- WHAT IT DELIBERATELY DOES NOT TOUCH
--   • billing."Plans" / "PlanPrices" / "PlanEntitlements" / "PlanQuotas" — the plan CATALOG is
--     shared by every tenant. "except free plan" is honoured by never deleting a catalog row at
--     all, not by filtering: deleting FREE (or any plan) here would break every other company.
--   • Any other company's rows. Every statement is keyed on v_company_id.
--   • sett."NumberSequences" — the INVOICE counter is left where it is. Rewinding it would let a
--     future invoice reuse a number that a real, already-issued invoice used, and invoice numbers
--     are a legal identifier. New invoices simply carry on from the current value.
--   • billing."UsageCounters" and billing."TenantPaymentMethods" — NOT in the ask. Optional blocks
--     for both are at the bottom, commented out; read the note before enabling either.
--
-- HARD DELETE, NOT SOFT. These rows are being reset for re-testing, so `IsDeleted = true` would
-- be worse than useless: the filtered UNIQUE index on billing.Subscriptions(CompanyId) does NOT
-- include IsDeleted, so a soft-deleted 'Active' row still blocks the new one.
--
-- ⚠ THIS IS DESTRUCTIVE AND IRREVERSIBLE. Payment and invoice rows are financial records. Run the
--   PREVIEW block below first, confirm the counts are what you expect, and take a backup of the
--   five billing tables before running this against anything but a dev/test database.
--
-- IDEMPOTENT: re-running is safe. The delete is a no-op the second time and the insert is guarded
-- by NOT EXISTS on a live subscription, so it never violates the one-live-subscription index.
-- =====================================================================================


-- ── PREVIEW — run this ALONE first. It changes nothing. ──────────────────────────────
-- Replace 3 with your CompanyId in all four lines.
--
--   SELECT 'Subscriptions' AS table_name, count(*) FROM billing."Subscriptions"        WHERE "CompanyId" = 3
--   UNION ALL SELECT 'Invoices',          count(*) FROM billing."Invoices"             WHERE "CompanyId" = 3
--   UNION ALL SELECT 'Payments',          count(*) FROM billing."SubscriptionPayments" WHERE "CompanyId" = 3
--   UNION ALL SELECT 'InvoiceLines',      count(*) FROM billing."InvoiceLines"
--                                          WHERE "InvoiceId" IN (SELECT "InvoiceId" FROM billing."Invoices" WHERE "CompanyId" = 3);
--
--   -- and what they are on today:
--   SELECT s."SubscriptionId", p."PlanCode", s."Status", s."Amount", s."CurrentPeriodEnd"
--   FROM billing."Subscriptions" s JOIN billing."Plans" p ON p."PlanId" = s."PlanId"
--   WHERE s."CompanyId" = 3;
-- ─────────────────────────────────────────────────────────────────────────────────────


BEGIN;

DO $$
DECLARE
    -- ⇩⇩⇩ THE ONLY LINE YOU EDIT ⇩⇩⇩
    v_company_id CONSTANT int := 3;

    v_free_plan_id   int;
    v_free_price     numeric;
    v_free_currency  int;
    v_free_cycle     varchar;
    v_deleted_lines  int;
    v_deleted_pay    int;
    v_deleted_inv    int;
    v_deleted_ovr    int;
    v_deleted_sub    int;
BEGIN
    -- ── 0. Guards ───────────────────────────────────────────────────────────────────
    -- A typo'd CompanyId must abort, not silently delete nothing and then create a
    -- subscription for a company that does not exist.
    IF NOT EXISTS (SELECT 1 FROM app."Companies" WHERE "CompanyId" = v_company_id) THEN
        RAISE EXCEPTION 'CompanyId % does not exist in app."Companies". Nothing was changed.', v_company_id;
    END IF;

    SELECT p."PlanId", p."Price", p."CurrencyId", p."BillingCycle"
      INTO v_free_plan_id, v_free_price, v_free_currency, v_free_cycle
      FROM billing."Plans" p
     WHERE p."PlanCode" = 'FREE'
       AND COALESCE(p."IsDeleted", false) = false;

    IF v_free_plan_id IS NULL THEN
        RAISE EXCEPTION 'No active FREE plan in billing."Plans". Run billing-plan-catalog-seed.sql first. Nothing was changed.';
    END IF;

    -- ── 1. Children first, parents after — FK order, no CASCADE relied on ───────────
    -- InvoiceLines have no CompanyId (they are reached through their invoice), so they are
    -- scoped by the invoice sub-select. Doing this BEFORE the invoices are gone is the only
    -- way to find them.
    DELETE FROM billing."InvoiceLines"
     WHERE "InvoiceId" IN (SELECT "InvoiceId" FROM billing."Invoices" WHERE "CompanyId" = v_company_id);
    GET DIAGNOSTICS v_deleted_lines = ROW_COUNT;

    -- Payments before invoices: SubscriptionPayments.InvoiceId FKs the invoice, and
    -- SubscriptionId FKs the subscription. It is a child of both.
    DELETE FROM billing."SubscriptionPayments" WHERE "CompanyId" = v_company_id;
    GET DIAGNOSTICS v_deleted_pay = ROW_COUNT;

    DELETE FROM billing."Invoices" WHERE "CompanyId" = v_company_id;
    GET DIAGNOSTICS v_deleted_inv = ROW_COUNT;

    -- SubscriptionOverrides also carry no CompanyId — same reasoning as InvoiceLines.
    DELETE FROM billing."SubscriptionOverrides"
     WHERE "SubscriptionId" IN (SELECT "SubscriptionId" FROM billing."Subscriptions" WHERE "CompanyId" = v_company_id);
    GET DIAGNOSTICS v_deleted_ovr = ROW_COUNT;

    DELETE FROM billing."Subscriptions" WHERE "CompanyId" = v_company_id;
    GET DIAGNOSTICS v_deleted_sub = ROW_COUNT;

    -- ── 2. Put them back on FREE, Active ────────────────────────────────────────────
    -- Status = 'Active' as requested, and TrialEndsOn stays NULL on purpose. Two consequences,
    -- both intended for a reset:
    --   • EntitlementService only expires a subscription when Status = 'Trial' AND TrialEndsOn
    --     has passed, so this row never lapses — the tenant is not on a 14-day countdown.
    --   • The one-trial-per-company guard keys on ANY past subscription with a non-null
    --     TrialEndsOn. Everything was just deleted and this row leaves it NULL, so the company
    --     is eligible for a fresh trial again.
    -- If you instead want the normal 14-day FREE trial the app itself would create, use the
    -- alternative INSERT at the bottom of this file.
    --
    -- Amount / CurrencyId / BillingCycle are SNAPSHOT columns — copied from the plan as values,
    -- never left to be read back through the FK later.
    IF NOT EXISTS (
        SELECT 1 FROM billing."Subscriptions"
         WHERE "CompanyId" = v_company_id
           AND "Status" IN ('Trial','Active','PastDue')
    ) THEN
        INSERT INTO billing."Subscriptions"
            ("CompanyId","PlanId","Status","StartDate","CurrentPeriodStart","CurrentPeriodEnd",
             "TrialEndsOn","CurrencyId","Amount","BillingCycle","PriceSource","AutoRenew",
             "DunningAttemptCount","CreatedDate","IsActive","IsDeleted")
        VALUES
            (v_company_id, v_free_plan_id, 'Active', now(), now(),
             CASE WHEN v_free_cycle = 'Annual' THEN now() + interval '1 year'
                  ELSE now() + interval '1 month' END,
             NULL, v_free_currency, COALESCE(v_free_price, 0), v_free_cycle, 'FREE', true,
             0, now(), true, false);
    END IF;

    RAISE NOTICE 'Company %: deleted % invoice line(s), % payment(s), % invoice(s), % override(s), % subscription(s). Now on FREE (PlanId %) / Active.',
        v_company_id, v_deleted_lines, v_deleted_pay, v_deleted_inv, v_deleted_ovr, v_deleted_sub, v_free_plan_id;
END $$;

COMMIT;


-- =====================================================================================
-- VERIFY (run after COMMIT — replace 3 with your CompanyId)
--
--   -- exactly one row, FREE / Active, no trial end:
--   SELECT s."SubscriptionId", p."PlanCode", s."Status", s."Amount", s."BillingCycle",
--          s."CurrentPeriodStart", s."CurrentPeriodEnd", s."TrialEndsOn"
--   FROM billing."Subscriptions" s JOIN billing."Plans" p ON p."PlanId" = s."PlanId"
--   WHERE s."CompanyId" = 3;
--
--   -- all three must be 0:
--   SELECT (SELECT count(*) FROM billing."Invoices"             WHERE "CompanyId" = 3) AS invoices,
--          (SELECT count(*) FROM billing."SubscriptionPayments" WHERE "CompanyId" = 3) AS payments,
--          (SELECT count(*) FROM billing."InvoiceLines" l
--             JOIN billing."Invoices" i ON i."InvoiceId" = l."InvoiceId"
--            WHERE i."CompanyId" = 3)                                                  AS invoice_lines;
--
--   -- the catalog must be untouched — 4 plans still there:
--   SELECT "PlanCode", "PlanName", "TrialDurationDays" FROM billing."Plans" ORDER BY "SortOrder";
--
-- AFTER RUNNING: the tenant's entitlements are cached in-process. Either restart the API or have
-- the user sign out and back in, otherwise they keep seeing their old plan's features until the
-- cache is invalidated.
-- =====================================================================================


-- =====================================================================================
-- ALTERNATIVE — give them the real 14-day FREE TRIAL instead of an open-ended Active row.
-- This is what AssignSubscription would produce for a time-boxed plan. Swap it in for the
-- INSERT above if you want to test the trial countdown / expiry path.
--
--   INSERT INTO billing."Subscriptions"
--       ("CompanyId","PlanId","Status","StartDate","CurrentPeriodStart","CurrentPeriodEnd",
--        "TrialEndsOn","CurrencyId","Amount","BillingCycle","PriceSource","AutoRenew",
--        "DunningAttemptCount","CreatedDate","IsActive","IsDeleted")
--   VALUES
--       (v_company_id, v_free_plan_id, 'Trial', now(), now(),
--        now() + (COALESCE((SELECT "TrialDurationDays" FROM billing."Plans" WHERE "PlanId" = v_free_plan_id), 14) || ' days')::interval,
--        now() + (COALESCE((SELECT "TrialDurationDays" FROM billing."Plans" WHERE "PlanId" = v_free_plan_id), 14) || ' days')::interval,
--        v_free_currency, COALESCE(v_free_price, 0), v_free_cycle, 'FREE', true,
--        0, now(), true, false);
-- =====================================================================================


-- =====================================================================================
-- OPTIONAL EXTRAS — not part of the ask, enable only if you know you want them.
--
-- (a) USAGE COUNTERS. FLOW meters (EMAILS/month) count against the tenant's limit and survive a
--     plan reset, so a company that already sent 500 emails this month is still at its FREE cap
--     the moment this script finishes. Clear them ONLY if you are resetting for a fresh test —
--     they are the record of what was actually consumed.
--
--       DELETE FROM billing."UsageCounters" WHERE "CompanyId" = 3;
--
-- (b) SAVED PAYMENT METHODS. These are gateway tokens for stored cards/mandates. Deleting the
--     row here does NOT revoke the token at the gateway — do that in the gateway dashboard as
--     well, or the mandate can still be charged.
--
--       DELETE FROM billing."TenantPaymentMethods" WHERE "CompanyId" = 3;
-- =====================================================================================
