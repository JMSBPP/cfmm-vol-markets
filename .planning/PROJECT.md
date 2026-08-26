# CFMM Payoff Replication — Plank ↔ GAMS Connection Layer

## What This Is

A research-engineering framework for replicating **arbitrary contingent payoffs** `Φ(S_T)` from a CFMM by tuning two parameter families — the **dynamic fee kernel** and the **liquidity density function (LDF)** / trading bonding curve — so the target payoff is reproduced out of classical **fee revenue**. The system spans two tracks that today don't talk to each other: a **Plank** on-chain implementation of CFMM dynamics (compiled to EVM bytecode, deployed behind a Uniswap-V4-style `beforeSwap` hook) and a **GAMS** algebraic model that solves for optimal curve/fee parameters. This project builds the **connection layer** between them: a shared semantic kernel, a GAMS↔Plank parameter map, and a thin open-loop pipeline that takes a target payoff through GAMS to a running Plank simulation.

## Core Value

A target contingent payoff can flow end-to-end — **payoff → GAMS solves optimal parameters → parameters encoded → Plank CFMM simulates** — with the two tracks agreeing on one authoritative type/parameter kernel. If everything else is deferred, this open-loop bridge plus shared kernel must work for at least one contingent payoff.

## Current State (v3.0 shipped 2026-07-19)

