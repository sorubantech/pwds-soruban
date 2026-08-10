# B5 — Gateway webhook replay dedup: migration hand-off

**From:** S2 (money-path correctness). **Investigated only — nothing applied.**
**Action needed from you:** one EF migration + one small code change (below). Agents do not create migrations.

## Finding

The column exists. `fund.PaymentWebhookLogs.GatewayEventId` is present on
[PaymentWebhookLog.cs:10](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/PaymentWebhookLog.cs#L10),
mapped `HasMaxLength(200)`, nullable, in
[PaymentWebhookLogConfiguration.cs:13](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/DonationConfigurations/PaymentWebhookLogConfiguration.cs#L13).
**There is no index on it at all** — unique or otherwise.

Dedup today is check-then-act in application code, in all three tenant gateway controllers:

- [PaymentWebhookController.cs:118-132](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/Controller/PaymentWebhookController.cs#L118-L132) (Braintree)
- [RazorpayWebhookController.cs:163-180](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/Controller/RazorpayWebhookController.cs#L163-L180)
- [PayUWebhookController.cs:172](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/Controller/PayUWebhookController.cs#L172)

Each runs `AnyAsync(...)` and then, if nothing came back, processes. Two copies of the same
provider event arriving concurrently both read "no duplicate" and both credit the donation. The
window is small and entirely real — providers retry in bursts precisely when we are slow, which is
also when two requests are most likely to be in flight together.

The platform-side twin already has the index this table is missing —
[PlatformWebhookLog.cs:33-35](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/OpsModels/PlatformWebhookLog.cs#L33-L35)
documents `UNIQUE (PlatformPaymentGatewayId, GatewayEventId) WHERE GatewayEventId IS NOT NULL AND IsDeleted = false`.
This hand-off is the tenant-side equivalent.

## Migration intent

Filtered unique index, PostgreSQL — so `migrationBuilder.Sql()`, not `CreateIndex` (EF cannot express
the `IS NOT NULL` predicate portably):

```csharp
migrationBuilder.Sql(@"
    CREATE UNIQUE INDEX IF NOT EXISTS ""IX_PaymentWebhookLogs_Company_Gateway_EventId_Unique""
    ON fund.""PaymentWebhookLogs"" (""CompanyId"", ""PaymentGatewayId"", ""GatewayEventId"")
    WHERE ""GatewayEventId"" IS NOT NULL AND ""IsDeleted"" = false;");
```

Down: `DROP INDEX IF EXISTS fund."IX_PaymentWebhookLogs_Company_Gateway_EventId_Unique";`

### Why that column list

- **`CompanyId` is required.** `PaymentGatewayId` points at the gateway *master* (Braintree, Razorpay,
  PayU), not the per-tenant `CompanyPaymentGateway` row, so two tenants on the same provider can
  legitimately hold the same provider event id space. Without `CompanyId` one tenant's event could
  block another's. Note this makes the index **stricter than the current app-level check**, which
  filters on `GatewayEventId` alone — see the follow-up below.
- **`WHERE GatewayEventId IS NOT NULL`** — the column is nullable and providers that send no event id
  leave it null; a plain unique index would collapse every such row into one.
- **`WHERE IsDeleted = false`** — matches the app predicate and keeps soft-deleted history from
  blocking a genuine re-receipt.
- **Signature-invalid rows need no exclusion.** All three controllers return *before* assigning
  `GatewayEventId` when the signature fails, so those rows carry null and the `IS NOT NULL` predicate
  already skips them. Worth preserving if that ordering is ever refactored.

## Two things that must land WITH the migration, not after

**1. Pre-existing duplicates will block index creation.** If prod already holds replayed rows, the
`CREATE UNIQUE INDEX` fails. Check first:

```sql
SELECT "CompanyId", "PaymentGatewayId", "GatewayEventId", count(*)
FROM fund."PaymentWebhookLogs"
WHERE "GatewayEventId" IS NOT NULL AND "IsDeleted" = false
GROUP BY 1,2,3 HAVING count(*) > 1;
```

Any rows returned are *already-double-credited donations* and want reading before they are soft-
deleted — they are the evidence that this defect fired.

**2. The unique violation has to be caught, or the fix becomes an outage.** The dedup path does not
insert on the duplicate branch — the log row is inserted early and then *updated* with
`GatewayEventId`. Once the index exists, the losing side of a concurrent replay throws
`DbUpdateException` out of `SaveChangesAsync`, the controller's catch returns 500, and the provider
retries the same event forever. Each of the three controllers needs the violation treated as what it
is — a duplicate:

```csharp
catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: "23505" })
{
    // The index caught what the check-then-act above raced past. Same outcome as the in-app
    // duplicate branch: mark ignored, return 200, do NOT re-credit.
}
```

That branch must return **200** — a non-2xx tells the gateway to send it again.

## Follow-up (not required for the index to be correct)

The app-level check filters on `GatewayEventId` alone while the index scopes by tenant. Aligning the
`AnyAsync` predicate to `CompanyId + PaymentGatewayId + GatewayEventId` in all three controllers would
make the fast path and the backstop agree; today the app check is the stricter of the two and would
mis-flag a cross-tenant id collision as a duplicate. Left out of S2 because it changes behaviour on a
money path and belongs with the migration, under test.
