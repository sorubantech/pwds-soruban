# PSS 2.0 — Production Cutover Checklist

**Compiled 2026-08-09 · deferred from the DEV/UAT release of 2026-08-10**

This file exists so that tonight's deferrals are *recorded decisions*, not forgotten ones.

Every item below was verified against source on 2026-08-09 and consciously left out of the
UAT release because it is not a UAT blocker. **None of them stop being real.** They stop being
urgent only for as long as the two conditions below hold.

---

## The two conditions this deferral depends on

The UAT release is defensible **only** while both remain true:

1. **No real donor or beneficiary PII in the UAT database.** The CQRS pipeline is default-open
   (see C-1) and the media upload endpoint is anonymous by design. Both are acceptable against
   seeded test data and unacceptable against real people's records.
2. **Sandbox payment gateway credentials only.** No live gateway keys in an environment whose
   credential-encryption key is committed to the repository (see A-1).

**If either condition breaks, the corresponding section below becomes blocking immediately —
regardless of environment name.** A "UAT" server holding real donor records is a production
system with a misleading label.

---

## A. Secrets — do these before any internet-facing deploy

### A-1. Rotate everything currently committed to `appsettings.json`
`PeopleServe/Services/Base/Base.API/appsettings.json` is **git-tracked** and contains live
credentials. Deleting the file does not help: the values are in git history and are compromised
the moment the repo is cloned, shared or forked. **Rotation is the fix.**

| Secret | Location | Notes |
|---|---|---|
| JWT signing keypair | `BEGIN PRIVATE KEY` block | regenerate; invalidates all existing sessions — do it at a cutover window |
| PostgreSQL password | `Password=Ba0wKVNnLeCVe` | rotate at the DB, then update config |
| PostgreSQL password | `Password=sKeIGZ2ejuGr` | as above |
| `PaymentGateway:CredentialEncryptionKey` | line 41 | **see A-2 — this one is not a simple rotation** |
| `SendGrid:WebhookVerificationKey` | line 44 | rotate via the SendGrid console; see A-3 |

Then: move all of them to environment variables / user-secrets, keep the *keys* in
`appsettings.json` with empty placeholders so the shape stays self-documenting, `git rm --cached`
the file, add it to `.gitignore`, and commit an `appsettings.Example.json`.

Finally, verify the app **fails loudly at startup** when a required secret is absent. A null
connection string that surfaces as a 500 an hour into a demo is worse than a startup crash.

### A-2. `PaymentGateway:CredentialEncryptionKey` needs a re-encryption plan, not a rotation
This key decrypts every row in `CompanyPaymentGateways`. Rotating it in isolation makes every
tenant's stored gateway credentials undecryptable — payments stop for everyone, and the failure
appears at transaction time rather than at deploy time.

The cutover procedure is:
1. Count the affected rows before touching anything.
2. Decrypt with the old key and re-encrypt with the new one in a single migration pass.
3. Only then remove the old key.

Treat this as a scheduled maintenance task with a rollback, not a config edit.

### A-3. `SendGrid:WebhookVerificationKey` is load-bearing as of 2026-08-09
S2 re-enabled signature validation on the `sendgrid/events-raw` endpoint. Per
`Base.Support/Email/Webhooks/SendGridWebhookValidator.cs`:

- **Missing key + validation enabled** → `ValidateSignature` returns `false` for every request.
  Every webhook is rejected. This is a loud, diagnosable outage.
- **`SendGrid:WebhookValidationEnabled = false`** → returns `true` unconditionally, for every
  unsigned request. This is the silent failure mode, and it is the one to guard against.

So: the key must survive the move to environment variables, and the flag must be `true` in every
non-local environment. Do not set it to `false` to make a deployment problem go away.

### A-4. `"AllowedHosts": "*"`
`appsettings.json:51`. Narrow it to the release hostnames alongside the CORS allowlist.

---

## B. Frontend authentication

### B-1. `authorize()` must verify server-side — `#283`
`src/infrastructure/lib/configs/auth.ts:62-80`. `authorize()` mints a NextAuth session from a JSON
blob the client supplied, with no server call in between.

**Calibrated severity: High, defence-in-depth — not a full compromise.** The forged `accessToken`
is still signature-validated by the API, so a fabricated session renders an authenticated-looking
shell that 401s on every call. It does not hand over data. It is, however, a convincing phishing
surface and it is wrong.

The fix: `authorize()` performs the login call itself against the backend and returns a user only
on a verified response; the client passes credentials, never a pre-built session object. Keep the
return shape identical so the JWT/session callbacks downstream are unchanged.

---

## C. Authorization

### C-1. The CQRS pipeline is default-open — `#68`
`Base.Application/Security/AuthorizationBehavior.cs:30-33`:

```csharp
// If the attribute is not found, skip authorization
if (authorizeAttribute == null)
{
    return await next();
}
```

Any command or query whose request type lacks `[CustomAuthorize]` executes for **any authenticated
caller**. This is not a single bug — the exposure equals the number of handlers that forgot the
attribute, **and that number is currently unknown.**

Deliberately deferred past the UAT release: flipping a default-open gate to default-closed the
night before a release converts an unknown security hole into a known outage. It needs measurement
first, which needs time.

