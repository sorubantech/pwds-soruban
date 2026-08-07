# PSS 2.0 — P-05d / T-B9 — Auto-approval master ON/OFF switch

**Type:** Follow-up patch to P-05 (S-02 Commercial Terms). **Not** a new screen.
**Schema change:** NONE. **Migration:** NONE. **New capability:** NONE. **New mutation/query:** NONE.
**Seed:** ONE row — `sql-scripts-dyanmic/ops-deal-autoapprove-toggle-seed.sql` (already written; user applies).
**Backend area:** `Base.Application/Business/OpsBusiness/LeadManagement/` — 2 tiny edits.
**Frontend area:** none.

---

## ① Why this prompt exists

Today auto-approval on `SubmitCommercialTerm` is governed by **one** control — the *threshold
percent* `PLATFORM_DISCOUNT_APPROVAL_THRESHOLD_PCT` (default 15). A deal auto-approves when
`DiscountPercent <= threshold`. There is **no way to switch auto-approval off entirely** — even
setting the threshold to `0` still auto-approves a 0%-discount deal.

Add a **master switch** so the platform operator can force *every* deal through manual approval:

- **`PLATFORM_DEAL_AUTO_APPROVE_ENABLED`** — BOOLEAN, platform-global, default **`true`**.
- **ON**  → today's behaviour (auto-approve when discount ≤ threshold, else `PENDING_APPROVAL`).
- **OFF** → auto-approval disabled: **every** submitted deal → `PENDING_APPROVAL`, regardless of
  discount (even 0%), requiring a `PLATFORM_DEAL_APPROVE` decision.

The switch is a raw platform setting (DB-edited today, like the threshold — there is no
platform-settings admin UI yet). The seed sets the default; flipping it is a one-line `UPDATE`
documented in the seed header.

---

## ② Scope — do exactly this, nothing more

**In scope:** one reader method on `LeadHelper`; one-line gate on the existing `autoApproved`
computation in `SubmitCommercialTerm`; apply the already-written seed row.

**Out of scope (do NOT build):** any schema/column/migration; a FE control or settings screen for
the toggle; a new capability/mutation/query; touching the threshold logic itself; changing the
`DRAFT`-only guard, the approval DTO, or the provisioning path.

---

## ③ Backend changes (2 edits, both in `LeadManagement/`)

Verified names to use (read from source — do not rename):
`LeadHelper.GetPlatformSettingAsync(dbContext, paramCode, ct)` (existing reusable reader — returns
`CurrentValue ?? ParamDefaultValue`, or `null` when absent/blank);
`LeadHelper.GetDiscountApprovalThresholdAsync`; `LeadHelper.APPROVAL_APPROVED` /
`LeadHelper.APPROVAL_PENDING`; the submit handler's existing local
`var autoApproved = entity.DiscountPercent <= threshold;`.

### ③.1 `LeadHelper.cs` — add the toggle constant + reader

Next to `DISCOUNT_THRESHOLD_PARAM_CODE` / `DefaultDiscountThresholdPct`, add:

```csharp
public const string AUTO_APPROVE_ENABLED_PARAM_CODE = "PLATFORM_DEAL_AUTO_APPROVE_ENABLED";
public const bool   DefaultAutoApproveEnabled       = true;

/// <summary>Master switch for commercial-term auto-approval. Returns the platform-global
/// PLATFORM_DEAL_AUTO_APPROVE_ENABLED setting; defaults to TRUE (auto-approval on) when the
/// setting is absent, blank, or unparseable — the safe status-quo default.</summary>
public static async Task<bool> GetAutoApproveEnabledAsync(
    ApplicationDbContext dbContext, CancellationToken ct)
{
    var raw = await GetPlatformSettingAsync(dbContext, AUTO_APPROVE_ENABLED_PARAM_CODE, ct);
    if (string.IsNullOrWhiteSpace(raw)) return DefaultAutoApproveEnabled;
    return bool.TryParse(raw.Trim(), out var enabled) ? enabled : DefaultAutoApproveEnabled;
}
```

*(Match the exact `ApplicationDbContext` type name used by the sibling `GetDiscountApprovalThresholdAsync`
signature — reuse whatever that method already declares; do not introduce a new context type.)*

### ③.2 `SubmitCommercialTerm.cs` — gate the auto-approve computation

The handler currently computes:

```csharp
var threshold = await LeadHelper.GetDiscountApprovalThresholdAsync(dbContext, cancellationToken);
var autoApproved = entity.DiscountPercent <= threshold;
```

Read the switch and AND it in:

```csharp
var threshold = await LeadHelper.GetDiscountApprovalThresholdAsync(dbContext, cancellationToken);
var autoApproveEnabled = await LeadHelper.GetAutoApproveEnabledAsync(dbContext, cancellationToken);
var autoApproved = autoApproveEnabled && entity.DiscountPercent <= threshold;
```

Everything after this line stays **unchanged** — the existing
`if (autoApproved) { … APPROVED … } else { … PENDING … }` block already does the right thing; when
the switch is OFF, `autoApproved` is `false`, so every deal falls into the `PENDING_APPROVAL` branch.

**`SubmitCommercialTermResultDto`:** its `AutoApproved` / `ThresholdPercent` fields stay as-is. The
FE toast ("Approved automatically" vs "Sent for approval") already keys off `AutoApproved`, so with
the switch OFF it will correctly say the deal was sent for approval — no FE change needed.

---

## ④ Seed (already written — apply, don't regenerate)

`sql-scripts-dyanmic/ops-deal-autoapprove-toggle-seed.sql` inserts the one platform-global row
(default `'true'`), idempotent `WHERE NOT EXISTS`. Apply it after `ops-lead-deal-seed.sql`. The
header documents the `UPDATE … SET "CurrentValue" = 'false'` one-liner to switch it off.

---

## ⑤ Hard constraints

1. **Backend only, 2 edits.** No schema/migration/capability/mutation/query/FE.
2. **Reuse `GetPlatformSettingAsync`** — do not add a second setting reader.
3. **Safe default is TRUE** — absent/blank/unparseable setting ⇒ auto-approval stays ON (today's
   behaviour), never silently disabled.
4. **UTC only** where any timestamp is touched (none new here).
5. **Control-plane read** already handled inside `GetPlatformSettingAsync` (CompanyId IS NULL +
   IgnoreQueryFilters) — do not re-implement.
6. **Do not touch** the threshold constant/reader, the `DRAFT`-only guard, or the approve/reject path.

---

## ⑥ Build evidence to return in the hand-back

- **BE:** `dotnet build …/Base.API/Base.API.csproj -c Debug` → **0 CS errors** (stop any running
  `Base.API` first to avoid the DLL copy lock; say if you used a redirected-output build).
- Confirm: with the setting `'false'`, a submitted 0%-discount deal lands in `PENDING_APPROVAL`
  (not APPROVED); with `'true'` (or the row absent), a within-threshold deal still auto-approves.
- Flag any property/method name that differed from what ③ assumed (verify-before-use).
