# PSS 2.0 — MVP-1 Pending Development List

**Compiled:** 2026-08-09 · **Target release:** morning of 2026-08-10
**Scope exclusion (per instruction):** dynamic subdomain — not in this list.

**How to read the Status column**
- `VERIFIED OPEN` — I read the current source today and the defect is still there.
- `AUDIT` — carried from `PRODUCTION-READINESS-BACKLOG.md` (2026-07-14). Not re-verified. Treat as probable, not certain.
- `VERIFIED PARTIAL` — a mitigation exists but does not fully close the finding.

---

## Bucket A — Security. Fix before anything is exposed.

| # | Item | Status | Evidence | Est. |
|---|---|---|---|---|
| **A1** / #73 | RSA private key + two live DB passwords committed to git | **VERIFIED OPEN** | `Base.API/appsettings.json` is git-tracked; contains `BEGIN PRIVATE KEY`, `Password=Ba0wKVNnLeCVe`, `Password=sKeIGZ2ejuGr` | 1–2 h |
| **A2** / #71 | CORS: any origin + credentials | **VERIFIED OPEN** | `Base.API/DependencyInjection.cs:402-406` — `.SetIsOriginAllowed(_ => true).AllowCredentials()` | 10 m |
| **A3** / #72 | `POST /api/media/upload` unauthenticated, `.svg` allowed → stored XSS | **VERIFIED OPEN** | `Base.API/Controller/MediaController.cs` — no `[Authorize]` anywhere in the file | 10 m |
| **A4** / #68 | **CQRS pipeline is default-OPEN** | **VERIFIED OPEN** | `Base.Application/Security/AuthorizationBehavior.cs:30-33` — no `[CustomAuthorize]` attribute ⇒ `return await next()`. Every command/query missing the attribute executes for any authenticated caller | audit + fix |
| **A5** / #283 | NextAuth `authorize()` trusts client-supplied `userData`, no server call | **VERIFIED OPEN** | `src/infrastructure/lib/configs/auth.ts:62-80` | 1 h |
| **A6** / #2 | Client-supplied `RoleId`/`CompanyId` accepted → privilege escalation | AUDIT | — | ? |
| **A7** / #76 | Decrypted gateway secrets readable cross-tenant | AUDIT | — | ? |
| **A8** / #66 | `GetUserRefreshTokens` authorization commented out | AUDIT | — | 15 m |
| **A9** / #5 | Account lockout defeatable | AUDIT | — | ? |
| **A10** / #33 | Public payment mutations have no reCAPTCHA / CSRF | AUDIT | — | ? |
| **A11** / #29 | `CompanyId = 0` paths | AUDIT | — | ? |

**A4 is the one to read first.** It is not a single bug — it is a policy hole. The size of the exposure equals the number of handlers that forgot the attribute. That count is unknown and worth 20 minutes of grepping tonight, because it decides whether A6 is even reachable.

