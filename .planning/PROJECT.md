# CFMM Payoff Replication — Plank ↔ GAMS Connection Layer

## What This Is

A research-engineering framework for replicating **arbitrary contingent payoffs** `Φ(S_T)` from a CFMM by tuning two parameter families — the **dynamic fee kernel** and the **liquidity density function (LDF)** / trading bonding curve — so the target payoff is reproduced out of classical **fee revenue**. The system spans two tracks that today don't talk to each other: a **Plank** on-chain implementation of CFMM dynamics (compiled to EVM bytecode, deployed behind a Uniswap-V4-style `beforeSwap` hook) and a **GAMS** algebraic model that solves for optimal curve/fee parameters. This project builds the **connection layer** between them: a shared semantic kernel, a GAMS↔Plank parameter map, and a thin open-loop pipeline that takes a target payoff through GAMS to a running Plank simulation.

## Core Value

A target contingent payoff can flow end-to-end — **payoff → GAMS solves optimal parameters → parameters encoded → Plank CFMM simulates** — with the two tracks agreeing on one authoritative type/parameter kernel. If everything else is deferred, this open-loop bridge plus shared kernel must work for at least one contingent payoff.

## Current State (v3.0 shipped 2026-07-19)

**v3.0 — VegaAccountMod Vault (H1 issuance, exogenous risk price): SHIPPED.** `VegaAccountMod.plk` is a live, proven deposit-only vault: deposit collateral → vega-exposure shares at `p_risk = oracle/(1−h)`, every claim a CALLED test or an OBSERVED mutation kill, verified phase-by-phase with independent mutant re-kills against the machine-checked Lean authority. `PLANK_SKIP` is empty; commands of record: `make compile` 11 ok/0/0, `make test` 74 pass / 4 pre-existing pos_spec fails (vol-type track's). Details: `.planning/MILESTONES.md`, tag `v3.0`.

**Next milestone: not yet defined.** Candidate directions (pick via `/gsd:new-milestone`): resume v2.0 Phases 10–11 (vol-oracle discriminating corpora + edges); vault v2 (withdraw/redeem + per-account ledger — reopens the first-depositor/donation analysis); oracle wiring (endogenous p_risk + setter auth, D2/P0/P2); resume v1.0 GAMS plumbing.

## Requirements

### Validated

<!-- Inferred from existing code (brownfield). "existing" = present in repo, not necessarily hardened/verified. -->

- ✓ Plank→EVM FFI build/deploy bridge (`lib/plank-foundry-deployer/src/PlankDeployer.sol`, `plankDeployFFI`) — existing
- ✓ Draft shared type kernel (`spec/entities/Types.md`: `NumberFormat`, `BoundedValue`, `VolatilityTermStructure`, `Grid`/`Lens` types) — existing
- ✓ GAMS algebraic model skeleton (`primitives.gms`, `PricingKernel.gms`, `LiquidityKernel.gms`, `TradingRegion.gms`, `PayoffModule.gms`, `dynamic/InitState.gms`) — existing, outside repo at `../experiments/gams`
- ✓ ~~bunni-v2 LDF conformance harness~~ — DELETED 2026-07-16 (`ead50b8`, empty scaffold); recover from git history with LDF-01
- ✓ ~~Stochastic swap-flow proxy (`BinomialProxy.plk`/`SwapAmtGen.plk`) and canonical market-state (`ReferenceMarket.plk`)~~ — DELETED 2026-07-16 (`ead50b8`) as unmaintained; recover from git history when the v1.0 pipeline resumes

### Active

<!-- This milestone. Hypotheses until shipped. -->

- [ ] Elevate `spec/entities/Types.md` into the **authoritative shared kernel** both tracks conform to (types, units, bounds, semantics)
- [ ] Define the **GAMS↔Plank parameter map** with explicit fixed-point encodings (`xi`↔`priceElasticity`/LDF `alpha`, `iota`↔`statePartitionDelta`/`tickSpacing`, `baseTick`; WAD / Q64.96 conventions)
- [ ] Vendor the GAMS sources into `model/` inside this repo (currently external `../experiments/gams`, 232K)
- [ ] Build the **open-loop runtime bridge**: GAMS optimization output → serialized/encoded parameters → Plank `IMarketDynamics.initVolTermStructure()` (selector `0xd9c112ef`)
- [ ] Thin **end-to-end pipeline** replicating one **contingent payoff** instance: payoff spec → GAMS solves `(xi*, iota*)` → encoded → Plank simulates → replication error measured
- [ ] Repo restructure: make **`wvs-finance/cfmm-replicationPlank`** the canonical **public** repo; **`JMSBPP/cfmm-replicationPlank`** becomes a fork
- [ ] Light literature grounding: map the key control parameters to the behavioral theorems/assumptions they encode (supporting input from existing notes + a few references — not a formal review)
- [ ] First real compilation pass on the Plank sources used by the pipeline (fix parse/type stubs blocking the path)

### Out of Scope

- **Closed-loop adaptive feedback controller** (`src/DynamicCFMM.plk` control law that updates `xi`/`iota` as the market evolves) — deferred to next milestone; this milestone is the open-loop bridge it sits on
- **Formal literature review deliverable** — deferred; literature is supporting input only here
- **Production / mainnet deployment** of the V4 hook — deferred; simulation-first
- **Cryptographically-secure on-chain randomness** — out; the simulation uses the documented deterministic/proxy swap-flow model, not VRF
- **Replicating multiple payoffs / a payoff library** — out; one contingent-payoff proof case this milestone (design stays payoff-agnostic)

## Context

- **Two-language duality is the defining trait.** On-chain CFMM logic is written in **Plank** (`.plk`, custom EVM language with its own compiler at `lib/plank-monorepo/plankc/`, `v0.1.1`), compiled to bytecode via FFI at test time; Solidity/Foundry is thin glue. GAMS is the off-chain algebraic solver. The research contribution lives in the bridge between them.
- **The shared "file kernel"** is `spec/entities/Types.md` — the formal type system both tracks reference. The parameter→behavior grounding connects out to the **`cfmm-theory`** knowledge base (local; cited by `KERNEL.md` citekey, no code dependency), whose root **`KERNEL.md`** is the primary upstream reference (extensible to notes like `cfmm-control/ELASTICITY_CONTROL.md`, `cfmm-options/PAYOFF.md`, `cfmm-options/FEE_PREMIUM.md`). The link is **by URL/citekey only** (no submodule/code dependency, because this repo is public); the reference markdown lives under `spec/refs/`, separate from the existing `refs/` Plank-playground web app.
- **Stochastic model** (`NOTES.md`): swap direction `I_{n,t} ∈ {-1,+1}` (P=½ each), counts `N_t ~ Poisson(λ_t)`, amounts `Δy_{n,t} ~ LogNormal(μ_t, σ²)`, with deterministic proxy `Δy(t) = 19 + 1.0001^{η·t⁴}`. Canonical start state: `(di=20, i=100, i_l=-120, i_u=120, L=1e18, Y=100e18)`.
- **Maturity is early.** Per the codebase map (`.planning/codebase/CONCERNS.md`), most `.plk` files are stubs or have parse/type errors; tests are largely empty shells; the Plank↔GAMS bridge is a zero-line gap (the core deliverable). The repo had no history before this initialization.
- **Reference ecosystem** in `lib/`: bunni-v2 (LDF interface + Geometric reference), Uniswap v3/v4 core, panoptic-v2-core, plankified-univ3 (Plank UniV3 math), plus Unistrata/Shizo/Mochi-Yield/Centrifuge references cited in `NOTES.md`.

## Constraints

- **Tech stack**: Plank `v0.1.1` (`.plk`, compiled via `PlankDeployer` FFI, backend `sona`), Foundry (Solidity glue/tests), GAMS (algebraic model). Pin the `plank` binary version for reproducibility.
- **Repository ownership**: canonical repo MUST be **public** and **owned by the `wvs-finance` org**; `JMSBPP` holds a **fork**. Current state is inverted (`JMSBPP/cfmm-replicationPlank` is standalone origin; `wvs-finance/cfmm-replicationPlank` does not yet exist) — restructuring is a setup task, and any public/ownership-transfer action is confirmed before execution.
- **GAMS location**: vendor into `model/` inside the repo (not left external, not a submodule unless chosen at execution).
- **Scope discipline**: open-loop this milestone; the adaptive controller is explicitly next-milestone.
- **Fixed-point rigor**: GAMS floats ↔ Plank `u256` fixed-point (WAD `1e18`, Q64.96) encoding must be defined before any type implementation, to avoid dimensional bugs.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Deliverable = shared kernel **+** minimal end-to-end pipeline (not spec-only, not runtime-only) | Need both the agreed semantics and proof the pipe carries a payoff through | — Pending |
| Open-loop parameter seeding now; closed-loop controller deferred | Bridge is the prerequisite the controller depends on; sequence risk | — Pending |
| Target = **any contingent payoff** (fixed-income is one instance), one proof case this milestone | Generality is the point ("any payoff from fee revenue"); keep design payoff-agnostic | — Pending |
| Literature = supporting input only (no formal review) | Notes + key references suffice to ground parameter→behavior mapping now | — Pending |
| Vendor GAMS into `model/` inside the repo | Single-repo dual-track; bridge work needs both sides co-located | — Pending |
| `wvs-finance` owns canonical public repo; `JMSBPP` forks | Org ownership / public visibility requirement | — Pending |
| Theory grounding links to `cfmm-theory` `KERNEL.md` by URL/citekey (no submodule); refs under `spec/refs/` | Repo is public — cfmm-theory is local-only, so cite rather than depend | — Pending |
| v3.0 vault pipeline is **H1 only** (`p_risk = oracle/(1−h)`, `h<1` enforced); distance D2 and P0/P2 composition deferred | Smallest proven core first — mirrors how the oracle track grew; the Lean decision table's issuance row backs H1 | ✓ Good — shipped v3.0 in 3 days, 0 arithmetic defects found |
| v3.0 `p_risk` is **exogenous/settable** (validated > 0); RealizedVolatilityMod wiring deferred | tbd.md's own stated assumption; keeps the vault testable in isolation; vol→price conversion depends on pos_spec types that still have red harness tests | ✓ Good — isolation made the e2e differential and battery cheap |
| v3.0 keeps `totalDeposits` / `totalShares` / `riskWeightedShares` as **three distinct state variables** (d ≡ 1 in v1) | Lean `discounted_claim_counterexample` refutes conflating the risk-adjusted subtotal with the accounting total | ✓ Good — read-conflation proved unkillable except by raw vm.load, vindicating the slot discipline |
| Lean lemmas are the v3.0 test oracle (each lemma → a fuzz property vs a Solidity reference mock) | Same differential discipline that proved the vol oracle; the lemmas are machine-checked so the properties are not aspirational | ✓ Good — with one honest carve-out: issuance_haircut_equiv is ℝ-only; integers get the one-sided transfer |

---
*Last updated: 2026-07-19 — v3.0 milestone SHIPPED and archived; v2.0 paused after Phase 9; v1.0 paused*
