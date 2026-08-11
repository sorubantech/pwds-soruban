# PSS 2.0 — Product-Shell Feature Exploration

> **Status:** EXPLORATION — no build authorised yet. This is a catalogue, not a build prompt.
> **Trigger:** demo conducted 2026-08-11; management not satisfied with the UI.
> **Ask:** research what real CRM / SaaS / collaboration products ship on the *tenant* side and the
> *platform* side, list what we should add, and ship it **dummy-first** — real wiring later.

---

## ① The diagnosis (and where I disagree with the obvious read)

Your own reading was: *"we included the feature only we focusing business — that's the reason our
application UI is just simple."* That is **half right**, and the other half matters more.

**What is true:** we have deep business-domain coverage — 24 CRM modules, donations, grants, cases,
events, memberships, volunteers, P2P, receipting, dashboards, RBAC, audit, billing. Almost every
screen is a **grid or a form**. A demo that walks module → grid → form → grid → form reads as an
*admin tool*, not a *product*, no matter how correct the data model is.

**What is not true:** that we have *no* product shell. We already have a command palette, a global
search dialog with business + menu results, a live notification panel, theme switching, fullscreen,
a plan-status chip. Someone built that layer. See §② for the evidence.

**So the real gap is not "we have no shell" — it is three narrower things:**

| # | Gap | Why the demo felt flat |
|---|-----|------------------------|
| **G-1** | **The shell we have is invisible during a demo.** `Cmd+K` is bound in two places but nothing on screen advertises it. Nobody presses a shortcut they were never shown. | The best thing we own was never demonstrated |
| **G-2** | **Nothing in the product is *alive*.** No activity feed, no comments, no @mentions, no presence, no "what changed since I was last here". Every screen is a static read of a table. | ClickUp/Monday feel alive because work is visibly happening *between people*. Ours shows rows |
| **G-3** | **The AI story is a menu of dead links.** `crm/intelligence` has 6 routes — actionboard, aidraft, aireporting, churnprediction, engagementscoring, predictiveanalytics — and **all 6 are `UnderConstruction`**. | Worse than no AI. A prospect clicks "AI Reporting" and hits a hard-hat page |

**G-3 is the one that likely cost us the demo.** We advertised AI in the navigation and delivered a
404-with-a-cone. That is the single highest-return thing to fix, and it is exactly the "dummy-first"
approach you asked for.

---

## ② What we already have (verified on disk, 2026-08-11)

Do not rebuild these. Surface them better.

| Surface | File | State |
|---|---|---|
| Command palette | `layout-components/command-palette/index.tsx`, fed by `app-topbar/index.tsx:84-230` | **Real.** Grouped by active module sections |
| `Cmd/Ctrl+K` binding | `app-topbar/index.tsx:136`, `global-search/inline-search-bar.tsx:174` | **Real, but undiscoverable** |
| Global search (menu + business results, tabs, debounce, empty state) | `layout-components/global-search/global-search.tsx` (482 lines) | **Real** — `GLOBAL_SEARCH_QUERY` |
| Notification panel (unread count, Unread/All filter, paging, mobile Sheet) | `custom-components/notifications-panel/index.tsx` (254 lines) | **Real** — `useFetchNotifications`, `useNotificationCount` |
| Notification centre + templates | `crm/notification/notificationcenter`, `/notificationtemplate` | **Real page configs** |
| Automation workflow | `crm/automation/automationworkflow` | **Real page config** |
| Theme toggle / fullscreen / profile / plan chip | `app-topbar/index.tsx:217-219` | **Real** |
| Tenant brand accent system | `useShellAccent` + `presentation/utils/brand-surface.ts` | **Real** — tenant colours already flow into the shell |
| Platform console | `(master)/ops/*` — tenants, leads, onboarding/provision, provisioning-runs, tenant-access, plans, audit, data-cleanup, deals, intimations, notifications; `(master)/platform/*` — billing, communications, gateways, staff, webhook-logs, dashboards | **Real and unusually complete** |
| **AI module** | `crm/intelligence/*` — 6 routes | ❌ **All `UnderConstruction` stubs** |
| Header inbox | `layout-components/header/inbox.tsx` | ❌ **Dead** — data import and badge both commented out |

---

## ③ What real products ship — the reference sweep

### Collaboration tools (ClickUp, Monday.com)
- **ClickUp:** 15+ view types (List, Board, Gantt, Timeline, Calendar, Table, Mind Map), 50+
  dashboard widget types, sprint burndown, custom formula fields, ~10,000 automations/month,
  workload view, custom exports.
- **Monday.com:** 27+ views with **one-click switching** on the same data, cross-board reporting,
  real-time widgets, custom chart types. Reads *simpler* than ClickUp — deliberately.