**Tenant isolation — better than the audit claimed (#57).** A real global query filter exists: `ApplicationDbContext.ApplyTenantFilters()` auto-applies `CompanyId` filtering to every entity with a `CompanyId` property. Plus `TenantIsolationBehavior` / `TenantAccessBehavior` validate request properties. **VERIFIED PARTIAL** — the caveat is that `CurrentTenantId == null` means *no filter at all* (by design, for SuperAdmin). Any path where tenant resolution silently fails is therefore wide open, not closed. Fails open, not closed.

---

## Bucket B — Money paths. Wrong numbers are worse than missing features.

| # | Item | Status | Fix or hide |
|---|---|---|---|
| **B1** / D-2 | Publish validator does not check `IsActive` on the gateway → a tenant can publish a donation page wired to a switched-off gateway; every donor fails at payment | **VERIFIED OPEN** — `ValidateOnlineDonationPageForPublish.cs:213` | **FIX** — add `&& g.IsActive == true`. One line. |
| **B2** / #41, #53 | Refunds never call the gateway; born "complete"; ledger moves, money does not | AUDIT | **HIDE** |
| **B3** / #39 | Recurring-donation retry fabricates SUCCESS, contacts no processor | AUDIT | **HIDE** |
| **B4** / #17 | FX rate supplied by the client | AUDIT | **HIDE multi-currency** or pin server-side |
| **B5** / #52 | No webhook dedup index → double-credit on gateway replay | AUDIT | **FIX** if cheap (unique index) — needs migration, so user's call |
| **B6** / #12 | Inbound email webhook signature unverified | AUDIT | **FIX or disable endpoint** |
| **B7** / #9 | Recurring-charge query mis-scoped | AUDIT | moot if B3 hidden |
| **B8** / #49 | Event ticket oversell (no capacity lock) | AUDIT | **HIDE ticketing** or accept + monitor |

---

## Bucket C — Features to switch off, not fix

No time to build these properly. Shipping them visible is worse than shipping without them, because each one reports success while doing nothing.

| Feature | Why | How |
|---|---|---|
| Refunds | B2 | `Menu.IsActive = false` / revoke `ISMENURENDER` |
| Recurring retry (manual button) | B3 | hide action in grid |
| Scheduled Reports (#10) | no execution engine; runs stick on RUNNING | hide menu |
| Custom Report Builder (#61) | preview/run/export all fabricated | hide menu |
| Member Portal (#86) | "auth" is a localStorage check | hide menu + block route |

Per the standing rule this is a **seed**, not code — `seed_mvp1_menu_hide.sql`, idempotent, `IsActive = false` but leave the rows in place so MVP-2 just flips them back.

---

## Bucket D — Config / environment. Cheap, and each one is fatal alone.

| Item | Symptom if missed |
|---|---|
| **`Auth:PlatformHosts`** must be set | `HostTenantResolver.cs:112` returns `false` when unset. Localhost works via the Development bypass, so this passes every local test and then **nobody can log in** on a real hostname in a Production build. |
| `ops."PlatformCommunicationProviders"` — active EMAIL row | Mail silently never sends. No error surfaces. |
| `NEXT_PUBLIC_UPGRADE_CONTACT` | Upgrade CTA dead-ends |
| Connection strings + JWT keys from env, not `appsettings.json` | follows from A1 |
| `pg_dump` before any of tonight's work | rollback |

---

## Bucket E — Data seeds (from the demo runbook, still required)

| Item | Why it blocks |
|---|---|
| `__TEMPLATE__` company must exist, with roles to clone, a `SYSTEMROLE` row, and an ADMINISTRATOR `StaffCategories` row | **Provisioning throws at step 3 without it.** This was the #1 demo blocker and nothing has changed it. |
| 4 plans (`FREE`, `PLAN_50K`, `PLAN_100K`, `CUSTOM`) each with quotas > 0, features > 0, prices > 0 | a plan with zero quotas **fails closed** — tenant can do nothing |
| All 15 migrations applied (`…_Add_TenantProvision_Entities` → `…_Add_RbacRollout_Entities`) | — |
| Phase 6 intimation seeds | banner stays empty |

---

## Bucket F — Known screen defects

| Item | Status |
|---|---|
| Contact screen #18 | **CLOSED — the `NEEDS_FIX` label was stale.** `screen-tracker/prompts/contact.md` and `REGISTRY.md` row 18 both read `COMPLETED`; every ITEM of the Contact readiness prompt (ISSUE-24/25/26/27/28/29/30) is closed. S6 fixed the one live residual (ISSUE-32, toast-only "Add relationship"). Two documented limitations remain — see S6 report below. |
| Tenant comms config UI defects | **CLOSED for MVP-1.** Phases 1 + 2 shipped 2026-08-05 (`PSS-2.0-TENANT-COMMS-CONFIG-UI-FIX-PROMPT.md` §⑭), typecheck green; the `SmsSettings.CurrencyId` migration landed in `20260805112547_Add_IsPlatformProvider_ToCompanEmailProvider`. Phase 3 (S-7 DND country source, W-3 WhatsApp cap/budget) deliberately deferred — blocked on the per-plan SMS/WhatsApp allowance product decision, not on code. |
| Phase 6 §9.3 — refresh branch must set `IsDismissible = false` + soft-delete dismissals when severity → CRITICAL | **CONFIRMED DONE** — `IntimationService.cs:67-91`, committed in `6b6ee0f8`. No migration. |
| Phase 6 §9.4 — widen partial unique index filter to `"Status" = 'ACTIVE' AND "IsDeleted" = false` | **DECIDED: widen.** Latent today (nothing soft-deletes an Intimation) but silent and permanent once reachable. `IntimationConfiguration.cs` already carries the widened filter; the migration, its Designer and the model snapshot do not → pending model diff. Migration handed to the user: `prompts/mvp1/S6-intimation-dedup-index-migration-handoff.md`. |
| Phase 6 §⑤ A1–A10 runtime acceptance | **entirely unexercised** |
| Phase 5 §⑤ A1–A10 | unconfirmed |
| Phase 4 §③ Part A — 27 runtime acceptance points | unexercised |

---

## Tonight, in order

1. `pg_dump`
2. A2 CORS allowlist — 10 min
3. A3 `[Authorize]` on MediaController + drop `.svg` — 10 min
4. B1 the D-2 one-liner — 1 min
5. A1 rotate both DB passwords + regenerate JWT keypair, move to env, `git rm --cached appsettings.json`, `.gitignore` — 1–2 h
   *Rotation is the fix. Deleting the file does not un-leak a key that is in history.*
6. D — set `Auth:PlatformHosts`, verify the EMAIL provider row
7. C — the menu-hide seed
8. E — verify `__TEMPLATE__` + the 4 plans on the actual release database
9. A4 — grep handlers missing `[CustomAuthorize]`, at minimum on anything money- or user-related
10. A5 if time remains

---

## Verdict

**Not shippable as open public production.** A1 alone (a private key and live DB credentials in a tracked file) rules that out, and 24 of the 28 audit blockers cannot be cleared overnight.

**Shippable as a managed release to onboarded pilot tenants** if items 1–8 land tonight. That posture is defensible to management: refunds, reports and the member portal move to MVP-2 — they were never in MVP-1 scope — and the remaining exposure is bounded by the fact that no unknown party can self-serve onto the platform.

The decision between those two is yours. What I will not do is call the second one "production-ready" — it is a controlled release with a named fix-set, and it should be described that way in writing to whoever signs off.

## What is explicitly NOT on this list

- Dynamic subdomain — excluded by instruction
- Phase 7 (Feature Dependency Registry, trigger layers, readiness widgets) — post-MVP; **only** its step-0 defect B1 is in scope tonight
- The three-way predicate drift behind B1 — inconsistency between advisory surfaces, not a money path
- The remaining ~310 non-blocker audit findings
