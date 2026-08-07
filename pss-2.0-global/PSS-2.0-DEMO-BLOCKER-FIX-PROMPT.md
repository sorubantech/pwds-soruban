# Demo Blocker Fix Prompt — MVP-1 demo, 6 Aug 2026 17:00

> **Status:** NOT BUILT (written 2026-08-05) · **Companion to** `PSS-2.0-MVP1-DEMO-READINESS-RUNBOOK.md`
> **Window:** tomorrow 12:00–16:00 only. Hard stop at 16:00.
> **Scope:** demo-blockers only. Read §0 before touching anything.

---

## ⚠️ Standing rules (non-negotiable)

1. **Do NOT run `dotnet build`.** The user builds the backend.
2. **Migrations are strictly user-owned.** Never run `dotnet ef migrations add/remove` or `database update`. Never hand-author a migration or snapshot. **This prompt must produce ZERO schema changes** — there is no time to apply one safely.
3. Seeds go to `sql-scripts-dyanmic/`. The user applies them.
4. Frontend typecheck: `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` with **no pipe**. Only exit 0 counts.
5. `PSS_2.0_Backend/` and `PSS_2.0_Frontend/` are gitignored — Grep/Glob return nothing. Use `find -iname`, or scope `grep -rn --include=*.cs` to **one** project subdirectory. Absolute-path `Read` works.
6. HotChocolate strips `Get` from resolver names and appends `Input` to input types. tsc cannot see gql field names — a wrong name builds clean and fails at runtime.
7. Every Postgres date column is `timestamp with time zone`. `DateTime.UtcNow` only.
8. Never assume a GraphQL field, DTO property, or column name — read the source first.

---

## §0 — Triage gate. Do not skip.

**Do not build anything in this file until the §3 rehearsal in the runbook has run.**

Each section below is **conditional**. Open a section only if the rehearsal proved that exact scene broken.

| Rule | |
|---|---|
| Blocks a demo scene entirely | Fix |
| Works but looks wrong | **Skip** — say "polish in progress" |
| Not in the demo script | **Do not touch** |
| Needs a migration | **Do not fix.** Use the §7 fallback instead |

Budget the four hours as: **2h fixing · 1h re-testing · 1h buffer.** If a fix is not landing within 45 minutes, abandon it and take the fallback.

---

## §1 — `Auth:PlatformHosts` is empty (config, not code) — **do this first, 10 minutes**

**Severity:** fatal on a real hostname. **Effort:** 10 min. **Risk:** none.

### Symptom
On `localhost` everything works. Deployed to `admin.yourdomain.com` in a Production build, **every login is refused** and the control plane is unreachable.

### Root cause
`Base.Infrastructure/Services/Auth/HostTenantResolver.cs` — `IsPlatformHost`:

```csharp
var configured = configuration.GetSection(PlatformHostsConfigKey).Get<string[]>();
if (configured == null || configured.Length == 0) return false;   // ← empty = NO host is platform
```

The loopback bypass (`localhost`, `127.0.0.1`, `[::1]`) only applies in the Development environment. In Production, an empty list means the host resolves to `HostKind.Unknown`, which fails closed.

### Fix — configuration only, no code

Set on the **backend** resource in Coolify:

```
Auth__PlatformHosts__0=admin.yourdomain.com
Auth__PlatformHosts__1=yourdomain.com
```

(Double underscore, zero-indexed — that is how .NET binds env vars to config arrays.)

Note `Normalize()` strips a leading `www.`, so `www.yourdomain.com` arrives as `yourdomain.com` — list the bare apex, not the `www.` form.

**Do not** list `app.yourdomain.com`. That host must fall through to tenant resolution.

### Verify
1. Restart the backend.
2. Load `https://admin.yourdomain.com` → platform login renders, credentials accepted.
3. Load `https://<tenant>.app.yourdomain.com` → tenant branding renders.

Full context: `PSS-2.0-TENANT-DOMAIN-AND-COOLIFY-HOSTING-GUIDE.md` §3.

---

## §2 — Contact screen `#18` (`status: NEEDS_FIX`) — **only if scene 9 breaks**

