# D-Q4 — Module → Plan map (decision brief)

> ✅ **DECIDED 2026-07-24.** All three forks confirmed as recommended: FREE = Contacts+Donation+capped-Email; Case & Grant = PLAN_100K only; Event/Volunteer/Membership = all in PLAN_50K. **The "Recommended default matrix" below is now the seed spec for P-02.**

**Why this blocks P-02:** the plan seed writes `PlanEntitlement` (`MODULE:*` / `CHANNEL:*` booleans) + `PlanQuota` rows, and provisioning **step 4** grants a new tenant `role capabilities ∩ plan entitlements`. Both need a concrete matrix. The design doc (`PSS-2.0-PLANS-AND-ENTITLEMENTS-APPROACH.md` §5) left the cells below as `❓`.

**Vocabulary (fixed, from §4):**
- Modules: `CONTACTS`, `DONATION`, `CASE`, `GRANT`, `VOLUNTEER`, `EVENT`, `MEMBERSHIP`
- Channels: `EMAIL`, `WHATSAPP`, `SMS`
- Plans: `FREE`, `PLAN_50K`, `PLAN_100K`, `CUSTOM`

---

## Recommended default matrix

| Feature / Meter | Type | FREE | PLAN_50K | PLAN_100K | CUSTOM |
|---|---|---|---|---|---|
| `MODULE:CONTACTS` | entitlement | ✅ | ✅ | ✅ | override |
| `MODULE:DONATION` | entitlement | ✅ | ✅ | ✅ | override |
| `MODULE:EVENT` | entitlement | ❌ | ✅ | ✅ | override |
| `MODULE:VOLUNTEER` | entitlement | ❌ | ✅ | ✅ | override |
| `MODULE:MEMBERSHIP` | entitlement | ❌ | ✅ | ✅ | override |
| `MODULE:CASE` | entitlement | ❌ | ❌ | ✅ | override |
| `MODULE:GRANT` | entitlement | ❌ | ❌ | ✅ | override |
| `CHANNEL:EMAIL` | feature | ✅ (capped) | ✅ | ✅ | ✅ |
| `CHANNEL:WHATSAPP` | feature | ❌ | ❌ | ✅ | override |
| `CHANNEL:SMS` | feature | ❌ | ❌ | ✅ | override |
| Contacts | STOCK | 2,000 | 500,000 | 1,000,000 | override |
| Donations | STOCK | 25,000 | 5,000,000 | 10,000,000 | override |
| Emails | FLOW/mo | 500 | plan limit | plan limit | override |
| Users (seats) | STOCK | 2 | 15 | 50 | override |

**Rationale:**
- **FREE = trial / tiny NGO.** Contacts + Donation + a capped Email so the product is genuinely usable and a lead can self-serve, but small enough to drive upgrade. (Fills the doc's `❓` FREE-tier blanks: Donations 25K, Email ✅-capped, 2 seats.)
- **PLAN_50K = growing NGO.** Adds the engagement modules (Event, Volunteer, Membership) + full Email. No premium channels, no casework/grants.
- **PLAN_100K = full suite.** Everything, including the two "heavy" modules (**Case, Grant**) and premium channels (WhatsApp, SMS). Case + Grant are the most complex/high-value modules → top tier is the natural gate.
- **CUSTOM = enterprise.** All modules on by default; real values set per-company via `SubscriptionOverride`.

**The three forks worth an explicit call (everything else follows):**
1. **FREE packaging** — Contacts+Donation+capped-Email (recommended) vs Contacts-only vs Contacts+Donation (no email).
2. **Case & Grant gating** — 100K-only (recommended) vs also in 50K.
3. **Engagement modules (Event/Volunteer/Membership)** — grouped into 50K (recommended) vs split across tiers.

> MVP note: enforcement is the *skeleton* (P2 of the plans doc). Getting the map "directionally right" is enough to seed; per-cell numbers are trivially editable later via the Plan Catalog screen. So don't over-optimize the exact quotas now — lock the **module→tier shape**.