The sequence, when it is picked up (full brief in [`prompts/mvp1/S5-authorization-sweep.md`](prompts/mvp1/S5-authorization-sweep.md)):
1. **Measure.** Enumerate every `ICommand<>` / `IQuery<>` request type; split attributed vs not;
   report both counts and the full unattributed list before changing anything.
2. **Classify.** Some unattributed handlers are anonymous *by design* — public-page queries rely
   on the absence of the attribute, since `[AllowAnonymous]` is MVC-only and does nothing on a
   HotChocolate resolver. Do not "fix" those.
3. **Fix the forgotten ones**, money and user/role and tenant-config handlers first.
4. **Then** invert the default to fail-closed, with an explicit marker on the genuinely-public
   handlers.

**Tooling trap:** `PSS_2.0_Backend` and `PSS_2.0_Frontend` are nested git repos and recursive
`grep`/`rg` silently misses files inside them. An empty result is not evidence of absence —
enumerate with PowerShell `Select-String` over an absolute path and cross-check the count against
the number of handler files.

### C-2. Tenant isolation fails open when tenant resolution fails
`ApplicationDbContext.ApplyTenantFilters()` does apply a real global `CompanyId` filter to every
entity that has a `CompanyId` property — the older audit claiming no global filter exists is
**stale**. The live caveat is narrower: `CurrentTenantId == null` disables filtering entirely,
by design, so SuperAdmin can see all companies.

The work is to establish whether that null state is reachable by a normal user through any path
where host/tenant resolution silently fails. If it is, that path is a cross-tenant read.

### C-3. Verify and fix
- **`#66`** — `GetUserRefreshTokens` authorization reportedly commented out.
- **`#2`** — client-supplied `RoleId` / `CompanyId` accepted on some commands. These must come
  from the token, never from the wire.
- **`#11` / `#29`** — `CompanyId = 0` code paths.

---

## D. Features withdrawn from MVP-1 — restore or finish

Hidden for the UAT release via the `ISMENURENDER` role grant (menus left `IsActive = true`).
Each reports success while doing nothing, which is worse than being absent.

| Feature | What is actually missing |
|---|---|
| Refunds (`#41`, `#53`) | never calls the gateway; born "complete"; mutates the ledger with no money moving |
| Recurring-donation manual **Retry** (`#39`) | fabricates a SUCCESS and increments counts, contacts no processor. *The recurring donation feature itself ships and stays visible — only this button was withdrawn.* |
| Scheduled Reports (`#10`) | no execution engine; runs stick on RUNNING forever |
| Custom Report Builder (`#61`) | preview / run / export all fabricated |
| Member Portal (`#86`) | "authentication" is a `localStorage` check |

MVP-2 flips the seed rows back — nothing was deleted.

---

## E. Also outstanding

- **Dynamic subdomain** — excluded from MVP-1 by explicit decision.
- **Phase 7** — Feature Dependency Registry, the three trigger layers, readiness widgets. Only the
  D-2 publish-gate defect shipped in this release.
- **Three-way predicate drift on `CompanyPaymentGateways`** — `GoLiveChecklistBuilder.cs:131`
  (`IsActive != false`), `PaymentGatewayMissingCondition.cs:33` (`IsActive == true`),
  `ValidateOnlineDonationPageForPublish.cs:213` (`IsActive != true`). Three files, three answers to
  "is this gateway usable". D-2 and D-1 are legitimately different questions — page-scoped publish
  vs tenant-scoped registry — but `!= false` and `== true` disagree on NULL, and NULL means
  *never configured*. Converge them behind one predicate.
- **Webhook replay dedup (B5)** — investigated and fully specified by S2; **awaiting one EF migration
  from the user**, which only they create. Brief:
  [`prompts/mvp1/S2-B5-webhook-dedup-migration-handoff.md`](prompts/mvp1/S2-B5-webhook-dedup-migration-handoff.md).
  `fund.PaymentWebhookLogs.GatewayEventId` has **no index at all**; dedup is check-then-act in three
  gateway controllers, so two concurrent replays of the same provider event both credit the donation.
  The fix is a filtered unique index on `(CompanyId, PaymentGatewayId, GatewayEventId)` — and the
  `23505` catch **must** land in the same change, returning 200, or the losing side of a race 500s and
  the provider retries forever. Run the duplicate-detection query in that brief against any database
  holding real donations **before** creating the index: rows returned are already-double-credited
  donations, and they are evidence the defect has fired.
- **Runtime acceptance suites** — Phase 4 §③ Part A (27 acceptance points), Phase 5 §⑤ A1–A10,
  Phase 6 §⑤ A1–A10. All unexercised. A stated, accepted gap for MVP-1; not a deferral that should
  survive to production.

---

## Ordering when this is picked up

1. **A-1 + A-4** — nothing else about exposure means anything while the credentials are public.
2. **A-2** — separately scheduled, with a rollback.
3. **C-1 step 1 (measure only)** — the count decides how big the rest of C actually is.
4. **C-2, C-3, B-1.**
5. **C-1 steps 2-4** — the fail-closed flip, once the list is known and short.
6. **D** — finish or formally drop.
7. **E** — as scoped.