**v3.0 — VegaAccountMod Vault (H1 issuance, exogenous risk price): SHIPPED.** `VegaAccountMod.plk` is a live, proven deposit-only vault: deposit collateral → vega-exposure shares at `p_risk = oracle/(1−h)`, every claim a CALLED test or an OBSERVED mutation kill, verified phase-by-phase with independent mutant re-kills against the machine-checked Lean authority. `PLANK_SKIP` is empty; commands of record: `make compile` 11 ok/0/0, `make test` 74 pass / 4 pre-existing pos_spec fails (vol-type track's). Details: `.planning/MILESTONES.md`, tag `v3.0`.

## Current Milestone: v6.0 — Model Output Store + VolumePath Bridge (rpc_api workstream)

**Goal:** A Postgres/JSONB **keyed store for model outputs** whose key is the shock that
produced them, so an identical shock **skips the solve** and a re-solve that disagrees is
caught — and, on top of it, the issue #25 bridge that carries a live Anvil `next` event
through the GAMS VolumePath prover to the fixture the forge test reads.

**Source:** GitHub issue #25 (`rpc_api: volume_path bridge — Anvil state → GAMS prover →
foundry fixture`). Binding reference: `model/mev_tax_model_one/VOLUME_PATH.md` — §2 the
seven inputs, §3 the output shape and determinism guarantee, §4 every abort is named and
**gated on exit code, never log text**. Consume, do not re-derive.

**Why the store comes first:** this is roadmap items 6–8 (`Integrate a PostGreDB with
haskell API`, `haskell DB API to GAMS`, `haskell API from GAMS`) arriving with their first
real tenant. The key is `H(seven inputs ‖ GAMS version ‖ CONOPT version)`, which makes
`VOLUME_PATH.md` §3's *"same inputs + same toolchain → same bytes"* a **standing falsifiable
check** rather than prose: re-solving an existing key must reproduce it byte-for-byte.

**Target features:**
- **Postgres foundation + Haskell client** — library decision (open; `postgresql-simple` is
  a prior, not a conclusion), connection/config, migrations, JSONB schema for keyed model
  outputs. Model-agnostic layout (`<model>/<key>`); only the `volume_path` tenant is built.
- **The keyed store** — cache hit elides the solve; re-solve of an existing key must
  reproduce bytes; pin/retain flags; **reset as its own operation**; append-only run log
  carrying `(timestamp, key, next-tx-hash, block)` for chronology the content key can't give.
- **GAMS invocation layer** — subprocess, gate on exit code (§4), toolchain version
  detection feeding the key.
- **Anvil read layer** — decode the `next` event (`SELECTOR_NEXT 0xd3827b0b` =
  `next(address,uint160,int24,uint24,uint24)`), read price/liquidity/fee, **every read
  pinned to one block**. BLOCKED on the plank worktree emitting the event.
- **Fee splitter** — the pool fee splits into (φ_X, φ_M) under two constraints:
  `(1−φ_X)(1−φ_M) = 1−f` sets the **level**, so φ̄ — the prover's composed fee — IS `f` in exact
  rational arithmetic. **Over the integer pip grid it is not generally attainable**, and that is a
  property of the grid rather than a defect: the identity holds only when `10⁶` divides
  `φ_X·φ_M`, true for 4.935 % of fees (987 of 20000) and for none of 100 / 500 / 3000 / 10000
  pips (MEASURED 2026-08-17). The splitter therefore rounds to nearest and records the exact
  residual as a first-class field: φ̄ equals `f` exactly only on the exact pairs, and otherwise
  equals `f` plus that recorded residual, bounded below half a pip by construction (MEASURED:
  `split_for 0 3000 490000` yields (752, 2250) composing to **3000.308** pips). The derived pips,
  not `f`, are what reach GAMS and the key — ROADMAP SC-1, which already provides for the rounding
  rule. Admissibility is the prover's own §1.3 test transcribed from
  `volume_path.gms:100-108`: `(φ̄²+Δφ²)δ*² − (φ_X+φ_M)·φ̄·δ* + φ_X·φ_M ≤ 0`, with **φ̄ the
  COMPOSED fee** and **Δφ the FULL gap `φ_M−φ_X`**. Exact integer arithmetic over pips.
  **CORRECTION (2026-08-17):** an earlier reading here took φ̄ as the arithmetic mean and Δφ as
  the ellipse SEMI-axis, giving `δ* ≥ 2ρ/(1+ρ²)`. That is WRONG — measured against the prover it
  is 2× too large, falsely refuses ~82,700 pips of admissible δ* at the fixture fees, and its
  corollary "no target reachable unless ρ ≥ 2+√3" is false. The prover's form independently
  reproduces §1.1's `δ ≤ 1/2` ceiling as its upper root; the mistaken form gives 1. Closed form,
  no optimizer — **proved feasible before GAMS is invoked**, so infeasibility is a refusal we
  explain, not an exit code we interpret.
- **The resident loop + fixture publication** — the loop re-solves continuously; publishing
  the newest run to `test/models/mev_tax_model_one/fixtures/volume_path.json` is what keeps
  the forge test's input from being a moving target.

**Territory:** the store lives under `offchain/` (ours). The only thing written into
`test/` is the latest fixture copy — one file into another track's tree, not a database.

## Superseded Milestone Header: v5.0 — VolOrder V2 Offchain Re-Pin + Stochastic Drivers (rpc_api workstream)

**SHIPPED 2026-08-03** — merged to develop as `19a06f3` (PR #9, 209 commits). Note the
merge used `--admin`, bypassing the `gate` check: CI has **never** validated it, and the
`haskell` gate job's first real execution will be on develop. Verified locally instead:
`cabal test` 91/91, zero `-Wall` warnings, `forge test` 252/0 (== develop's baseline),
`verify-rig.sh`/`verify-import.sh` exit 0.

**Goal:** The rpc_api Haskell client speaks the VolOrder **V2 (targetVega) ABI** and both
stochastic drivers — price diffusion and Poisson VolOrder creation — run end-to-end
against the four-script deploy rig, emitting the real event set.

**Source:** GitHub issue #13 (plank workstream handoff, `feat/plank` @ `df7088f`).
Binding references, in precedence order: `src/interfaces/<namespace>/*.plk` (selectors +
events, cast/solc-verified), `.planning/rpc-api-volorder-v2-HANDOFF.md`,
`notes/DATA_CONTRACT.md`, `notes/UNITS_AND_SCALES.md`. Consume, do not re-derive.

**Target features:**
- V2 ABI re-pin of `offchain/lib/VolOrder/{Types,Encoding,Decode,Rpc}.hs`: 4-arg
  `create_order(uint88,uint24,uint16,uint96)` = `0x98d950ec`; V2 batch input word
  (`skew@0..15 | strike@16..103 | width@104..127` masked-interior, `targetVega@128..223`
  unmasked-top, bits ≥ 224 zero); 248-bit storage word (`targetVega@152..247`); E1 v2
  topic0 `0x18bd4d46…`; fix the pre-existing stale topic0 (`0xa8892769…`) with a
  topic0-pin test.
- `StochasticOrderGen` draws a `targetVega` per order — raw LIQUIDITY units
  (dimension (ii), `UNITS_AND_SCALES.md` §2), valid `[1, 2^96−1]`, realistic 1e18–1e21.
- Both drivers live against the `foundry-scripts/deploy/` rig (anvil-first): stochastic
  price diffusion (E3 `TimepointWritten` per step) + stochastic V2 VolOrder creation
  (single + batch, preview/readback consistency incl. targetVega).

## Queued Milestone: v7.0 — Subgraph for the vol-instrument event set

**Renumbered from v6.0 (2026-08-16)** — the model output store took v6.0 on dependency
grounds: the subgraph needs somewhere to put what it indexes, and v6.0 builds exactly that
(Postgres + JSONB + a Haskell DB layer). Doing it first means this milestone inherits
storage infrastructure instead of inventing its own. Nothing about issue #14's scope
changed; only its number and its position in the queue.

GitHub issue #14: index E1v2/E3/E4/E5/E6 per `notes/DATA_CONTRACT.md` and materialize
the position-epoch panel (keyed by uint48 `seriesIdHash`) that the cfmm-gams
`execute_loadDC` reader consumes (cfmm-gams#1) — the chain → subgraph → GAMS missing
middle. Originally sequenced after v5.0 because it consumes the event stream v5.0's drivers
generate; now after v6.0. Hard rules already pinned by the issue: v1 E1 topic0 retired-never-live;
E5↔`Swap` same-tx nearest-preceding-logIndex join with `FeeApplied.fee == Swap.fee`
integrity assert; `tObs` = E3's EMITTED timestamp; σ² windowed from E6 history;
sign-extension + golden vectors for tokenId decode when E2 ships.

## Shipped: v4.0 — VolOrderManagerMod + Multicall (plank workstream)

**Goal:** A new `VolOrderManagerMod.plk` module — a vol-order REGISTRY (`create_order(uint88,uint24,uint16)` = strike/width/skew, selector `0x6501fe94`, independently cast-sig-verified) plus a BEST-EFFORT multicall entrypoint batching N create_order calls in one tx — built for the rpc_api Haskell track's StochasticOrderGen (Poisson-arrival order batching; their PR #9 shipped create_order/write_price/StochasticPriceGen offchain and awaits this on-chain surface).

**Target features:**
- `create_order`: validate bounds (strike u88, width u24, skew u16; revert on zero-width), construct the KEPT pos_spec `VolOrder` type, assign sequential order id, store at keccak-derived slot, `orderCount` accumulator — registry ONLY, no tick/price computation (pos_spec pricing has 4 red harness tests on the vol-type track and stays out)
- Multicall: BEST-EFFORT per-call semantics — failed orders are skipped without reverting the batch, per-call success/order-id results returned; a failed call leaves NO partial state, successful calls persist
- Dynamic-array ABI in Plank (calldata array in, results out) — genuinely new ground: every existing module selector takes fixed words; this is the milestone's main technical risk
- Readers for every stored field (module-not-a-black-box rule); interface file with cast-sig-verified signature strings; v3.0's full discipline (CALLED-green, constructed corpora, observed-RED mutation battery, Solidity reference mock differential)

**Consumer contract (from peer coordination, rpc_api track `mv15a18k`):** create_order selector 0x6501fe94 confirmed both sides; batch-size bound and per-call return shape to be confirmed when the peer answers the open semantics message — requirements assume per-call (success, orderId) pairs until then.


## Requirements

### Validated

<!-- Inferred from existing code (brownfield). "existing" = present in repo, not necessarily hardened/verified. -->

- ✓ Plank→EVM FFI build/deploy bridge (`lib/plank-foundry-deployer/src/PlankDeployer.sol`, `plankDeployFFI`) — existing
- ✓ Draft shared type kernel (`spec/protocol/entities/Types.md`: `NumberFormat`, `BoundedValue`, `VolatilityTermStructure`, `Grid`/`Lens` types) — existing
- ✓ GAMS algebraic model skeleton (`primitives.gms`, `PricingKernel.gms`, `LiquidityKernel.gms`, `TradingRegion.gms`, `PayoffModule.gms`, `dynamic/InitState.gms`) — existing, outside repo at `../experiments/gams`
- ✓ ~~bunni-v2 LDF conformance harness~~ — DELETED 2026-07-16 (`ead50b8`, empty scaffold); recover from git history with LDF-01
- ✓ ~~Stochastic swap-flow proxy (`BinomialProxy.plk`/`SwapAmtGen.plk`) and canonical market-state (`ReferenceMarket.plk`)~~ — DELETED 2026-07-16 (`ead50b8`) as unmaintained; recover from git history when the v1.0 pipeline resumes

### Active

<!-- This milestone. Hypotheses until shipped. -->

**v5.0 (rpc_api workstream) — see REQUIREMENTS.md for REQ-IDs:**

- [ ] Haskell client re-pinned to the VolOrder V2 (targetVega) ABI — all four byte
      layouts, both selectors, E1 v2 topic0 (+ stale-topic0 fix with pin test)
- [ ] `StochasticOrderGen` generates per-order `targetVega` (raw L units, `[1, 2^96−1]`)
- [ ] Both stochastic drivers run against the `foundry-scripts/deploy/` rig end-to-end

**Earlier active list (plank workstream snapshot, unmodified):**

- [ ] Elevate `spec/protocol/entities/Types.md` into the **authoritative shared kernel** both tracks conform to (types, units, bounds, semantics)
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
- **The shared "file kernel"** is `spec/protocol/entities/Types.md` — the formal type system both tracks reference. The parameter→behavior grounding connects out to the **`cfmm-theory`** knowledge base (local; cited by `KERNEL.md` citekey, no code dependency), whose root **`KERNEL.md`** is the primary upstream reference (extensible to notes like `cfmm-control/ELASTICITY_CONTROL.md`, `cfmm-options/PAYOFF.md`, `cfmm-options/FEE_PREMIUM.md`). The link is **by URL/citekey only** (no submodule/code dependency, because this repo is public); the reference markdown lives under `spec/protocol/refs/`, separate from the existing `refs/` Plank-playground web app.
- **Stochastic model** (`notes/STOCHASTIC_MODEL.md`): swap direction `I_{n,t} ∈ {-1,+1}` (P=½ each), counts `N_t ~ Poisson(λ_t)`, amounts `Δy_{n,t} ~ LogNormal(μ_t, σ²)`, with deterministic proxy `Δy(t) = 19 + 1.0001^{η·t⁴}`. Canonical start state: `(di=20, i=100, i_l=-120, i_u=120, L=1e18, Y=100e18)`.
- **Maturity is early.** Per the codebase map (`.planning/codebase/CONCERNS.md`), most `.plk` files are stubs or have parse/type errors; tests are largely empty shells; the Plank↔GAMS bridge is a zero-line gap (the core deliverable). The repo had no history before this initialization.
- **Reference ecosystem** in `lib/`: bunni-v2 (LDF interface + Geometric reference), Uniswap v3/v4 core, panoptic-v2-core, plankified-univ3 (Plank UniV3 math), plus Unistrata/Shizo/Mochi-Yield/Centrifuge references cited in `notes/STOCHASTIC_MODEL.md`.

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
| Theory grounding links to `cfmm-theory` `KERNEL.md` by URL/citekey (no submodule); refs under `spec/protocol/refs/` | Repo is public — cfmm-theory is local-only, so cite rather than depend | — Pending |
| v3.0 vault pipeline is **H1 only** (`p_risk = oracle/(1−h)`, `h<1` enforced); distance D2 and P0/P2 composition deferred | Smallest proven core first — mirrors how the oracle track grew; the Lean decision table's issuance row backs H1 | ✓ Good — shipped v3.0 in 3 days, 0 arithmetic defects found |
| v3.0 `p_risk` is **exogenous/settable** (validated > 0); RealizedVolatilityMod wiring deferred | tbd.md's own stated assumption; keeps the vault testable in isolation; vol→price conversion depends on pos_spec types that still have red harness tests | ✓ Good — isolation made the e2e differential and battery cheap |
| v3.0 keeps `totalDeposits` / `totalShares` / `riskWeightedShares` as **three distinct state variables** (d ≡ 1 in v1) | Lean `discounted_claim_counterexample` refutes conflating the risk-adjusted subtotal with the accounting total | ✓ Good — read-conflation proved unkillable except by raw vm.load, vindicating the slot discipline |
| Lean lemmas are the v3.0 test oracle (each lemma → a fuzz property vs a Solidity reference mock) | Same differential discipline that proved the vol oracle; the lemmas are machine-checked so the properties are not aspirational | ✓ Good — with one honest carve-out: issuance_haircut_equiv is ℝ-only; integers get the one-sided transfer |

---
*Last updated: 2026-08-16 — started milestone v6.0 (model output store + VolumePath bridge, rpc_api workstream, from issue #25); v5.0 SHIPPED 2026-08-03 as 19a06f3 (PR #9, merged --admin, CI never ran); subgraph (issue #14) renumbered v6.0 → v7.0*
