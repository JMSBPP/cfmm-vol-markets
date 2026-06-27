# CFMM Payoff Replication — Plank ↔ GAMS Connection Layer

## What This Is

A research-engineering framework for replicating **arbitrary contingent payoffs** `Φ(S_T)` from a CFMM by tuning two parameter families — the **dynamic fee kernel** and the **liquidity density function (LDF)** / trading bonding curve — so the target payoff is reproduced out of classical **fee revenue**. The system spans two tracks that today don't talk to each other: a **Plank** on-chain implementation of CFMM dynamics (compiled to EVM bytecode, deployed behind a Uniswap-V4-style `beforeSwap` hook) and a **GAMS** algebraic model that solves for optimal curve/fee parameters. This project builds the **connection layer** between them: a shared semantic kernel, a GAMS↔Plank parameter map, and a thin open-loop pipeline that takes a target payoff through GAMS to a running Plank simulation.

## Core Value

A target contingent payoff can flow end-to-end — **payoff → GAMS solves optimal parameters → parameters encoded → Plank CFMM simulates** — with the two tracks agreeing on one authoritative type/parameter kernel. If everything else is deferred, this open-loop bridge plus shared kernel must work for at least one contingent payoff.

## Requirements

### Validated

<!-- Inferred from existing code (brownfield). "existing" = present in repo, not necessarily hardened/verified. -->

- ✓ Plank→EVM FFI build/deploy bridge (`lib/plank-foundry-deployer/src/PlankDeployer.sol`, `plankDeployFFI`) — existing
- ✓ Draft shared type kernel (`spec/entities/Types.md`: `NumberFormat`, `BoundedValue`, `VolatilityTermStructure`, `Grid`/`Lens` types) — existing
- ✓ GAMS algebraic model skeleton (`primitives.gms`, `PricingKernel.gms`, `LiquidityKernel.gms`, `TradingRegion.gms`, `PayoffModule.gms`, `dynamic/InitState.gms`) — existing, outside repo at `../experiments/gams`
- ✓ bunni-v2 LDF conformance test harness wired (`test/LiquidityDensityFunctionPlankTest.t.sol` against `ILiquidityDensityFunction`) — existing, test bodies stubbed
- ✓ Stochastic swap-flow proxy design per `NOTES.md` (`src/lib/BinomialProxy.plk` direction `I_{n,t}`, `src/lib/SwapAmtGen.plk` amount `ΔY(t)`) — existing, needs hardening
- ✓ Canonical Plank market-state contract (`src/ReferenceMarket.plk`, `src/MarketState.plk`) — existing, partial

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
- **The shared "file kernel"** is `spec/entities/Types.md` — the formal type system both tracks reference.
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

---
*Last updated: 2026-06-27 after initialization*