- Both: no-code automation builder ("when X, do Y"), file attachments with commenting, @mentions,
  activity log per record, time tracking (paid tiers).

**The transferable lesson is not "add 27 views."** It is: *the same data, re-presented on demand,
feels like far more product than one grid.* We have `MASTER_GRID` everywhere — a **view switcher**
(Table / Board / Calendar / Timeline) over the grid we already render is the cheapest possible way
to multiply perceived surface area.

### Modern CRM shells
- Command palette (Linear is the gold standard; now a **standard expectation** in any SaaS with more
  than ~10 features) — *we have this*.
- In-app resource/support centre widget (CommandBar, UserGuiding) — docs, search, "contact support",
  changelog, all behind one persistent launcher.
- Product tours, onboarding checklists, nudges, hotspots, empty-state prompts.
- **Targeted**, not broadcast, feature announcements.
- In-app notification centre — *we have this*.

### AI layer (HubSpot Breeze, Microsoft Copilot for Sales, Attio)
- **Embedded copilot sidebar** — drafts emails, summarises a record, pulls a report, answers in
  natural language, always available on the right edge.
- **Natural-language search over records** — Attio's "Ask": *"which open enterprise deals haven't had
  a touch point in 30 days?"*
- **AI summarisation** — record summaries, opportunity summaries with health / recent changes /
  next steps.
- **Next-best-action** recommendations on the record.
- Auto tagging, routing, record updates.

### Nonprofit domain (our actual market)
- **Bloomerang** — donor-retention-first: engagement scoring, retention dashboards, audit-ready
  documentation tying donor history to reporting filters. *Weak* on events, auctions, membership,
  major gifts — **all of which we already have.**
- **Salesforce NPSP** — multi-entity structures, complex grant accounting, planned giving.
- **Blackbaud Raiser's Edge NXT** — cultivation tools, built-in analytics, data enrichment,
  constituent relationship model with attribution reporting.

**Worth saying out loud to management:** on *domain* features we are competitive with Bloomerang and
ahead of it on events/membership/grants. We are behind on *shell*. That is a much cheaper gap to
close than the reverse would have been.

### Multi-tenant admin console (platform side)
- **Impersonation / login-as** with: reason required, elevated authentication, limited duration,
  **visible in-product indicator**, and a complete audit event.
- Tenant-aware audit logging — actor, tenant, action, resource type, outcome.
- Tenant-aware monitoring: logs, traces, metrics and audit records all carry a tenant identifier
  *without* exposing customer data.
- Per-tenant feature flags encoded as entitlement claims in the access token.
- Break-glass roles with just-in-time elevation and time-bounded sessions.

---

## ④ Tenant-side catalogue

Effort is FE-only dummy build unless noted. **Demo value** = how much it moves a live walkthrough.

| ID | Feature | What the dummy is | Effort | Demo value |
|----|---------|-------------------|:---:|:---:|
| **T-1** | **AI Copilot sidebar** — right-edge drawer, always available, tenant-branded. Suggested prompts per screen ("Summarise this donor", "Draft a thank-you", "Who lapsed this quarter?") | Scripted responses keyed to the current route. Typing indicator, streaming-style reveal, source chips. **Visible "Preview" badge.** | M | ★★★★★ |
| **T-2** | **Kill the 6 `UnderConstruction` AI routes** — replace with designed screens on canned data | `aireporting` → NL question box + chart; `churnprediction` → at-risk donor list with scores; `engagementscoring` → score distribution; `actionboard` → next-best-action cards; `aidraft` → email draft composer; `predictiveanalytics` → forecast chart | M | ★★★★★ |
| **T-3** | **Ask-your-data box** — natural-language query over records, on every index page | Fixed question→result mapping for ~8 demo questions; falls back to "I can't answer that yet" | S | ★★★★☆ |
| **T-4** | **AI record summary card** — top of every detail/drawer view | Template-generated from fields we already have (last gift, total, tenure) — *this one can be real on day one, no LLM needed* | S | ★★★★☆ |
| **T-5** | **Multi-view switcher over MASTER_GRID** — Table / Board / Calendar / Timeline toggle | Board + Calendar render the same rows client-side. No new queries | M | ★★★★★ |
| **T-6** | **Saved views** — named filter+column+sort combos, personal and shared, pinned as tabs | Persist to `sett` KV or localStorage for the dummy | M | ★★★★☆ |
| **T-7** | **Activity feed / timeline per record** — who did what, when | Derive from existing audit rows (`createdDate`/`modifiedDate` + audit module). Largely real already | M | ★★★★☆ |
| **T-8** | **Comments + @mentions on records** | Local-state thread with avatars; @ opens a real user picker (we have the users) | M | ★★★★★ |
| **T-9** | **Bug / feedback raiser** — persistent launcher, category (Bug / Idea / Question), description, screenshot attach, auto-captures route + browser + tenant + user | Writes to local state + a toast with a fake ticket ID. **Pairs with P-6** | S | ★★★★★ |
| **T-10** | **In-app help & resource centre** — one launcher: search docs, keyboard shortcuts, contact support, what's new | Static curated article list + shortcut sheet | S | ★★★☆☆ |
| **T-11** | **Discoverable `Cmd+K`** — a real search affordance in the topbar showing the `⌘K` chip, not just a hidden binding | **Wiring only — the palette exists.** Highest ratio of demo value to effort in this document | XS | ★★★★☆ |
| **T-12** | **Onboarding checklist + product tour** — post-setup "get started" card, dismissible, progress ring | We already have `TenantSetupChecklistWidget` — extend the same pattern past setup | S | ★★★☆☆ |
| **T-13** | **What's-new / changelog panel** — dot on the bell when unread | Static JSON of releases | XS | ★★★☆☆ |
| **T-14** | **Bulk actions on grids** — select rows → assign / tag / export / status change, with an undo toast | Toast + optimistic row update only | S | ★★★★☆ |
| **T-15** | **Automation builder canvas** — visual when/then rules | `crm/automation/automationworkflow` exists — needs the *canvas*, not a grid of rules | L | ★★★★☆ |
| **T-16** | **Presence** — "3 people viewing", avatar stack on shared screens | Fixed avatars | XS | ★★★☆☆ |
| **T-17** | **Personal notification preferences** — per-channel, per-event matrix | Real toggles, saved to UserSettings | S | ★★☆☆☆ |
| **T-18** | **Keyboard shortcut sheet** (`?`) | Static | XS | ★★☆☆☆ |
| **T-19** | **Fix the dead header inbox** (`header/inbox.tsx`) — either wire it to real messages or **delete it** | Deleting is a valid, immediate fix | XS | ★★☆☆☆ |

