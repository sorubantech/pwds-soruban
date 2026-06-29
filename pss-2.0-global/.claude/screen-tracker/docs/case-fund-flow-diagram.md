# Case Management — Money Flow (Detailed Flowchart)

> Renders in VS Code (Mermaid preview) / GitHub. Box = node · diamond = decision · subgraph = area.
> Each node names the screen + the entity/table behind it.
> Colors:  green = built ✅ · orange = missing-build 🔧 · red = gap/no-link ❌ · gray = planned ⏳

```mermaid
flowchart TD

  %% ═════════ ① PROGRAM ═════════
  subgraph PROG["① PROGRAM — plan & need"]
    P1([Create Program<br/>case.Programs]):::built
    P1a([Services × capacity → NEED<br/>ProgramFundingMath.ComputeAnnualNeed]):::built
    P1b([Eligibility criteria<br/>+ verification method]):::built
    P1c([Outcome metrics<br/>baseline / target / freq]):::built
    P2{Submit for approval}:::built
    P3([Program ACTIVE<br/>status MasterData · form locks]):::built
    P1 --> P1a --> P1b --> P1c --> P2
    P2 -->|Reject + reason| P1
    P2 -->|Approve| P3
  end

  %% ═════════ ④ COMMUNICATIONS ═════════
  subgraph COMMS["④ COMMUNICATIONS — tell the donors"]
    C1([PROGRAM_ANNOUNCEMENT<br/>EmailTemplate]):::build
    C2([Program placeholders<br/>PlaceholderDefinition · EntityType=Program]):::build
    C3([ProgramDonorAudienceQuery<br/>copy EventDonorAudienceQuery · honors DoNotEmail]):::build
    C4([Fire hook on approve<br/>+ 'announce to donors' toggle]):::build
    C5([Send infra · EmailSendJob / EmailSendQueue<br/>provider resolution]):::built
    C1 --> C2 --> C3 --> C4 --> C5
  end
  P3 -. fires on approve .-> C1

  %% ═════════ ② FUNDING SOURCES ═════════
  subgraph FSRC["② FUNDING SOURCES — who funds it (Fund Allocation screen, post-approval)"]
    F1([Add funding source<br/>case.ProgramFundingSource]):::built
    F2{Funding model<br/>gates area}:::built
    FG([Grant source · GrantId]):::built
    FD([Donation Purpose source · DonationPurposeId]):::built
    FS([Sponsor source · SponsorContactId]):::built
    F3([Commit Expected/year<br/>+ cadence + currency]):::built
    F4{Approve source?<br/>FUNDSOURCESTATUS}:::built
    F5([APPROVED]):::built
    FX([CLOSED — funder stopped · locked]):::built
    F6([Payment log<br/>case.ProgramFundingTransaction<br/>WAITING → TRANSFERRED]):::built
    F1 --> F2
    F2 -->|GRANT| FG
    F2 -->|POOLED| FD
    F2 -->|INDIVIDUAL / MIXED| FS
    FG --> F3
    FD --> F3
    FS --> F3
    F3 --> F4
    F4 -->|Close / Reject| FX
    F4 -->|Approve| F5 --> F6
  end
  P3 --> F1

  %% ═════════ ③ FUND COLLECTION — money IN ═════════
  subgraph FIN["③ FUND COLLECTION — money IN"]
    DP([Donation Purpose<br/>fund.DonationPurposes · target vs raised]):::built
    I1([P2P · P2PCampaignPage / P2PFundraiser]):::built
    I2([Pledge · Pledge / PledgePayment<br/>committed vs partial received]):::built
    I3([Online Donation Page · #10]):::built
    I4([Campaign]):::built
    DN([Donors · Contact + ContactDonationPurpose]):::built
    ID([Global Donations<br/>fund.GlobalDonations + GlobalDonationDistribution<br/>amount · receipt · date]):::built
    DP --> I1 --> ID
    DP --> I2 --> ID
    DP --> I3 --> ID
    DP --> I4 --> ID
    DN --> ID
  end
  FD -. funds the same cause .-> DP
  ID --> GAP
  GAP([❌ NO auto-link<br/>donations do NOT feed program Collected<br/>Collected = Σ TRANSFERRED, hand-entered]):::gap
  GAP -. seed-match A · or build-rollup B .-> F6

  %% ═════════ DASHBOARD ═════════
  F6 --> M1([THE 4 NUMBERS<br/>Need · Expected · Collected · Used · Available<br/>GetProgramFundingAllocation]):::built

  %% ═════════ ⑤ BENEFICIARY ═════════
  subgraph BEN["⑤ BENEFICIARY — who's helped"]
    B1([Register · Beneficiary · BEN-YYYY-SEQ]):::built
    B2([Enrol into program · BeneficiaryEnrollment]):::built
    B3([Verify · Verification tab<br/>DFT → VRF → ACT]):::built
    B4([Reveal on public page<br/>sponsorship / P2P route]):::planned
    B1 --> B2 --> B3 -.-> B4
  end
  P3 --> B1
  B4 -. public donations .-> ID

  %% ═════════ ⑥ CASE & DISTRIBUTION — money OUT ═════════
  subgraph CASE["⑥ CASE & DISTRIBUTION — money OUT"]
    CS1([Create case · case.Cases<br/>1 beneficiary + 1 program]):::built
    CST([Tabs · Action Plan · Service Log<br/>Milestones · Notes]):::built
    CS2{Fund transfer<br/>funding-flow}:::planned
    T1([Cash to beneficiary]):::planned
    T2([Charity pays school · EDUCATION]):::planned
    T3([Charity pays hospital · MEDICAL]):::planned
    T4([In-kind · goods · no cash]):::planned
    U1([Service Log = USED<br/>BeneficiaryServiceLog.AmountCents<br/>guard: ServiceLogFundingGuard caps at Available]):::built
    UA([Per-source attribution<br/>ServiceLog.FundingSourceId]):::planned
    CO{Close / Cancel}:::built
    CG([Beneficiary GRADUATED / EXITED]):::built
    CC([Case CANCELLED]):::built
    CS1 --> CST --> CS2
    CS2 -->|cash| T1
    CS2 -->|education| T2
    CS2 -->|hospital| T3
    CS2 -->|in-kind| T4
    T1 --> U1
    T2 --> U1
    T3 --> U1
    T4 --> U1
    U1 -. which funder paid .-> UA
    U1 --> CO
    CO -->|Close + outcome| CG
    CO -->|Cancel| CC
  end
  B3 --> CS1
  M1 -. Available gates spend .-> CS2
  U1 --> M1

  %% ═════════ styles ═════════
  classDef built   fill:#dcfce7,stroke:#16a34a,color:#14532d;
  classDef build   fill:#ffedd5,stroke:#ea580c,color:#7c2d12;
  classDef gap     fill:#fee2e2,stroke:#dc2626,color:#7f1d1d;
  classDef planned fill:#f1f5f9,stroke:#64748b,color:#334155;
```
