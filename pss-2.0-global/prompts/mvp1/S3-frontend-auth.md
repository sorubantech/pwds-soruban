# S3 — Frontend Authentication Hardening

**Wave 1 · run in parallel with S1, S2, S4 · ~1 h**
**Repo:** `PSS_2.0_Frontend` (nested git repo — stage from inside it)

## Standing rules for this session
- **Never `git commit`.** Stage only (`git add`) and report. No push, amend, or tag.
- No `Co-Authored-By: Claude` / "Generated with Claude Code" lines in any commit message you draft.
- **`BaseUrlConfig.ts` is user-managed.** Never edit, stage, or revert it.
- Do not change the session strategy, `maxAge`, the JWT callbacks, or the credentials provider *shape* — only what `authorize()` does internally (see below).
- Do not touch `PlatformGate` (Phase 2.1 F-3 control-plane gate) or `MenuLoader`'s commit-gated scrim logic.
- Do not probe whether the API is running. The user runs it.
- **Stay inside the file list below** — S1/S2 are editing the backend, S4 is editing menu seeds.

## Why this session exists
`authorize()` mints a NextAuth session out of a JSON blob the client supplied, with no server call in between.

## Scope

### 1. A5 — `authorize()` must verify server-side
File: `src/infrastructure/lib/configs/auth.ts:62-80`

```ts
async authorize(credentials) {
  if (!credentials?.userData) { throw new Error("No user data provided"); }
  const userData = JSON.parse(credentials.userData as string);   // ← trusted, never verified
  return { id: credentials.userName as string, /* …tokens straight from the client… */ };
}
```

**Calibrate the severity honestly.** The forged `accessToken` is still signature-validated by the API, so this does not hand over data — it renders an authenticated-looking shell that 401s on every call. It is defence-in-depth and a convincing phishing surface, not a full compromise. Fix it properly; do not let anyone describe it as either "already safe" or "total breach".

The fix: `authorize()` performs the login call itself against the backend and returns the user only on a verified response. The client passes **credentials**, never a pre-built session object. Keep the same return shape so the JWT/session callbacks downstream are unchanged.

Check what currently calls `signIn("credentials", { userData })` and update those call sites — that is where the login form hands over the already-fetched payload.

### 2. Member Portal — block the route
`#86`: Member Portal "authentication" is a localStorage check. It is being withdrawn from MVP-1.

S4 hides its menu entries. **You** make the route itself unreachable — a hidden menu is not access control, and the URL is still typeable. Block it in the auth gate: `middleware.ts` at the **repo root** (not `src/`) is the real gate; `RouteGuard` is dead code, do not use it. Note that `publicRoutes` currently omits the entire `(public)` group.

### 3. `NEXT_PUBLIC_UPGRADE_CONTACT`
Unset, so the upgrade CTA dead-ends. Either set it or hide the CTA. Report which you did.

## Acceptance
- [ ] A crafted `signIn` with a fabricated `userData` no longer produces a session
- [ ] Normal login still works end to end; session duration and refresh behaviour unchanged
- [ ] Member Portal URLs are unreachable when typed directly, not merely unlisted
- [ ] Upgrade CTA either works or is not shown

## Out of scope
Any backend file. Menu/capability seeds (S4). Session strategy, `maxAge`, JWT callbacks.
