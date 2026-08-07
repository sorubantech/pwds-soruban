# MVP-1 Demo Readiness Runbook — demo at 17:00, 6 Aug 2026

> **Written:** 2026-08-05 · **Time to demo: ~24 hours**
> **Purpose:** get a working demo on screen. Not a complete product.
> **Governing rule for the next 24 hours:** *if it doesn't appear on screen during the demo, it doesn't get touched.*

---

## 0. Read this first

You have ~24 hours. That is enough — **but only if you spend it on data, not code.**

The MVP-1 modules are built. What is not done is the **setup around them**: migrations not applied, seeds not run, the template organisation empty. None of that is development. All of it is SQL you already have written.

So the plan is:

| Phase | When | What |
|---|---|---|
| **1. Find out what's actually missing** | Tonight, 30 min | Run §1. It answers in one query set. |
| **2. Apply the backlog** | Tonight, 2 h | §2, in the given order. |
| **3. Rehearse end to end** | Tomorrow AM | §3. Every break you find becomes a §4 fix. |
| **4. Fix only demo-blockers** | Tomorrow midday | §4. Nothing else. |
| **5. Freeze** | 16:00 | §5. No deploys after this. |
| **6. Demo** | 17:00 | §6 script, §7 fallbacks. |

> ⚠️ **Do not start any of the three build prompts sitting in the repo** (metering, bulk-email reliability, tenant comms UI). None of them changes what management sees tomorrow, and all three touch the email pipeline you are about to demo. They are post-demo work.

---

## 1. Verification — run this first (30 minutes)

You cannot plan the night until you know what your database actually has. Run each block and write the answer in the right-hand column.

### 1.1 Which migrations are applied?

```sql
SELECT "MigrationId"
FROM public."__EFMigrationsHistory"
WHERE "MigrationId" >= '20260724'
ORDER BY "MigrationId";
```

Expected — **all 15**. Tick what is present:

| Migration | Present? | If missing, what breaks |
|---|---|---|
| `20260724052723_Add_TenantProvision_Entities` | | Onboarding wizard — **demo dead** |
| `20260724063221_Add_Plan_And_BillingCycle_Entities` | | Plans screen, provisioning step 2 |
| `20260724085640_Add_PlanPrice` | | Plan pricing |
| `20260727084118_Add_Lead_CommercialTerm_Entities` | | Lead → deal → wizard flow |
| `20260728130831_Change_Unique_Index_Role_Entity` | | Provisioning role clone (step 3) |
| `20260729062510_Add_PlatformCommunicationProvider` | | **Welcome email never sends** |
| `20260729111750_Add_TrialDurationDays_Plan` | | Trial length |
| `20260730133824_Add_Invoice_SubscriptionPayment` | | Billing screens |
| `20260731045638_Add_PaymentGatewayCurrency` | | Gateway config |
| `20260731075733_Add_PlatformPaymentGateways` | | Gateway picker in the wizard |
| `20260803070336_Add_FeatureConfiguration_FeatureMenuMap` | | Plan → menu gating |
| `20260803101432_Add_OrgDetails_Fields_To_Lead` | | Lead form fields |
| `20260803124842_Add_LeadAssignment` | | Lead ownership |
| `20260804055257_Add_UserNotificationPreference` | | Notification preferences panel |
| `20260804115147_Add_RbacRollout_Entities` | | Platform staff / RBAC admin |

**If any are missing:** `dotnet ef database update` brings them all forward in order. You own this — I do not run it.

### 1.2 ★ Is the template organisation ready? (**the #1 demo blocker**)

Provisioning **throws at step 3** without this. If this query returns nothing, the onboarding demo cannot run at all.

```sql
-- a) does the template company exist?
SELECT "CompanyId", "CompanyName", "ShortName", "IsActive", "IsDeleted"
FROM app."Companies"
WHERE "ShortName" = '__TEMPLATE__' OR "CompanyName" ILIKE '%TEMPLATE%';

-- b) does it have roles to clone? (expect > 0, ideally 4-6)
SELECT r."RoleName", COUNT(rc.*) AS capability_count
FROM auth."Roles" r
LEFT JOIN auth."RoleCapabilities" rc ON rc."RoleId" = r."RoleId"
WHERE r."CompanyId" = (SELECT "CompanyId" FROM app."Companies" WHERE "ShortName" = '__TEMPLATE__')
GROUP BY r."RoleName"
ORDER BY r."RoleName";

-- c) is there a SYSTEMROLE row? (provisioning step 8)
SELECT "RoleId", "RoleName", "CompanyId" FROM auth."Roles"
WHERE "RoleName" ILIKE '%SYSTEM%' OR "RoleCode" = 'SYSTEMROLE';

-- d) ADMINISTRATOR staff category? (provisioning step 8b)
SELECT * FROM app."StaffCategories" WHERE "CategoryName" ILIKE '%ADMIN%';
```

