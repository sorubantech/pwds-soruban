# Plan — Grant Fund Receipt & Payment Tracking (funder → charity money-in)

## Context

**The gap.** Grant spend-out is fully modeled (`GrantExpense`: date/amount/budget-line/vendor/ref/receipt-URL). Grant money-**in** is not. The only inbound hook today is `RecordGrantTranche.cs`, which writes a `GrantStageHistory` row carrying `AmountReceived` + `receivedDate` + free-text `notes` — and sets `ToStageId == current stage` (a tell that a *payment* is being bent into a *stage-transition* record). This captures partial/multiple receipts and a timeline, but nothing else: no payment method, no receiving bank account, no reference number, no per-payment evidence, no cheque-deposit tracking, no outstanding-receivable balance, and no auditable/voidable payment record.

**Outcome.** A first-class `GrantFundReceipt` ledger + a reusable `OrganizationBankAccount` config, surfacing one grant financial picture: **Awarded → Received → Outstanding**, alongside the existing **Spent**, plus **Cash-on-hand** (Received − Spent).

**Decisions (locked with user 2026-07-06):**
1. **Receiving account = shared org-level config** (reusable), not grant-local fields. New `OrganizationBankAccount` (`app` schema). `CompanyBank` exists but is insufficient (bank+branch only, no account number/currency/nickname) — do **not** overload it; new table references `Bank` the same way.
2. **Milestone linkage = light** — a receipt may optionally FK a `GrantMilestone`. No planned-disbursement/expected-vs-received schedule table in this build.
3. **Cheque-deposit tracking (user add-on)** — capture which account it was deposited to (`ReceivingAccountId`), **who deposited it** (`DepositedByStaffId`), and **when** (`DepositedDate`). Cheque clearing matters → a lightweight receipt status (RECEIVED/DEPOSITED/CLEARED/BOUNCED/CANCELLED); balances count only non-BOUNCED/non-CANCELLED.
4. **Evidence = URL-link only** — consistent with [[project-grant-attachment-url-vs-upload]] (no blob yet). Dormant upload path applies later.
5. **Balances computed on read** — no dual-write into `Grant.*`. Single EF query per grant.
6. **Sensitive account number** — per [[feedback-config-screens]]: write-only, masked on read (last-4), audited.

