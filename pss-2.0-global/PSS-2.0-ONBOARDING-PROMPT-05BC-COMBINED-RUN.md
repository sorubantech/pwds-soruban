# PSS 2.0 — P-05b + P-05c combined dev-session run (T-B7 + T-B8)

**Purpose:** run **two** independent follow-up patches to P-05 in a single dev session. This is a
**cover / runner** doc — the full instructions live in the two prompt files it points to. Do both,
then return **one** combined hand-back.

**Neither patch adds:** schema · migration · capability · mutation · query · seed.
(P-05b is 4 BE edits + an FE swap; P-05c is FE-only.)

---

## ① The two patches (run in this order)

| # | Prompt file | Task | Area | What it does |
|---|-------------|------|------|--------------|
| 1 | `PSS-2.0-ONBOARDING-PROMPT-05B-LEAD-LIFECYCLE.md` | **T-B7** | BE `Base.Application/Business/OpsBusiness/LeadManagement/` + FE `presentation/components/page-components/ops/leads/` | Server-governs `Lead.Status`: ordered transition guard, `WON` reachable **only** via `ApproveCommercialTerm`, create-time `WON` block; FE swaps the free status dropdown for lifecycle action buttons. |
| 2 | `PSS-2.0-ONBOARDING-PROMPT-05C-PAYMENT-GATEWAY-PICKER.md` | **T-B8** | FE `presentation/components/page-components/ops/deals/` + `domain/entities/ops-service/CommercialTermDto.ts` | Replaces the deal form's free-text `paymentGatewayCode` `FormInput` with a closed `FormSelect` (`RAZORPAY` / `STRIPE` + "— Not decided —"); field stays optional (blank → null). |

**Execute each prompt exactly as written** — its own ②/③/④ scope and hard-constraints sections are
authoritative. This cover doc only sequences them and merges the build evidence.

---

## ② Why they combine safely (no conflict)

- **No shared file.** P-05b works in the **`ops/leads/`** FE folder + BE `LeadManagement/`; P-05c
  works in the **`ops/deals/`** FE folder + `CommercialTermDto.ts`. The one file both prompts
  *mention* is `ApproveCommercialTerm.cs` — but P-05b **edits** it (auto-WON hook) and P-05c only
  **reads its DTO field name**; P-05c changes no BE file. No merge conflict either way.
- **Order-free.** They share no state, so 1→2 or 2→1 both work. The table order is just tidy.
- **One shared surface at runtime:** approving a deal (P-05c form feeds it) is exactly what P-05b's
  auto-WON hook keys off — so after both land, saving a deal with a chosen gateway and then approving
  it should (a) persist the gateway code and (b) flip the parent lead to `WON`. Worth an end-to-end
  eyeball once both are in.

---

## ③ Combined build evidence (run once, after BOTH patches)

- **BE** (P-05b only touches BE): `dotnet build …/Base.API/Base.API.csproj -c Debug` → **0 CS errors**.
  Stop any running `Base.API` first to avoid the DLL file-copy lock (`MSB3026/3027/3021`); a
  redirected-output build is acceptable evidence — say which you used.
- **FE** (covers both patches): `npx tsc --noEmit --incremental false` → **exit 0**. Only exit 0
  counts as clean (a run that reports only a pre-existing config error checked zero files).

---

## ④ One combined hand-back — confirm all of:

**P-05b (T-B7):**
- the 4 BE edits are in place; list the **exact rejected transitions** proving `WON` is unreachable
  via `UpdateLead`; create rejects `WON`; the FE status dropdown is gone → lifecycle action buttons;
  and **where** the buttons live (list row vs a detail header).

**P-05c (T-B8):**
- gateway is now a dropdown of Razorpay / Stripe + "— Not decided —"; field still optional and saves
  `null` when blank; editing a deal that already has a code pre-selects it; **no** BE/schema/seed
  touched.

**Both:**
- the combined BE + FE build evidence above; and any property / component / route name that differed
  from what the prompts assumed (verify-before-use — flag it, don't silently rename).