> ⚠️ **Verify the schema and column names in the four queries above against your model before running.** They are written from `HostTenantResolver.cs` (`Companies.ShortName`, `Companies.Subdomain`, `Companies.CustomDomain`, `IsActive`, `IsDeleted`) and from the seed-file names; the RBAC tables live in **`auth`**, companies in **`app`**. If a table name is wrong, fix the query — do not conclude the data is missing.

**All four must return rows.** If not → §2 step 2 is your whole evening.

### 1.3 Is there a plan to provision against?

```sql
SELECT p."PlanCode", p."PlanName", p."TrialDurationDays", p."IsActive",
       (SELECT COUNT(*) FROM billing."PlanQuotas"       q WHERE q."PlanId" = p."PlanId") AS quotas,
       (SELECT COUNT(*) FROM billing."PlanEntitlements" e WHERE e."PlanId" = p."PlanId") AS features,
       (SELECT COUNT(*) FROM billing."PlanPrices"       x WHERE x."PlanId" = p."PlanId") AS prices
FROM billing."Plans" p ORDER BY p."PlanCode";
```

Expect four plans (`FREE`, `PLAN_50K`, `PLAN_100K`, `CUSTOM`), each with **quotas > 0, features > 0, prices > 0**. A plan with zero quotas fails closed — the new tenant will be blocked from everything the moment they log in.

### 1.4 Can the platform send email?

The system is **fail-closed by design** — no provider configured means no mail, silently, forever.

```sql
SELECT "PlatformCommunicationProviderId", "ChannelCode", "ProviderName", "IsActive"
FROM ops."PlatformCommunicationProviders" WHERE "ChannelCode" = 'EMAIL';
```

Must return at least one **active** row with real SendGrid credentials. If not, the welcome email in the wizard demo silently does nothing and you'll be standing there refreshing an empty inbox.

### 1.5 Everything else

```sql
-- notification templates (empty = every preference panel is blank)
SELECT COUNT(*) FROM app."NotificationTriggerTemplates";     -- expect > 0

-- email job statuses
SELECT md."DataCode" FROM app."MasterDatas" md
JOIN app."MasterDataTypes" t ON t."MasterDataTypeId" = md."MasterDataTypeId"
WHERE t."TypeCode" = 'EMAILSENDJOBSTATUS' ORDER BY 1;
-- expect: CANCELLED, COMPLETED, FAILED, PAUSED, PENDING, PROCESSING, QUEUED, SENDING

-- platform capabilities (0 = the control plane menu is empty)
SELECT COUNT(*) FROM auth."Capabilities" WHERE "CapabilityCode" LIKE 'PLATFORM%';

-- go-live checklist statuses
SELECT COUNT(*) FROM ops."TenantGoLiveChecklists";
```

---

## 2. Apply the backlog — tonight, in this order

**Back up the database first.** `pg_dump` before the first script. Non-negotiable — you have one night and no room for a bad restore.

| # | Action | Blocks |
|---|---|---|
| 1 | `dotnet ef database update` — brings all 15 migrations forward | Everything |
| 2 | ★ `ops-template-company-seed.sql` | **Provisioning step 3** |
| 3 | `system-staff-category-and-admin-staff-backfill.sql` (**PART A**) | Provisioning step 8b |
| 4 | `fix-aram-tenant-systemrole-assignment.sql` + `fix-aram-tenant-rolecapability-backfill.sql` | Provisioning step 8 |
| 5 | `plan-role-baseline-bootstrap-seed.sql` | New tenant's roles |
| 6 | `ops-platform-plan-view-capability-seed.sql` — **before** #7 | Plans screen |
| 7 | `billing-plan-trial-duration-seed.sql` | Trial length |
| 8 | `billing-communication-quota-seed.sql` | Email quotas |
| 9 | `billing-capability-seed.sql` + `billing-platform-settings-seed.sql` → **restart the app** | Billing menu |
| 10 | `ops-platform-communication-provider-seed.sql` | **Welcome email** |
| 11 | `notification-trigger-templates-seed.sql` + `notification-platform-settings-seed.sql` | Notification panels |
| 12 | `platform-staff-rbac-seed.sql`, `platform-menu-capability-backfill-seed.sql`, `platform-tenant-access-menu-seed.sql` | Control-plane menus |
| 13 | `paymentgateway-capability-seed.sql` + `billing-gateway-platform-seed.sql` | Gateway picker |
| 14 | `masterdata-combined-menu-seed.sql` | Masters screens |
| 15 | `ops-backfill-golive-status.sql` | Go-live checklist |
| 16 | `fix-tenant-currency-from-country-backfill.sql` → **restart** | Currency display |