**Scope:** Entity-level build (2 new tables + MasterData seeds + migration + backfill + GraphQL + FE). Backend root `PSS_2.0_Backend\PeopleServe\Services\Base\`. This layers cleanly on top of the pending `AgreementSignedDate` migration (independent).

---

## 1. Domain entities

### 1a. `Base.Domain/Models/ApplicationModels/OrganizationBankAccount.cs` (NEW, `app` schema)
Reusable org receiving-account config.
```
OrganizationBankAccountId (PK)
CompanyId (int, tenant)
AccountName        string   // nickname e.g. "HDFC – Grants Operating"
BankId             int  FK → com.Banks (Bank)          // reuse existing Bank reference table
BranchName         string?
AccountNumber      string   // SENSITIVE: write-only, masked (last-4) on read, audited
CurrencyId         int? FK → com.Currencies
IsDefault          bool     // one default receiving account per company
IsActive           bool     // (Entity base also has audit + IsDeleted)
// nav: Company, Bank, Currency
```
- `IsDefault`: enforce at most one active default per `CompanyId` in the write handler (demote prior default on set).

### 1b. `Base.Domain/Models/GrantModels/GrantFundReceipt.cs` (NEW, `grant` schema)
The money-in ledger. One row per funder payment/tranche.
```
GrantFundReceiptId (PK)
GrantId            int  FK → grant.Grants
CompanyId          int?
ReceiptCode        string   // NumberSequence entityType "GRANTRECEIPT", auto on create
Amount             decimal
CurrencyId         int  FK → com.Currencies            // snapshot; defaults to grant currency
ReceivedDate       DateTime // when funder released funds (UTC)
PaymentMethodId    int  FK → sett.MasterDatas (TypeCode = GRANTPAYMENTMETHOD)
ReferenceNumber    string?  // cheque no / wire ref / txn id
ReceivingAccountId int? FK → app.OrganizationBankAccounts   // which of OUR accounts received it
EvidenceUrl        string?  // cheque image / bank receipt / confirmation (URL-link)
LinkedMilestoneId  int? FK → grant.GrantMilestones          // light milestone link
DepositedByStaffId int? FK → com.Staffs                     // who deposited (cheque flow)
DepositedDate      DateTime?                                 // when deposited (≠ ReceivedDate)
ReceiptStatusId    int  FK → sett.MasterDatas (TypeCode = GRANTRECEIPTSTATUS)
Notes              string?
// nav: Grant, Currency, PaymentMethod, ReceivingAccount, LinkedMilestone, DepositedByStaff, ReceiptStatus, Company
```
- Add `public virtual ICollection<GrantFundReceipt>? FundReceipts { get; set; }` to `Grant.cs`.

## 2. EF configurations (`Base.Infrastructure/Data/Configurations/`)

- **`ApplicationConfigurations/OrganizationBankAccountConfiguration.cs`** — table `app.OrganizationBankAccounts`; identity PK; `AccountName` maxlen 150 required; `AccountNumber` maxlen 64 required; `BranchName` maxlen 150; FK `Bank`/`Currency` `OnDelete Restrict`; index `(CompanyId, IsDefault)`.
- **`GrantConfigurations/GrantFundReceiptConfiguration.cs`** — table `grant.GrantFundReceipts`; identity PK; `Amount` `decimal(18,2)`; `ReceiptCode` maxlen 50; `ReferenceNumber` maxlen 100; `EvidenceUrl` maxlen 1000; `Notes` maxlen 2000; **all** FKs `OnDelete Restrict` (matches grant convention, avoids multiple-cascade-path); indexes on `GrantId`, `ReceiptStatusId`, `ReceivingAccountId`. Register both `DbSet`s on `ApplicationDbContext` (`IApplicationDbContext` interface + partial class).

## 3. MasterData seeds (`Base.Infrastructure/Data/SeedDatas` or existing MasterData seed path)

Mirror the `GRANTSTAGE` seeding pattern (grant module already owns its own MasterData types).
- **`GRANTPAYMENTMETHOD`**: `BANKTRANSFER` (Bank Transfer), `CHEQUE` (Cheque), `WIRETRANSFER` (Wire Transfer), `ONLINE` (Online Payment), `CASH` (Cash), `OTHER` (Other).
- **`GRANTRECEIPTSTATUS`**: `RECEIVED`, `DEPOSITED`, `CLEARED`, `BOUNCED`, `CANCELLED`. (Instant methods default `CLEARED`; cheque starts `RECEIVED`/`DEPOSITED`.)
- Idempotent seed (upsert by `TypeCode`+`DataValue`), same as existing MasterData seeds. Colour/sort optional but set sensible display order.

## 4. Migration + backfill — `Add_GrantFundReceipt_And_OrganizationBankAccount`

`Up()` order: create `OrganizationBankAccounts` → create `GrantFundReceipts` → FKs/indexes → seed MasterData rows (if not seeded via seeder) → **backfill** existing tranches:
```sql
-- Convert historical GrantStageHistory.AmountReceived rows into receipts (idempotent).
INSERT INTO "grant"."GrantFundReceipts"
  ("GrantId","CompanyId","ReceiptCode","Amount","CurrencyId","ReceivedDate",
   "PaymentMethodId","ReceiptStatusId","Notes","IsActive","IsDeleted","CreatedDate", ...)
SELECT h."GrantId", g."CompanyId",
       'MIGR-'||h."GrantStageHistoryId", h."AmountReceived", g."CurrencyId", h."TransitionDate",
       <OTHER method id>, <CLEARED status id>,
       COALESCE(h."Notes",'Migrated from tranche history'), true, false, now(), ...
FROM "grant"."GrantStageHistories" h
JOIN "grant"."Grants" g ON g."GrantId" = h."GrantId"
WHERE h."AmountReceived" IS NOT NULL AND h."AmountReceived" > 0
  AND NOT EXISTS (SELECT 1 FROM "grant"."GrantFundReceipts" r
                  WHERE r."ReceiptCode" = 'MIGR-'||h."GrantStageHistoryId");
