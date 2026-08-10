# Phase 6 §9.4 — Intimation dedup index: migration hand-off

**From:** S6 (residual screen defects). **Investigated and decided — nothing applied.**
**Action needed from you:** one EF migration. Agents do not create migrations.

## Decision

**Yes — widen the filter.** `"Status" = 'ACTIVE'` → `"Status" = 'ACTIVE' AND "IsDeleted" = false`.

The failure it prevents is silent and permanent. `IntimationService.RaiseAsync` looks a condition up with

```csharp
i.CompanyId == request.CompanyId
&& i.IntimationTypeCode == request.IntimationTypeCode
&& i.SourceKey == request.SourceKey
&& i.Status == IntimationStatuses.Active
&& i.IsDeleted != true
```

([IntimationService.cs:34-42](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Services/Intimations/IntimationService.cs#L34-L42))

A row that is soft-deleted while still `Status = 'ACTIVE'` is invisible to that lookup, so the service
takes the insert path — but the row is still sitting in the narrow partial index, so the INSERT raises
`23505`. `RaiseAsync` catches every exception, logs a `LogWarning` and returns `false`
([:137-146](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Services/Intimations/IntimationService.cs#L137-L146)),
by design, so nothing surfaces. That condition never raises again for that tenant, for good, and the
only evidence is a warning line in the log.

**Reachability today: latent, not live.** Nothing in the codebase sets `IsDeleted = true` on an
`Intimation` — `ExpireIntimation` sets `Status = 'EXPIRED'` and `ExpiresAt`, and leaves `IsDeleted`
alone. So this cannot fire on the current code. It becomes live the first time anyone adds a
soft-delete path (an ops "remove this banner" action is the obvious candidate), and at that point the
damage is invisible. The index ships in the initial migration either way, so widening it now costs one
migration and closes the hole before it opens.

## The code already says widened — the database does not

This is a **model↔migration divergence** and is the real reason a migration is owed:

| Where | Filter |
|---|---|
| `IntimationConfiguration.cs` (`HasFilter`) | `"Status" = 'ACTIVE' AND "IsDeleted" = false` ✅ |
| `20260809132101_Add_Intimation.cs:154` | `"Status" = 'ACTIVE'` ❌ |
| `20260809132101_Add_Intimation.Designer.cs:21017` | `"Status" = 'ACTIVE'` ❌ |
| `ApplicationDbContextModelSnapshot.cs:21014` | `"Status" = 'ACTIVE'` ❌ |

So the database gets the narrow index, and there is a **pending model diff** — the next
`dotnet ef migrations add` for any unrelated change will scoop this index rebuild up with it. Better to
land it deliberately.

## Migration intent

`dotnet ef migrations add Widen_Intimation_Dedup_Index_Filter`

EF will generate the drop/recreate itself from the config. If you would rather write it by hand, the
equivalent is:

```csharp
migrationBuilder.DropIndex(
    name: "UX_Intimations_Company_Type_SourceKey_Active",
    schema: "notify",
    table: "Intimations");

migrationBuilder.CreateIndex(
    name: "UX_Intimations_Company_Type_SourceKey_Active",
    schema: "notify",
    table: "Intimations",
    columns: new[] { "CompanyId", "IntimationTypeCode", "SourceKey" },
    unique: true,
    filter: "\"Status\" = 'ACTIVE' AND \"IsDeleted\" = false");
```

`Down` is the same pair with `filter: "\"Status\" = 'ACTIVE'"`.

**No duplicate pre-check is needed.** Widening a partial unique index only ever *narrows* the row set
it covers, so any data that satisfies the current index satisfies the new one. This is the opposite of
the B5 hand-off, where the index was new and prod data could block it.

## Optional second index in the same migration

`UX_IntimationDismissals_Intimation_User` is unique on `(IntimationId, UserId)` with **no filter**
([IntimationDismissalConfiguration.cs](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/NotifyConfigurations/IntimationDismissalConfiguration.cs),
[migration :117-122](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Migrations/20260809132101_Add_Intimation.cs#L117-L122)).

The §9.3 escalation fix now **soft-deletes** dismissal rows when a warning escalates to CRITICAL. If the
same `(intimation, user)` pair were ever dismissed again, the soft-deleted row would still occupy the
unfiltered unique index and the insert would throw — and `DismissIntimation` catches `DbUpdateException`
and returns *success*, so the banner would stay on screen while the UI reported it dismissed.

**Unreachable today**, because escalation also sets `IsDismissible = false` permanently, and
`DismissIntimation` rejects non-dismissible rows server-side — so the pair can never be re-dismissed.
It is listed here because it is the exact same shape of bug as §9.4, one line of config away, and
cheapest to fix while the other index is already being rebuilt:

```csharp
// IntimationDismissalConfiguration.cs
builder.HasIndex(d => new { d.IntimationId, d.UserId })
    .IsUnique()
    .HasFilter("\"IsDeleted\" = false")            // <-- add
    .HasDatabaseName("UX_IntimationDismissals_Intimation_User");
```

Your call. Not a blocker; the §9.4 change is.

## Confirmation of §9.3 (no migration, no action)

For the record, since the pending-development list carried it as *"handed to build session,
unconfirmed"*: the §9.3 escalation fix **is implemented and already committed** (present in `6b6ee0f8`).
`IntimationService.cs:67-91` sets `IsDismissible = false` on escalation and clears the dismissal rows
via `ExecuteUpdateAsync`, and the insert path forces CRITICAL rows non-dismissible at
`:117-119`. The guard `request.SeverityCode == Critical && existing.IsDismissible` uses `IsDismissible`
as the "not already CRITICAL" test, which is safe: a row that was never dismissible can never have
dismissal rows to clear, because `DismissIntimation` refuses them.

## Not run by this session

`dotnet ef migrations add` was not run, `dotnet build` was not run, and
`ApplicationDbContextModelSnapshot.cs` was not hand-edited.
