# PSS 2.0 — P-05b / T-B7 — Lead lifecycle enforcement (server-governed status)

**Type:** Follow-up patch to P-05 (S-01 Lead / Deal). **Not** a new screen.
**Schema change:** NONE. **Migration:** NONE. **New capability:** NONE. **New mutation:** NONE.
**Backend area:** `Base.Application/Business/OpsBusiness/LeadManagement/`
**Frontend area:** `presentation/components/page-components/ops/leads/`

---

## ① Why this prompt exists

`Lead.Status` (`NEW | QUALIFIED | WON | LOST`) is currently only guarded as a **vocabulary**
— both `CreateLead` and `UpdateLead` accept any value in `LeadHelper.AllowedStatuses`, in any
order. That means the lifecycle is effectively a **manual dropdown**: an update can jump
`NEW → WON`, skip `QUALIFIED`, or go backwards. The FE `lead-form-dialog.tsx` reinforces this
with a free `FormSelect` bound to `LEAD_STATUS_OPTIONS`.

The intended lifecycle is an **ordered, server-enforced** progression, and `WON` must be
**earned by an approved deal**, never hand-picked:

```
NEW ──▶ QUALIFIED ──▶ WON        (WON only via CommercialTerm approval)
  │          │
  └────┬─────┘
       ▼
     LOST  ──▶ (reopen) NEW
```

`WON` is a **derived** state: it is set as a side-effect of `ApproveCommercialTerm` succeeding,
and is otherwise **unreachable** from the client. Provisioning remains the only thing that
touches a `WON` lead (it stamps `ConvertedCompanyId`, which already freezes the record).

---

## ② Scope — do exactly this, nothing more

**In scope:** a transition guard on manual status changes; blocking `WON` as a manual target;
auto-advancing the parent lead to `WON` when its deal is approved; a create-time `WON` block;
and replacing the FE free status dropdown with lifecycle action buttons.

**Out of scope (do NOT build):** any schema/column/migration change; a new mutation or endpoint;
a new capability; touching the provisioning engine; touching `ConvertedCompanyId` handling
(already correct); the `Source` field; CommercialTerm approval logic beyond the single auto-WON
hook described in ③.3.

---

## ③ Backend changes (4 edits, all in `LeadManagement/`)

Verified names to use (already read from source — do not rename):
`LeadHelper.STATUS_NEW / STATUS_QUALIFIED / STATUS_WON / STATUS_LOST`;
`dbContext.Leads`; `dbContext.CommercialTerms`; `CommercialTerm.LeadId` (int) with nav
`CommercialTerm.Lead`; `Lead.ConvertedCompanyId` (int?); audit field `ModifiedDate`.

### ③.1 `LeadHelper.cs` — add the transition table + a guard method

Add, next to the `Status` constants:

```csharp
// ── Lead.Status lifecycle ────────────────────────────────────────────────────────────────
// WON is intentionally absent as a manual target: it is reachable ONLY via ApproveCommercialTerm.
// Same-state (from == to) is always allowed so an ordinary edit that doesn't touch status passes.
private static readonly Dictionary<string, string[]> _allowedStatusTransitions = new()
{
    [STATUS_NEW]       = [STATUS_QUALIFIED, STATUS_LOST],
    [STATUS_QUALIFIED] = [STATUS_LOST],                 // → WON is NOT here (deal-derived only)
    [STATUS_WON]       = [],                             // terminal to the client; provisioning acts
    [STATUS_LOST]      = [STATUS_NEW],                   // reopen for re-engagement
};

/// <summary>True if a CLIENT-initiated status change from → to is permitted. Same-state is a
/// no-op and always allowed. WON is never a legal manual target.</summary>
public static bool IsAllowedManualStatusTransition(string from, string to)
{
    if (string.Equals(from, to, StringComparison.Ordinal)) return true;
    if (string.Equals(to, STATUS_WON, StringComparison.Ordinal)) return false;
    return _allowedStatusTransitions.TryGetValue(from ?? "", out var next)
           && next.Contains(to, StringComparer.Ordinal);
}
```

### ③.2 `UpdateLead.cs` — enforce the transition in the non-converted branch

In `UpdateLeadHandler.Handle`, the `else` (not-converted) branch currently does a blind
`dto.Adapt(entity)`. Before adapting, guard the transition:

```csharp
else
{
    if (!LeadHelper.IsAllowedManualStatusTransition(entity.Status, dto.Status))
        throw new BadRequestException(
            $"Illegal lead status change {entity.Status} → {dto.Status}. " +
            $"WON is set only by approving a commercial term.");

    var convertedCompanyId = entity.ConvertedCompanyId;
    dto.Adapt(entity);
    entity.ConvertedCompanyId = convertedCompanyId;   // never client-settable
    if (entity.Status != LeadHelper.STATUS_LOST) entity.LostReason = null;
}
```

(The existing converted-branch freeze and the `LostReason`-required validator stay as-is.)

### ③.3 `ApproveCommercialTerm.cs` — auto-advance the parent lead to WON on approval

In `ApproveCommercialTermHandler.Handle`, **after** the term is set to `APPROVED` and **before**
`SaveChangesAsync` (so it commits in the same transaction), when `command.approve == true`:

```csharp
if (command.approve)
{
    var lead = await dbContext.Leads
        .IgnoreQueryFilters()
        .FirstOrDefaultAsync(l => l.LeadId == entity.LeadId && l.IsDeleted != true, cancellationToken);

    // Only advance a live, not-yet-converted lead that is still in the funnel.
    if (lead is not null
        && lead.ConvertedCompanyId is null
        && (lead.Status == LeadHelper.STATUS_NEW || lead.Status == LeadHelper.STATUS_QUALIFIED))
    {
        lead.Status = LeadHelper.STATUS_WON;
        lead.ModifiedDate = DateTime.UtcNow;
        lead.ModifiedBy = command.actingUserId;
    }
}
```

Also add a **pre-condition guard** at the top of the handler (right after the
`ApprovalStatus != PENDING` check) so a deal on a dead lead can't be approved:

```csharp
if (command.approve)
{
    var leadStatus = await dbContext.Leads
        .IgnoreQueryFilters().AsNoTracking()
        .Where(l => l.LeadId == entity.LeadId && l.IsDeleted != true)
        .Select(l => l.Status)
        .FirstOrDefaultAsync(cancellationToken);
    if (leadStatus == LeadHelper.STATUS_LOST)
        throw new BadRequestException("Cannot approve a deal for a lead that has been marked LOST.");
}
```

(Merge the two `if (command.approve)` blocks if you prefer a single lead fetch — one tracked
read is enough; the guard can read `lead.Status` from the same entity.)

### ③.4 `CreateLead.cs` — block `WON` at creation

A lead may still be logged after-the-fact as `LOST` (keep that), but never born `WON`. In
`CreateLeadValidator`, tighten the status rule:

```csharp
RuleFor(x => x.lead.Status)
    .Must(s => string.IsNullOrWhiteSpace(s)
               || (LeadHelper.AllowedStatuses.Contains(s) && s != LeadHelper.STATUS_WON))
    .WithMessage("A new lead cannot be created as WON — WON is earned by approving a deal.");
```

(The handler's `blank → NEW` default stays.)

---

## ④ Frontend changes — replace the manual status dropdown with lifecycle actions

Files: `lead-form-dialog.tsx`, `lead-form-schemas.ts`, `lead-list-page.tsx`,
`lead-status-chip.tsx`, and the constants holding `LEAD_STATUS_OPTIONS`.
Mutations file: `infrastructure/gql-mutations/ops-mutations/LeadMutation.ts` (reuse `UPDATE_LEAD`
— **do not add a mutation**).

### ④.1 Remove status from the create/edit form
- Delete the `FormSelect` status control from `lead-form-dialog.tsx`. Create always sends no
  status (server defaults `NEW`); the edit dialog no longer edits status at all.
- Remove `status` from the editable Zod object in `lead-form-schemas.ts` (keep the `lostReason`
  field only where the Mark-Lost action needs it — see ④.2). Keep default `status: "NEW"` out of
  the submit payload for create if the BE defaults it; if the DTO requires the field, send `"NEW"`.

### ④.2 Add lifecycle action buttons (on the list row actions and/or a detail header)
Drive each from the row's current `status` (all fields for the round-trip are already on
`LeadResponseDto`). Each button resends the **full current lead** via `UPDATE_LEAD` with only the
target status changed:

| Button | Shown when status is | Sends status | Extra |
|--------|----------------------|--------------|-------|
| **Qualify** | `NEW` | `QUALIFIED` | — |
| **Mark Lost** | `NEW` or `QUALIFIED` | `LOST` | opens a small reason dialog → `lostReason` (required) |
| **Reopen** | `LOST` | `NEW` | clears `lostReason` |
| *(none)* | `WON` | — | read-only; show a chip + tooltip "Won on deal approval" |

- `WON` and converted leads expose **no** status button.
- Surface the BE `BadRequestException` message on failure (the guard is the source of truth; the
  FE just requests the transition).

### ④.3 `LEAD_STATUS_OPTIONS` and the chip
- Remove `WON` from any **selectable** option list. Keep all four in `lead-status-chip.tsx` so
  every state still renders a chip (WON is display-only now).

---

## ⑤ Hard constraints (repeat of the standing rules that bite here)

1. **No schema / migration / capability / mutation added.** Reuse `UPDATE_LEAD` and
   `ApproveCommercialTerm`.
2. **Control-plane reads:** every `Leads` / `CommercialTerms` read uses `.IgnoreQueryFilters()`
   **and** an explicit `IsDeleted != true` (platform callers have `CurrentTenantId == null`).
3. **UTC only:** `DateTime.UtcNow` for `ModifiedDate`; never `DateTime.Now` / `DateTime.Today`.
4. **Verify before use:** the property names in ③ were read from source — do not invent others.
5. **Auto-WON commits in the same `SaveChangesAsync`** as the term approval — one transaction, so
   a failed save leaves neither the term APPROVED nor the lead WON.
6. **Idempotent auto-WON:** only advances a not-converted lead in `NEW`/`QUALIFIED`; a re-approval
   or an already-WON/converted lead is a no-op (never throws on the WON path).

---

## ⑥ Build evidence to return in the hand-back

- **BE:** `dotnet build …/Base.API.csproj -c Debug` → **0 CS errors** (stop any running `Base.API`
  first to avoid the DLL file-copy lock; a redirected-output build is acceptable evidence if the
  in-place copy step is blocked — say which you used).
- **FE:** `npx tsc --noEmit --incremental false` → **exit 0** (only exit 0 counts as clean).
- In the hand-back, confirm: the four BE edits; that `WON` is unreachable via `UpdateLead`
  (list the exact rejected transitions); that create rejects `WON`; that the FE status dropdown
  is gone and replaced by the action buttons; and any decision you had to make (e.g. where the
  action buttons live — list row vs a detail header).
```