```
Resolve method/status ids by subquery on MasterDatas (`GRANTPAYMENTMETHOD`/`OTHER`, `GRANTRECEIPTSTATUS`/`CLEARED`). `AmountReceived` column stays (history preserved); no new writes to it after this build.

## 5. Application layer — `Base.Application/Business/`

### 5a. Schemas (`Schemas/GrantSchemas/GrantSchemas.cs`, new `Schemas/ApplicationSchemas/…` for bank account)
- `GrantFundReceiptRequestDto` (nullable Id for create/update) + `GrantFundReceiptResponseDto` (includes resolved method/status/account/milestone names + `ReceivingAccountName`, `PaymentMethodName`, `StatusName`).
- `OrganizationBankAccountRequestDto` / `…ResponseDto` — response returns **masked** `AccountNumberMasked` (e.g. `••••1234`), never full number.
- `GrantFinancialSummaryDto { AwardedAmount, TotalReceived, Outstanding, TotalSpent, CashOnHand, ReceiptCount, ReceiptsByMethod[], HasAward }`.
- **Mapster:** confirm no `.Ignore` blocks new props in `GrantMappings`/mapping config; `AccountNumber` maps in only (request→entity), never entity→response.

### 5b. Grant fund receipt commands/queries — `GrantBusiness/GrantFundReceipts/`
- `CreateCommand/CreateGrantFundReceipt.cs` — validator: grant exists; `Amount > 0`; method FK exists; `CurrencyId` FK; optional `ReceivingAccountId`/`LinkedMilestoneId`/`DepositedByStaffId` FK-exist when set; if method = CHEQUE recommend (not force) deposit fields. Handler: resolve default status (CLEARED for non-cheque, else RECEIVED unless `DepositedDate` set → DEPOSITED); default `CurrencyId` to grant currency; generate `ReceiptCode` via `NumberSequenceGenerator` (entityType `GRANTRECEIPT`, execution-strategy wrapper like `CreateGrant`); UTC-normalise `ReceivedDate`/`DepositedDate`; also append a `GrantStageHistory` timeline note ("Funds received — {code} {amount}") **without** setting `AmountReceived` (timeline now sources receipts).
- `UpdateCommand/UpdateGrantFundReceipt.cs` — edit amount/method/ref/account/evidence/milestone/deposit/status/notes; UTC-normalise; re-validate FKs.
- `UpdateCommand/VoidGrantFundReceipt.cs` — set status `CANCELLED` (soft; preserves audit) rather than hard delete.
- `GetAllQuery/GetGrantFundReceipts.cs` — list by grant, newest first, projected response DTO.
- `GetByIdQuery/GetGrantFinancialSummary.cs` — one query:
  `TotalReceived = Σ Amount [GrantId, status ∉ {BOUNCED,CANCELLED}, !IsDeleted]`;
  `TotalSpent = Σ GrantExpense.Amount [GrantId, !IsDeleted]`;
  `Outstanding = AwardedAmount.HasValue ? Awarded − TotalReceived : null (HasAward=false)`;
  `CashOnHand = TotalReceived − TotalSpent`; `ReceiptsByMethod` grouped.

### 5c. Organization bank account CRUD — `ApplicationBusiness/OrganizationBankAccounts/`
- Create/Update/Toggle(+Delete guard)/GetAll/GetById. On Create/Update with `IsDefault=true`, demote other active defaults for the company. Delete guard: block if referenced by any non-void receipt (Restrict already enforces at DB; surface friendly message).

### 5d. Deprecate `RecordGrantTranche`
- Repoint `RecordGrantTrancheCommand` to create a `GrantFundReceipt` (method OTHER) for backward-compat, **or** remove its mutation once FE migrates. Plan: keep command as thin shim → `CreateGrantFundReceipt` this build; delete in a follow-up. Update `GetGrantTimeline.cs` to read receipts (fallback to legacy `AmountReceived` rows already backfilled, so timeline stays correct).

## 6. GraphQL — `Base.API/EndPoints/Grant/` + `.../Application/`

- **Queries** (`Grant/Queries/GrantQueries.cs`): `getGrantFundReceipts(grantId)`, `getGrantFinancialSummary(grantId)`. New `Application/Queries`: `getOrganizationBankAccounts`, `getOrganizationBankAccountById`.
- **Mutations** (`Grant/Mutations/GrantMutations.cs`): `createGrantFundReceipt`, `updateGrantFundReceipt`, `voidGrantFundReceipt`. New app mutations: `createOrganizationBankAccount`, `updateOrganizationBankAccount`, `toggleOrganizationBankAccount`, `deleteOrganizationBankAccount`.
- All under existing `[CustomAuthorize(DecoratorGrantModules.Grant, …)]` / appropriate module; BUSINESSADMIN role.

## 7. Frontend (`PSS_2.0_Frontend`)

Grant detail (`.../crm/grant/grantlist/grant/`):
- **Financial summary card** — Awarded / Received / Outstanding / Spent / Cash-on-hand (amounts right-aligned per [[feedback-amount-field-alignment]]; solid-bg KPI tiles per [[feedback-widget-icon-badge-styling]]; "no award set" empty state when `HasAward=false`).
- **"Funds Received" tab/panel** — receipts table (date, code, method chip, amount, status chip, receiving account, ref) + **Record Receipt** modal: Amount, Currency, Method (select), Received Date, Reference #, Receiving Account (picker → org accounts, shows masked number), Evidence URL (http/https validated, `isValidHttpUrl` helper), Linked Milestone (optional), **Deposited By** (staff picker) + **Deposited Date** (shown when method=CHEQUE), Status. Void action on a row.
- Replace the existing "Record Tranche" action with "Record Receipt"; timeline still shows receipts.

Org bank accounts (settings/config screen):
- CRUD list + form (AccountName, Bank picker, Branch, Account Number [write-only; masked on display], Currency, Default toggle). This is a CONFIG SETTINGS_PAGE per [[feedback-config-screens]] — account number masked + write-only + audited.

GraphQL/DTO wiring: `grant-queries/GrantQuery.ts` (+ receipts/summary), `grant-mutations/GrantMutation.ts`, new `OrganizationBankAccount` query/mutation files, DTOs in `domain/entities/...`.

## 8. Verification (E2E)

1. Config: create an OrganizationBankAccount → number stored, list shows masked last-4 only.
2. Grant (awarded 100k): record CHEQUE receipt 40k → pick receiving account + deposited-by + deposited-date → status DEPOSITED; summary Received=40k, Outstanding=60k, Cash-on-hand=40k−spent.
3. Record BANKTRANSFER 60k (CLEARED) → Received=100k, Outstanding=0.
4. Mark a cheque BOUNCED → Received drops, Outstanding rises (bounced excluded).
5. Void a receipt → excluded from all balances; row retained (CANCELLED).
6. Evidence URL rejects non-http(s); grid amounts right-aligned; chips solid-bg.
7. Legacy grant with old `AmountReceived` tranche → appears as a backfilled receipt; balances match pre-migration total.
8. Migration builds/applies clean on scratch DB (no multiple-cascade-path error); backfill idempotent on re-run.
9. Delete-guard: cannot delete a bank account referenced by a live receipt.

## Critical files
- NEW `Base.Domain/Models/GrantModels/GrantFundReceipt.cs`, `Base.Domain/Models/ApplicationModels/OrganizationBankAccount.cs`
- NEW EF configs (grant + application) + `ApplicationDbContext`/`IApplicationDbContext` DbSets
- Migration `Add_GrantFundReceipt_And_OrganizationBankAccount` (+ backfill SQL)
- MasterData seed (GRANTPAYMENTMETHOD, GRANTRECEIPTSTATUS)
- `Base.Application/Business/GrantBusiness/GrantFundReceipts/*`, `.../ApplicationBusiness/OrganizationBankAccounts/*`
- `Schemas/GrantSchemas/GrantSchemas.cs` (+ app schema for bank account)
- `Base.API/EndPoints/Grant/{Queries,Mutations}` + Application endpoints
- `RecordGrantTranche.cs` (shim/deprecate), `GetGrantTimeline.cs` (read receipts)
- FE: grant detail financial panel + receipts tab + modal; org-bank-account config screen; grant + bank GraphQL/DTOs

## Deferred (not this build)
- Planned-disbursement schedule / expected-vs-received milestone reconciliation (chose "light" link).
- Real evidence file upload (flip when private blob container provisioned — same dormant path as grant attachments).
- Over-allocation guard (Σ receipts ≤ Awarded) — receipts can legitimately exceed on FX/top-ups; surface warning only, not a hard block.
- Multi-currency FX snapshot on receipt beyond storing CurrencyId + rate value (follow [[feedback-fx-direct-pair]] if cross-currency receipts arise).