**After every restart, re-run §1.** A seed that silently did nothing is worse than one that errored.

> Steps 2, 3, 4 are the ones that decide whether tomorrow's demo exists. Do them first, then re-run §1.2 and confirm all four queries return rows before moving on.

---

## 3. Rehearsal — tomorrow morning, 09:00

Run the **whole demo, out loud, on the real environment**, twice. Not a click-through in your head.

| # | Rehearse | Passes if |
|---|---|---|
| 1 | Log in to `admin.` control plane as platform staff | Menu renders, no empty sections |
| 2 | Create a lead → qualify → commercial terms → approve → won | Lands in the wizard |
| 3 | Run the 7-step onboarding wizard end to end | **Status Active, no failed step** |
| 4 | Watch the provisioning monitor during the run | Steps go green one by one |
| 5 | Welcome email actually arrives | Real inbox, real link |
| 6 | Click the activation link, set a password, log in as the new tenant admin | Tenant home renders |
| 7 | New tenant: menus match the plan | No 403s, no blank pages |
| 8 | Record a donation → issue a receipt | Receipt number generated |
| 9 | Create a contact → send a one-to-one email from their record → the email appears in their Communication tab | ✅ **Built** — `ComposeEmailDrawer`, from the sidebar or the Communication tab. Confirm the contact has an active email address and is not opted out, or the send returns "not sent" with no error |
| 10 | Build a bulk email campaign, send to a 3-person test list | Mail arrives |
| 11 | Publish an online donation page → make a test card donation | Money shows in the donation list |
| 12 | Create a case → approve → disburse | Status moves |
| 13 | Volunteer register + public registration page | Submission appears |
| 14 | Ticketed event → registration → ticket income | Income shows |
| 15 | Company Settings + General Settings render and save | No errors |
| 16 | Users · Roles & permission matrix | Matrix renders and saves |

**Write down every break with a screenshot.** That list — and only that list — feeds §4.

---

## 4. Fix window — tomorrow 12:00 to 16:00

Four hours. Triage everything found in §3 into exactly one bucket:

| Bucket | Rule | Action |
|---|---|---|
| **A — Blocks a demo scene** | The scene cannot be shown at all | Fix now |
| **B — Ugly but demonstrable** | Works, looks wrong | **Skip.** Mention it as "polish in progress" |
| **C — Not in the demo script** | Nobody will click it | **Do not touch** |

Known bucket-A candidates, in likely order:

| Candidate | Evidence | Demo scene |
|---|---|---|
| Contact screen `#18` is `status: NEEDS_FIX` | `PSS-2.0-CONTACT-PRODUCTION-READINESS-FIX-PROMPT.md` | Scene 9, 10 |
| Tenant comms config screens have UI/validation defects | `PSS-2.0-TENANT-COMMS-CONFIG-UI-FIX-PROMPT.md` | Scene 10 setup |
| `Auth:PlatformHosts` empty → `admin.` host is `Unknown` and **refuses every login** | `HostTenantResolver.cs:112` returns false when unset | Scene 1 — **fatal if you demo on a real hostname** |
| `NEXT_PUBLIC_UPGRADE_CONTACT` unset | Known gap | Upgrade prompt shows a blank contact |

> ⚠️ **The `Auth:PlatformHosts` one is a trap.** On `localhost` it works (Development bypass, `HostTenantResolver.cs:107-109`). The moment you demo on `admin.yourdomain.com` in a Production build, **nobody can log in**. Set it tonight — see the hosting guide, §3.

**A separate fix prompt exists for the code items:** `PSS-2.0-DEMO-BLOCKER-FIX-PROMPT.md`. Open it only after §3 tells you which items are real.

---

## 5. Freeze — 16:00

| Rule |
|---|
| No deploys after 16:00. None. |
| No SQL after 16:00 except a rollback. |
| Take a `pg_dump` at 16:00 and keep it open in a terminal. |
| Re-run §3 scenes 1–6 once more on the frozen build. |
| Record a 3-minute screen capture of the onboarding wizard as your §7 fallback. |
| Charge the laptop. Test the projector. Test the internet. |

