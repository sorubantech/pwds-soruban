# S2 — Money-Path Correctness (Backend)

**Wave 1 · run in parallel with S1, S3, S4 · ~45 min**
**Repo:** `PSS_2.0_Backend` (nested git repo — stage from inside it)

## Standing rules for this session
- **Never `git commit`.** Stage only (`git add`) and report. No push, amend, or tag.
- No `Co-Authored-By: Claude` / "Generated with Claude Code" lines in any commit message you draft.
- **You do not run `dotnet build`.** Make compiling changes and hand off.
- **You do not create EF migrations.** Where one is needed, write the intent and hand it to the user.
- **Stay inside the file list below.** S1 owns `appsettings.json` + `DependencyInjection.cs`; S5 owns authorization attributes. Do not touch either.

## Why this session exists
Wrong money is worse than missing money. Each item here either takes a donor's payment down a dead path or credits an amount that never moved.

## Scope

### 1. B1 — the D-2 defect *(do this first; it is one line)*
File: `PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/OnlineDonationPages/Queries/ValidateOnlineDonationPageForPublish.cs:213`

The publish validator checks the gateway exists and is not deleted, but **never checks `IsActive`**. A tenant whose only gateway is switched off publishes a live donation page, and every donor who reaches it fails at payment.

```csharp
.AnyAsync(g => g.CompanyPaymentGatewayId == entity.CompanyPaymentGatewayId
            && g.CompanyId == companyId
            && g.IsActive == true          // ← add this
            && g.IsDeleted == false, ct)
```

**Context you should know but must NOT act on:** the same business fact is written three different ways across `GoLiveChecklistBuilder.cs:131` (`IsActive != false`), `PaymentGatewayMissingCondition.cs:33` (`IsActive == true`) and this file (unchecked). Unifying them is Phase 7 and is explicitly **out of scope tonight**. Fix only this one call site — it is the only one on a money path.

### 2. A3-reduced — media upload hardening
File: `PeopleServe/Services/Base/Base.API/Controller/MediaController.cs`

**The endpoint stays anonymous — this is deliberate.** Public donation and P2P fundraiser pages depend on unauthenticated upload; adding `[Authorize]` would break them.

Do exactly one thing: **remove `.svg` from `AllowedExtensions`.** An SVG is executable markup, so an anonymous SVG upload served from your own origin is stored XSS. Removing it closes that without touching the public flow. Leave `.png`, `.jpg`, `.jpeg`, `.webp` and the 5 MB cap alone.

If it is cheap, also validate the magic bytes match the claimed extension. If it is not cheap, skip it and say so.

### 3. B6 — inbound email webhook signature
The inbound email webhook does not verify its provider signature, so anyone who knows the URL can post events. Locate the handler, verify the provider's signature (HMAC over the raw body — you need the **raw** body, not the deserialized model), reject on mismatch. If the shared secret is not available in config, **stop and report** rather than inventing one — S1 owns configuration.

### 4. B5 — webhook replay dedup *(investigate, do not migrate)*
Gateway webhooks have no dedup index, so a provider replay can double-credit a donation. Confirm whether a provider-event-id column exists.
- If it does → the fix is a unique index. **Write the migration intent and hand it to the user.** Do not run `ef migrations add`.
- If it does not → report the shape needed; this likely slips past MVP-1.

## Acceptance
- [ ] Publishing a donation page whose gateway is inactive is now rejected server-side
- [ ] Publishing with an active gateway still succeeds (do not over-tighten — `IsDeleted == false` semantics unchanged)
- [ ] `.svg` no longer accepted by the upload endpoint; the endpoint is still anonymous
- [ ] Email webhook rejects an unsigned or wrongly-signed payload
- [ ] B5 written up as a migration hand-off, not applied

## Out of scope
Refund logic and the recurring-retry button (S4 hides them). Authorization attributes (S5). Configuration (S1). Phase 7 predicate unification.
