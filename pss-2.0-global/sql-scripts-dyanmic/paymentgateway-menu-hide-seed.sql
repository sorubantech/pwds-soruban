-- =====================================================================================
-- P-15 T-A21 — Hide the standalone PAYMENTGATEWAY (master catalogue) menu
-- -------------------------------------------------------------------------------------
-- WHY THIS EXISTS
-- The gateway catalogue is a code artefact, not tenant data: a com."PaymentGateways" row only means
-- something if PaymentGatewayFactory can turn its code into a provider class. T-A21 removed the
-- createPaymentGateway / deletePaymentGateway mutations for that reason, which leaves the standalone
-- master screen an empty shell. Its content now lives as Tab 1 ("Available Gateways") inside the
-- per-company Payment Gateways screen, where it is read-only advice next to the row a tenant can
-- actually configure.
--
-- HIDE, NEVER DELETE. Removing the auth."Menus" row would strand its MenuCapabilities and
-- RoleCapabilities children and break any role-permission screen that joins them. IsActive = false
-- takes it out of navigation while every capability row stays intact and reversible.
--
-- COMPANYPAYMENTGATEWAY IS UNTOUCHED, deliberately. Nothing is revoked there: CREATE and DELETE are
-- correct on that menu, because a tenant does create and delete its own gateway configurations. The
-- "no create" rule applies to the master catalogue only.
--
-- IDEMPOTENT: guarded UPDATE, value-stable. Re-running is a no-op.
-- SAFE: no DROP, no DELETE, no schema change. Reverse with the ROLLBACK statement at the foot.
-- =====================================================================================

BEGIN;

UPDATE auth."Menus"
   SET "IsActive"    = false,
       "IsVisible"   = false,   -- navigation renders from IsVisible on some surfaces; set both so
                                -- the menu cannot reappear through whichever one a screen reads.
       "IsLeastMenu" = false,
       "ModifiedDate" = now()
 WHERE "MenuCode" = 'PAYMENTGATEWAY'
   AND ("IsActive" IS DISTINCT FROM false
     OR "IsVisible" IS DISTINCT FROM false
     OR "IsLeastMenu" IS DISTINCT FROM false);

COMMIT;

-- ── Verification ─────────────────────────────────────────────────────────────────────────────
-- Menu hidden, capability rows still present:
--   SELECT mn."MenuCode", mn."IsActive", mn."IsVisible", mn."IsLeastMenu"
--     FROM auth."Menus" mn WHERE mn."MenuCode" IN ('PAYMENTGATEWAY','COMPANYPAYMENTGATEWAY');
--
--   SELECT count(*) FROM auth."RoleCapabilities" rc
--     JOIN auth."Menus" mn ON mn."MenuId" = rc."MenuId"
--    WHERE mn."MenuCode" = 'PAYMENTGATEWAY';   -- expect unchanged, not zero
--
-- ── Reversal ─────────────────────────────────────────────────────────────────────────────────
--   UPDATE auth."Menus" SET "IsActive" = true, "IsVisible" = true, "IsLeastMenu" = true,
--          "ModifiedDate" = now()
--    WHERE "MenuCode" = 'PAYMENTGATEWAY';