---

## 6. Demo script — 17:00, ~35 minutes

Tell it as a story about **one charity**, not a tour of screens.

| # | Scene | Say | Min |
|---|---|---|---|
| 1 | Enquiry lands | "A charity fills in our website form. It arrives as a lead." | 2 |
| 2 | Lead → deal | "Our sales team qualifies it, sets commercial terms, gets approval." | 3 |
| 3 | **Onboarding wizard** | "Seven steps. Then the system builds their entire organisation — roles, menus, settings, reference data — automatically." | 6 |
| 4 | Provisioning monitor | "We watch it build, step by step. Any step can be retried on its own." | 2 |
| 5 | Welcome email | "They get their link. Under an hour from signature to live." | 2 |
| 6 | Tenant logs in | "This is their system. Their branding, their menus — only what their plan includes." | 3 |
| 7 | Donation + receipt | "Money in, receipted, numbered by their own rules." | 4 |
| 8 | Public donation page | "Their own branded page, live on the web, taking card payments." | 4 |
| 9 | Email one donor from their record → then a bulk campaign | "They can email one donor personally — and it's logged on that donor's record. Or email all of them at once, with delivery tracked." | 4 |
| 10 | Case → approval → disbursement | "And money out, to the people they serve." | 3 |
| 11 | Roles & permissions matrix | "They control exactly who sees what." | 2 |
| 12 | Close | "Money in, money out, the people on both sides. That's MVP-1." | 1 |

**Scene 3 is the demo.** If everything else fails, that one scene still sells the product. Rehearse it three times.

### Say this once, up front

> *"Plan names and limits on screen are worked examples for illustration — the final packaging is management's decision."*

That is straight from the MVP-1 scope doc §3 and it stops the whole meeting derailing into a pricing debate.

### If asked what's not in MVP-1

Have the honest list ready — it reads as control, not as a gap:

> Pledges · volunteer **login** portal · SMS and WhatsApp campaigns · general (non-ticketed) events · membership · prayer requests · field collection · certificates · advanced reports. **And our own subscription billing is manual invoicing in MVP-1** — that's deliberate, not missing.

---

## 7. Fallbacks — decide these before you walk in

| If this fails | Do this |
|---|---|
| Onboarding wizard breaks mid-run | Play the §5 screen recording. **Say so plainly** — do not pretend it's live. |
| Welcome email doesn't arrive | Show the activation link from the provisioning monitor and continue. |
| Payment gateway sandbox is down | Show a previously-recorded donation in the list. |
| Bulk email doesn't send | Show the campaign builder + a previously-sent campaign's delivery report. |
| One-to-one email returns "not sent" | It's a blocked outcome, not a crash — missing address, opted out, or no provider. Show the Communication tab history instead and move on. |
| The whole environment is down | Screen recording of scenes 3–8, then walk the slides. |
| A screen 500s | Don't debug on stage. "That's a known item in the fix list." Move on. |

**The one rule:** never debug live in front of management. Move to the fallback, finish the story, follow up by email.

---

## 8. What is explicitly NOT happening before the demo

| Not doing | Why |
|---|---|
| Metering / plan email limits | New behaviour on the path you're about to demo. Post-demo. |
| Bulk-email job reliability | Same file. Post-demo. |
| Marketing website (P-20) | Not in the demo script. Show the enquiry form only. |
| P-21 lead ownership · P-23 commercial terms UX · P-24 platform staff | Not in the script. |
| Any migration you don't already have written | No new schema in the last 24 hours. |

---

## 9. Open items management may ask about — have an answer

| They'll ask | Answer |
|---|---|
| "When can we sell it?" | Once the plan limits and prices are signed off — that's §3 and §6.2 of the scope doc, and it's **your decision, not development's**. |
| "What are the real limits?" | Not set. Needs a decision, sized for a **peak** month. |
| "Can a customer sign up themselves?" | MVP-2. Today our team runs the wizard — under an hour. |
| "Do we bill them automatically?" | Not in MVP-1. Manual invoicing, deliberately. |
| "Can each charity have their own web address?" | **Yes — already supported.** See `PSS-2.0-TENANT-DOMAIN-AND-COOLIFY-HOSTING-GUIDE.md`. |

---

## 10. Runbook log

| Time | Step | Result |
|---|---|---|
| | | |