**Condition:** open this only if the rehearsal shows the contact list or contact form erroring, or a required field failing to save.

**Source of truth:** `PSS-2.0-CONTACT-PRODUCTION-READINESS-FIX-PROMPT.md`. That prompt is the full fix and is almost certainly larger than four hours.

### How to use it under time pressure

**Do not execute that prompt.** Instead:

1. Open it and read its defect list.
2. Identify **only** the defects that break the specific action in demo scene 9 (create a contact, then send them one email).
3. Fix those. Leave every other defect.
4. Record in that prompt's build log which defects you cherry-picked, so the post-demo run knows what is already done.

### Triage priority within it

| Priority | Defect class | Why |
|---|---|---|
| 1 | Contact **create** throws or silently fails | Blocks the scene |
| 2 | Contact list 500s or renders empty | Blocks the scene |
| 3 | Required-field validation blocks a valid save | Blocks the scene |
| 4 | Duplicate detection, merge, import, bulk ops | **Skip** — not in the script |
| 5 | Any labelling, spacing, icon, or empty-state issue | **Skip** |

### If the fix needs a migration
**Stop.** Use the fallback: demo with a contact created before the demo, and show the list rather than the create form.

---

## §3 — One-to-one contact email — ✅ **VERIFIED BUILT. Demo it. Do not touch it.**

> **Correction (2026-08-05):** an earlier draft of this file said this feature was not built. **That was wrong.** It is fully implemented and wired end to end on both sides. It is a demo asset, not a demo risk.

### Evidence

| Layer | File | Note |
|---|---|---|
| Command + validator | `Base.Application/.../ContactBusiness/ContactCommunications/CreateCommand/SendContactEmail.cs:49` | `SendContactEmailHandler`, injects `IEmailTemplateService` |
| Send call | same file `:156` | `SendComposedEmailForCompanyAsync(emailDto, companyId)` |
| GraphQL mutation | `Base.API/EndPoints/Contact/Mutations/ContactMutations.cs:228` | `SendContactEmail` → schema field `sendContactEmail` |
| History query | `Base.API/EndPoints/Contact/Queries/ContactQueries.cs:155` | `GetContactCommunications` → schema field `contactCommunications` |
| FE mutation | `src/infrastructure/gql-mutations/contact-mutations/ContactCommunicationMutation.ts:22` | correct field name, gotcha documented in the file header |
| FE query | `src/infrastructure/gql-queries/contact-queries/ContactCommunicationQueries.ts:22` | ditto |
| FE drawer | `.../crm/contact/contact/detail/communication/compose-email-drawer.tsx:80` | `ComposeEmailDrawer` |
| Reachable from | `detail/contact-sidebar.tsx:359` **and** `detail/tabs/communication-tab.tsx:306` | two entry points |

Both gql files explicitly document the HotChocolate naming rule, so the usual silent runtime-only failure mode does not apply here.

### ⚠️ Two things that make it *look* broken during a demo

The handler **never rethrows on a send failure** (`SendContactEmail.cs:143` — *"Send via provider — never rethrow on failure"*). A blocked or failed send is persisted as compliance evidence and returned with `sent=false`. So on stage you get a polite "not sent" toast rather than an error — and no clue why.

The three blocked outcomes are `DO_NOT_EMAIL`, `NO_ADDRESS`, `RATE_LIMIT`. Before the demo, confirm on the demo contact:

| # | Check | Why |
|---|---|---|
| 1 | The contact has **at least one active email address** | Otherwise `NO_ADDRESS` → silent `sent=false` |
| 2 | The contact is **not** flagged do-not-email / opted out | Otherwise `DO_NOT_EMAIL` → silent `sent=false` |
| 3 | The **platform email provider is configured and active** | Runbook §1.4. Fail-closed by design — no provider, no mail, no error |

Do this in the rehearsal, not on stage.

### Action
**None.** Add it to the demo script as its own beat — see the runbook scene 9. It is a stronger demo moment than a bulk campaign because it shows the contact's communication history filling up straight afterwards.

---

## §4 — Tenant communication config screens — **only if scene 10 setup breaks**