---

## ⑤ Platform-side catalogue

`(master)/ops` and `(master)/platform` are already substantial. These are the named gaps.

| ID | Feature | What the dummy is | Effort | Demo value |
|----|---------|-------------------|:---:|:---:|
| **P-1** | **Tenant health console** — one row per tenant: plan, seats used, storage, last activity, open tickets, health score, churn risk | Computed from real counts + a fake health formula | M | ★★★★★ |
| **P-2** | **Impersonation / login-as** — **reason required, time-boxed, persistent coloured banner while active, full audit event**. `ops/tenant-access` exists — check what it does before building | Do **not** dummy the audit trail. If we build the button, the audit write is real or the button doesn't ship | L | ★★★★☆ |
| **P-3** | **Cross-tenant audit log** — actor / tenant / action / resource / outcome, filterable | `ops/audit` exists — verify coverage | M | ★★★★☆ |
| **P-4** | **Usage & adoption analytics** — DAU/MAU per tenant, feature adoption heatmap, "tenants who never used X" | Seeded numbers, clearly labelled | M | ★★★★☆ |
| **P-5** | **Per-tenant feature flags** — toggle matrix, tenant × feature | Overlaps `billing.Features` / `FeatureMenuMaps` — **those are hand-curated, never generated.** Read that seed before designing | M | ★★★★☆ |
| **P-6** | **Support ticket inbox** — fed by T-9. Ticket → tenant → user → route → screenshot, with status and assignee | Static list, but the *pairing* with T-9 is what sells it. **Demo this immediately after T-9** | M | ★★★★★ |
| **P-7** | **Announcement broadcaster** — compose an in-product banner/notification, target by plan or tenant, schedule, see read rate | Compose UI + preview; no send | S | ★★★☆☆ |
| **P-8** | **Break-glass / JIT elevation** — request elevated access, reason, approver, auto-expiry | Design only. Do not fake an approval flow that grants nothing | M | ★★☆☆☆ |
| **P-9** | **Provisioning run timeline** — step-by-step with retry-from-failed-step. `ops/onboarding/provision` + `provisioning-runs` exist | Verify against the 9-step `ProvisionTenantCommand` design before touching | M | ★★★☆☆ |
| **P-10** | **Platform AI ops assistant** — "which tenants are at churn risk?", "who hasn't finished setup?" | Same scripted engine as T-1, different corpus | S | ★★★☆☆ |

---

## ⑥ Rules for dummy-first (this is the part that protects us)

Shipping placeholders is right. Shipping placeholders *badly* is how you get a worse demo than no
feature at all — which is exactly what `crm/intelligence` is today.

1. **Every dummy carries a visible marker.** A `Preview` / `Coming soon` chip in the screen header,
   in tenant accent, using `brandSoft`. Not a hidden footnote.
2. **A dummy is a designed screen with plausible data.** Never an `UnderConstruction` page, never an
   empty state, never a `TODO`. If we can't design it this sprint, **remove it from the menu** until
   we can — an absent feature beats a broken one.
