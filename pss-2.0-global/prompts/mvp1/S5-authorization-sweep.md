# S5 — Authorization Sweep (Backend)

**Wave 2 · start when S2 reports done · ~1.5 h**
**Repo:** `PSS_2.0_Backend` (nested git repo — stage from inside it)

## Why this is Wave 2
This session adds attributes across many handler files. S2 is editing handlers in the donation area at the same time. Waiting avoids a merge fight over the same files for no gain.

## Standing rules for this session
- **Never `git commit`.** Stage only (`git add`) and report. No push, amend, or tag.
- No `Co-Authored-By: Claude` / "Generated with Claude Code" lines in any commit message you draft.
- **You do not run `dotnet build`.** Make compiling changes and hand off.
- **You do not create EF migrations.**
- **Do not seed or alter `auth.Modules`, menus, or capabilities.** If a handler needs a capability that is not seeded, **report it** — do not invent one. Granting an unseeded capability silently 403s every user and looks like a broken screen.
- Do not touch configuration (S1) or `PSS_2.0_Frontend` (S3).

## Why this session exists — the finding
`Base.Application/Security/AuthorizationBehavior.cs:30-33`:

```csharp
// If the attribute is not found, skip authorization
if (authorizeAttribute == null)
{
    return await next();
}
```

**The CQRS pipeline is default-open.** Any command or query whose request type lacks `[CustomAuthorize]` executes for *any authenticated caller*. This is not one bug — the exposure equals the number of handlers that forgot the attribute, and that number is currently unknown.

## Scope

### 1. Measure before fixing *(do this first, report before proceeding)*
Enumerate every `ICommand<>` / `IQuery<>` request type and split into: **has `[CustomAuthorize]`** vs **does not**. Report both counts and the full unattributed list.

**Beware the tooling trap:** `PSS_2.0_Backend` and `PSS_2.0_Frontend` are nested git repos and recursive `grep`/`rg` silently misses files inside them. An empty result is *not* evidence of no matches. Enumerate with PowerShell `Select-String` over an explicit absolute path and cross-check the count against the number of handler files.

Some unattributed handlers are legitimate — anonymous public-page queries are anonymous **by design**, via absence of the attribute (`[AllowAnonymous]` is MVC-only and does nothing on a HotChocolate resolver). Do not "fix" those. Classify each as *deliberately anonymous* or *forgotten*.

### 2. Fix the forgotten ones, highest blast radius first
Priority order: anything touching **money**, **users/roles**, **tenant configuration**, then the rest. If the list is long, MVP-1 needs the first three tiers — say plainly what you did not reach rather than quietly stopping.

### 3. Consider failing closed
Evaluate inverting the default: **deny** when the attribute is absent, with an explicit `[AllowAnonymousCommand]` marker on the genuinely-public handlers. This is the correct long-term design.

**Give a recommendation, do not implement it tonight unless the unattributed list is short.** Flipping a default-open gate to default-closed the night before a release converts an unknown security hole into a known outage. Write it up as the immediate post-MVP-1 change.

### 4. Related items — verify then fix
- **#66** — `GetUserRefreshTokens` authorization reportedly commented out. Verify against current source, fix if true.
- **#2** — client-supplied `RoleId`/`CompanyId` accepted on some commands → privilege escalation. Verify; these should come from the token, never the wire.
- **#11 / #29** — `CompanyId = 0` code paths.

**Tenant isolation context (already better than the old audit says):** a real global query filter exists — `ApplicationDbContext.ApplyTenantFilters()` applies `CompanyId` filtering to every entity with a `CompanyId` property. The caveat worth checking is that `CurrentTenantId == null` disables the filter entirely (by design, for SuperAdmin), so **it fails open** wherever tenant resolution silently fails. Report any path where that is reachable by a normal user.

## Acceptance
- [ ] Counts reported: attributed vs unattributed handlers
- [ ] Every unattributed handler classified deliberately-anonymous or forgotten
- [ ] Money, user/role and tenant-config handlers all carry `[CustomAuthorize]`
- [ ] Capabilities referenced are ones that actually exist in the seed — unseeded ones reported, not invented
- [ ] Fail-closed written up as a recommendation with a risk note

## Report back
The unattributed list, what you fixed, what you deliberately left anonymous, and what you ran out of time for.