**Condition:** the rehearsal cannot configure an email provider for the demo tenant.

**Source:** `PSS-2.0-TENANT-COMMS-CONFIG-UI-FIX-PROMPT.md`. Its **Phase 1 is 17 frontend-only steps** — no backend, no migration. That makes it unusually safe for a same-day fix.

### Triage

| Fix | Do it? |
|---|---|
| A field that must be filled cannot be filled (missing input, broken validation, disabled Save) | ✅ Yes |
| Save succeeds but the value doesn't persist | ✅ Yes |
| The screen 500s | ✅ Yes |
| Label wording, spacing, chip colour, icon choice | ❌ Skip |
| SMS / WhatsApp tabs | ❌ Skip — MVP-2, and MVP-1 shows them disabled with "Coming soon" by design |

### Shortcut if the screen is unusable
Configure the demo tenant's provider **directly in the database** tonight, and demo the screen read-only. Scene 10 needs mail to *send*; it does not need you to configure it live.

---

## §5 — `NEXT_PUBLIC_UPGRADE_CONTACT` unset — **5 minutes, do it**

**Symptom:** the plan-limit upgrade prompt renders with a blank contact — visible in scene 6/7 if a quota warning fires.

**Fix:** set the env var on the frontend resource in Coolify to a real sales email or phone. Redeploy the frontend.

**No code change.** If you cannot redeploy before the freeze, skip it — the odds of a quota warning firing during a 35-minute demo are low.

---

## §6 — Explicitly NOT in this prompt

| Excluded | Why |
|---|---|
| `PSS-2.0-COMMUNICATION-METERING-BUILD-PROMPT.md` | New behaviour on the exact path scene 10 demos |
| `PSS-2.0-BULK-EMAIL-JOB-RELIABILITY-BUILD-PROMPT.md` | Same files as above; also depends on metering shipping first |
| P-20 marketing site · P-21 lead ownership · P-23 commercial terms UX · P-24 platform staff | Not in the demo script |
| Anything needing a migration | No new schema in the last 24 hours |
| `ProvisionTenant` step 2 hard-coded 14-day trial | Cosmetic in the demo; the trial length is not on screen |
| Provisioning step 9 welcome email | ✅ **Verified already correct** — honours the send result, logs a warning on failure, deliberately does not fail provisioning |
| SUPERADMIN landing-page redirect | Open decision, not a blocker — navigate manually |

---

## §7 — Fallbacks (use these instead of a risky fix)

| Broken | Fallback |
|---|---|
| Contact create | Use a pre-created contact; show the list |
| One-to-one email | Bulk campaign with a one-person list (§3) |
| Comms config screen | Configure in the database; show the screen read-only |
| Any screen 500s | "Known item in the fix list." Move on. **Never debug on stage.** |
| Onboarding wizard | The screen recording taken at the 16:00 freeze |

---

## §8 — Acceptance

Before the 16:00 freeze:

1. ☐ Every fix applied is listed here with the file and line changed
2. ☐ `npx tsc --noEmit --incremental false` exits **0** (frontend changes only)
3. ☐ Backend compiles — **user runs this**
4. ☐ Runbook §3 scenes **1 through 8 re-run clean** on the frozen build
5. ☐ Scene 10 (bulk email) retested if **any** email-path file was touched
6. ☐ Screen recording of scenes 3–8 captured
7. ☐ `pg_dump` taken at 16:00
8. ☐ Nothing in §6 was built

---

## §9 — Open questions

| # | Question | Blocks |
|---|---|---|
| Q1 | Is the demo on `localhost` or a real hostname? | If real → **§1 is mandatory, do it tonight** |
| Q2 | What is the production platform hostname? | §1's exact value |
| Q3 | Is the payment gateway in sandbox or production for the demo? | Scene 8 |
| Q4 | Which tenant is the demo tenant — new via the wizard, or pre-created? | Scenes 3–7 |

> Q1 and Q2 need answering **tonight**, not tomorrow. §1 is a config change plus a restart, and it is the single fix here that turns a total demo failure into a working one.

---

## §10 — Build log

| Date | Section | What was done | Result |
|---|---|---|---|
| | | | |