3. **Nothing that writes is ever faked as succeeding.** A dummy may show a result; it may not claim
   it saved. "Preview — not yet saved" on any submit.
4. **Audit, impersonation, and permissions are never dummied.** If P-2's audit write isn't real, P-2
   doesn't ship. Faking a security control is the one failure mode with real consequences.
5. **Canned data lives in one file per feature**, typed, so the swap to a real query is a
   one-import change.
6. **House rules still apply**: design tokens not hex/px; solid `bg-X-600` + `text-white` for icon
   containers / badges / chips (never `bg-X-50`, `text-X-700`, `bg-muted` as status); shaped
   Skeletons; @iconify Phosphor icons; `tabular-nums` + `text-right` on money; xs→xl responsive;
   Save gated on RHF `isValid`, never on `canCreate`.
7. **Tenant accent, always.** Read `--shell-accent` via `brand-surface.ts` — never `bg-primary-600`,
   which paints the static platform violet on a tenant's page.

---

## ⑦ What I'd actually put in the next demo

Not the whole catalogue. Eight items, chosen so a 10-minute walkthrough changes character. All FE,
all dummy-safe, no migrations.

| Order | Item | Why it's in |
|---|---|---|
| 1 | **T-11** discoverable `⌘K` | Wiring only. We already own the palette — we just never showed it |
| 2 | **T-2** the six AI routes | Stops the active bleeding. Today they are hard-hat pages under an "Intelligence" menu |
| 3 | **T-1** AI copilot sidebar | The single most "modern product" signal available to us |
| 4 | **T-5** multi-view switcher | Turns every existing grid into four screens. Monday's whole trick |
| 5 | **T-8** comments + @mentions | Makes the product feel occupied by people |
| 6 | **T-9** bug raiser | You named it. Cheap, and it earns goodwill in the room |
| 7 | **P-6** support inbox | Demo T-9 then immediately show the ticket land platform-side. **This pair is the money shot** |
| 8 | **P-1** tenant health console | Answers "how do you run this at scale?" before it's asked |

Rough shape: 2 short FE builds. Items 1–2 and 6–7 are the fast half and could stand alone if time
is tight.

**One thing I'd argue against:** do not chase ClickUp's 15 views or 50 widget types. Monday reads as
the better product to most buyers *because* it is simpler, and our buyer is a nonprofit
administrator, not a software team. Four views, done well, beats fifteen.

---

## ⑧ Open questions before any build prompt is written

1. `ops/tenant-access` — is that already impersonation? Determines whether **P-2** is new or a polish job.
2. `ops/audit` — cross-tenant, or platform-actions-only? Determines **P-3**.
3. `crm/automation/automationworkflow` — grid of rules, or a canvas? Determines **T-15**'s size.
4. `crm/notification/notificationcenter` vs the topbar `NotificationsPanel` — two surfaces on one
   dataset, or two datasets? If two, that's a defect, not a feature.
5. Do we want **T-1** to eventually be a real LLM call, or permanently a scripted assistant? Changes
   how the component boundary is drawn today.

---

## ⑨ Sources

Product shell / adoption: [Custify](https://www.custify.com/), [SaaS UI Design](https://saasui.design/),
[UserGuiding](https://userguiding.com/), [Product Fruits](https://productfruits.com/).
AI in CRM: [Worknet](https://worknet.ai/), [Zendesk](https://www.zendesk.com/),
[Zapier](https://zapier.com/), [Kustomer](https://www.kustomer.com/),
[Microsoft Learn — Copilot for Sales](https://learn.microsoft.com/).
Nonprofit CRM: [Bloomerang](https://bloomerang.co/), [RallyUp](https://rallyup.com/),
[DNL OmniMedia](https://www.dnlomnimedia.com/), [Cube84](https://cube84.com/).
Multi-tenant admin & impersonation: [SuperTokens](https://supertokens.com/),
[WorkOS](https://workos.com/), [Qrvey](https://qrvey.com/).
Collaboration: [Monday.com](https://monday.com/), [Plutio](https://www.plutio.com/),
[Cloudwards](https://www.cloudwards.net/), [ZenPilot](https://www.zenpilot.com/).

---

## ⑩ Log

### 2026-08-11 — exploration written
Route inventory scanned (`src/app/[lang]` depth 4), topbar composition read
(`app-topbar/index.tsx:1-230`), `global-search.tsx`, `notifications-panel/index.tsx`,
`header/inbox.tsx`, and all `crm/intelligence` + `crm/automation` + `crm/notification` page files
inspected. Key correction to the working assumption: **the command palette, global search and
notification centre already exist and are real** — the gaps are AI (all stubs), collaboration
(absent), and discoverability (present but hidden). No files changed.
