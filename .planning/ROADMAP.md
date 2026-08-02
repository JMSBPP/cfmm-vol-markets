# Roadmap: CFMM Payoff Replication — Plank ↔ GAMS Connection Layer (v1 Plumbing)

## Overview

This milestone builds the **open-loop plumbing** that carries a parameter set from a (stub) GAMS solver, through a defined encoding contract, into a compiled Plank write/read surface, and back out via a round-trip equality check — all bound to one authoritative kernel. The journey is deliberately ordered plumbing-first: first make the repository public-ready and canonical (Phase 1), then co-locate the GAMS sources and pin the toolchain and kernel both tracks conform to (Phase 2), then write the encoding contract and theory grounding the implementation and bridge both consume (Phase 3), then implement **and compile** the Plank bridge-surface BEFORE wiring it (Phase 4), then stand up the GAMS stub emitter (Phase 5), then wire the runtime bridge with read-back round-trip and selector conformance (Phase 6), and finally run the whole thing end-to-end behind hard guards (Phase 7).

This milestone proves the connection layer *carries parameters correctly* — it does **not** prove payoff replication, run a real optimization model, or assert LDF conformance; those are explicitly v2. This is an early research repo: most `.plk` sources are stubs or have parse/type errors, the Plank↔GAMS bridge is a zero-line gap, and the GAMS solver is intentionally a stub this milestone. The phases below assume nothing about working replication, a real optimization model, or LDF correctness.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Repository Restructure & Sanitize** - Canonical public `wvs-finance` repo, `JMSBPP` fork, and a publish-readiness scrub gating the public flip
- [ ] **Phase 2: Vendoring, Shared Kernel & Toolchain Pin** - GAMS vendored into `model/`, the bridge-path kernel fully specified, the Plank toolchain + submodules pinned with loud FFI guards
- [ ] **Phase 3: Encoding Contract & Theory Grounding** - The per-hop fixed-point encode/decode + ABI/storage-slot contract, plus the parameter→theory reference notes
- [ ] **Phase 4: Plank Bridge-Surface Implementation & Compile** - Implemented and cleanly-compiling Plank write body, struct read, and lens getters for every seeded field
- [ ] **Phase 5: GAMS Plumbing (stub solver)** - GAMS model runs from `model/` and emits the bridge-consumed parameter artifact with a stub objective
- [ ] **Phase 6: Open-Loop Runtime Bridge** - Serialize → encode → write → read-back round-trip equality, plus selector conformance
- [ ] **Phase 7: End-to-End Plumbing Run** - One command runs the full open-loop plumbing path, succeeding only if the FFI guards and round-trip pass

## Phase Details

### Phase 1: Repository Restructure & Sanitize
**Goal**: The project lives in the correct ownership topology — a canonical public `wvs-finance` upstream with a `JMSBPP` fork — and the tree is sanitized so nothing leaks or breaks when it goes public.
**Depends on**: Nothing (first phase). Outward-facing — the public flip and the destructive fork-migration step are confirmed with the user at execution.
**Requirements**: REPO-01, REPO-02, REPO-03, REPO-04, REPO-05
**Success Criteria** (what must be TRUE):
  1. `git grep -InE '/home/[a-z0-9_-]+/'` returns nothing; `refs/`, `node_modules`, and the `Counter` scaffold are absent from tracked files; and `.gitignore` covers `node_modules`/build artifacts (REPO-05).
  2. The public flip and the destructive fork-migration step (retire/rename the existing standalone `JMSBPP` repo) execute only after an explicit user confirmation, following a documented, reversible backup → create-canonical → retire → fork sequence with the destructive step called out (REPO-02, REPO-05).
  3. `git remote -v` shows `upstream` → `wvs-finance/cfmm-replicationPlank` and `origin` → the `JMSBPP` fork, and `wvs-finance/...` is reachable as a public repo that is the canonical upstream (REPO-01, REPO-03).
  4. `README.md` is no longer Foundry boilerplate and describes the Plank/GAMS dual-track plus setup (REPO-04).
  5. The broken CI is fixed or explicitly disabled so a fresh clone does not present a misleading red check at the public flip (REPO-05).
**Plans**: 2 plans

Plans:
- [ ] 01-01-PLAN.md — Local sanitize (remove refs/, Counter, broken CI; scrub home paths; README + MIT LICENSE) and squash to one clean baseline (REPO-04, REPO-05)
- [ ] 01-02-PLAN.md — Gated irreversible migration: push baseline, transfer to wvs-finance, flip public, fork back to JMSBPP, set remotes (REPO-01, REPO-02, REPO-03)

### Phase 2: Vendoring, Shared Kernel & Toolchain Pin
**Goal**: Both tracks are co-located and reproducible — GAMS sources live inside the repo, the bridge-path type kernel is fully and unambiguously specified, and the Plank toolchain plus submodules are pinned with FFI guards that fail loudly.
**Depends on**: Phase 1 (serialized — no Phase 1∥Phase 2 parallelism, to avoid the repo-identity race the review flagged).
**Requirements**: GAMS-01, KERN-01, KERN-02, KERN-03, TOOL-01, TOOL-02
**Success Criteria** (what must be TRUE):
  1. ✓ **DONE (pre-completed)** — GAMS sources are tracked under `model/` and the pipeline references that path; residual `../experiments/gams` text references cleaned in the Phase 1 scrub (GAMS-01). Phase 2 carries only KERN-01..03 + TOOL-01..02 as remaining work.
  2. The FFI build asserts `plank --version` matches a pinned `.plank-version` (with the `sona` codegen backend declared) and fails loudly on mismatch; the deployer/`plankified-univ3` submodules are pinned to specific commits; and the deploy path asserts returned bytecode length > 0 and deployed address ≠ 0 (TOOL-01, TOOL-02).
  3. Every type on the enumerated bridge path — `VolatilityTermStructure` and its fields, plus the `NumberFormat`/`BoundedValue` they use — carries number format, bounds, and unit semantics with no placeholder bounds (the `baseTick` bound resolved to a concrete int24 range) (KERN-01).
  4. A concrete conformance mechanism (a generated shared constants file both sides include, or a checked field-by-field cross-reference) binds the Plank type and the GAMS symbols to one kernel definition — not prose alone (KERN-02).
  5. The kernel states the canonical fixed-point conventions (WAD `1e18`, Q64.96) using one canonical name for the Q64.96 format consistently (`Q64x96`/`Q64.96`/`Q96_ONE` reconciled) (KERN-03).
**Plans**: TBD

Plans:
- [ ] 02-01: TBD

### Phase 3: Encoding Contract & Theory Grounding
**Goal**: The single source of truth for how every parameter crosses the boundary exists — a per-hop fixed-point encode/decode chain plus the ABI/storage-layout contract — and each mapped parameter is grounded to its theory note. This spec is consumed by both the Plank implementation (Phase 4) and the bridge (Phase 6).
**Depends on**: Phase 2 (kernel + fixed-point conventions).
**Requirements**: MAP-01, MAP-02, MAP-03, MAP-04, MAP-05, MAP-06, REF-01, REF-02
**Success Criteria** (what must be TRUE):
  1. A GAMS↔Plank mapping table covers at least `xi`↔`priceElasticity`/LDF `alpha`, `iota`↔`statePartitionDelta`/`tickSpacing`, and `baseTick`, each with an explicit mapping direction (MAP-01).
  2. Each parameter has a documented per-hop encode/decode chain with scale base and rounding mode for every quantizing hop, and the `priceElasticity` upper bound is corrected so the type covers the full valid `alpha` range (resolving `Q96_ONE` < `MAX_ALPHA`) (MAP-02).
  3. Signed `baseTick` encoding is specified (int24 two's-complement sign-extended to `u256`, rounded to a `tickSpacing` multiple, within resolved int24 bounds) and a `tickSpacing` divisibility invariant for `tickLower`/`tickUpper` is enforced (MAP-03, MAP-04).
  4. The `initVolTermStructure` ABI + storage-layout contract is specified (signature string, ABI arg layout, on-storage bit-packing) with selector `0xd9c112ef` verified to equal `keccak(signature)[:4]`, and the write slot and simulator read slots are reconciled into declared slots with no undefined `SLOT_TICK_*` (MAP-05, MAP-06).
  5. Each mapped parameter has a reference markdown under `spec/refs/` citing its `cfmm-theory` grounding note (primary `KERNEL.md`) by URL/citekey with no code dependency on the theory tree, annotated with the behavioral theorem/assumption/regime it encodes (REF-01, REF-02).
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

### Phase 4: Plank Bridge-Surface Implementation & Compile
**Goal**: The actual Plank write body, struct read, and lens getters are implemented per the Phase 3 contract AND compile cleanly via the pinned FFI build — delivered BEFORE the bridge wiring so the wiring has a real surface to call. This fixes the prior phase-order inversion BLOCKER.
**Depends on**: Phase 3 (the layout/encoding/slot contract).
**Requirements**: PLNK-01, PLNK-02, PLNK-03, PLNK-04
**Success Criteria** (what must be TRUE):
  1. `src/types/VolatilityTermStructure.plk` has a working `read` that decodes the stored struct per the MAP-05 layout (PLNK-01).
  2. `IMarketDynamics.initVolTermStructure` has an implemented body that decodes calldata and stores into the reconciled MAP-05/MAP-06 slot — not just a selector constant (PLNK-02).
  3. `IMarketDynamicsLens` getters `getPriceElasticity`, `getStatePartitionDelta`, and `getBaseTick` are implemented, providing a read-back view for every seeded field (PLNK-03).
  4. All Plank sources on the bridge/pipeline path compile cleanly via the pinned FFI build — the parse/type stubs (`SELECTOR_… =;`, untyped fields, `uint256` vs `u256`, the `u265` typo) blocking the path are fixed (PLNK-04).
**Plans**: TBD

Plans:
- [ ] 04-01: TBD

### Phase 5: GAMS Plumbing (stub solver)
**Goal**: The GAMS side produces the artifact the bridge consumes, running from the vendored location with a stub objective — enough to feed the pipe, no real optimization.
**Depends on**: Phase 2 (vendored sources), Phase 3 (knows the output shape/encoding to emit).
**Requirements**: GAMS-02
**Success Criteria** (what must be TRUE):
  1. The GAMS model runs from `model/` and exits successfully using a stub/placeholder objective (a trivial or fixed map is acceptable this milestone) (GAMS-02).
  2. The run emits the parameter-output artifact in the shape/encoding the Phase 3 contract defines for the bridge to consume (GAMS-02).
  3. The stub objective is clearly marked as such; no real optimization model is present, and the real model remains a v2 (`PAY-01`) deferral (GAMS-02).
**Plans**: TBD

Plans:
- [ ] 05-01: TBD

### Phase 6: Open-Loop Runtime Bridge
**Goal**: The connection layer is wired — GAMS output is serialized, encoded per contract, written to the compiled Plank surface, and read back with a round-trip equality and selector-conformance check. This is the open-loop bridge: no in-loop parameter updates.
**Depends on**: Phase 3 (encoding contract), Phase 4 (compiled Plank write/read surface), Phase 5 (GAMS output to serialize).
**Requirements**: BRDG-01, BRDG-02, BRDG-03, BRDG-04
**Success Criteria** (what must be TRUE):
  1. GAMS output is serialized to a defined exchange format (e.g., JSON or ABI-encoded calldata) that the Plank side consumes (BRDG-01).
  2. A bridge step encodes the parameters per the MAP-02 contract and writes them via `IMarketDynamics.initVolTermStructure()` (selector `0xd9c112ef`) (BRDG-02).
  3. The seeded parameters are read back through the lens views and a round-trip equality holds — `decode(readback) ≈ original` within the stated quantization tolerance — for every seeded field (BRDG-03).
  4. A selector-conformance test asserts each Plank selector constant on the path equals `keccak(documented signature)[:4]` (BRDG-04).
**Plans**: TBD

Plans:
- [ ] 06-01: TBD

### Phase 7: End-to-End Plumbing Run
**Goal**: A single command runs the full open-loop plumbing path end-to-end and is honest about success — it passes only if the guards and round-trip pass, and the simulate step does no closed-loop updates.
**Depends on**: Phase 6.
**Requirements**: PIPE-01, PIPE-02
**Success Criteria** (what must be TRUE):
  1. One command runs payoff spec → (stub) GAMS solve → encode → Plank write → read-back, end-to-end (PIPE-01).
  2. That command exits success only if the TOOL-02 FFI guards (bytecode length > 0, address ≠ 0) and the BRDG-03 round-trip pass, and exits non-zero (fails loudly) otherwise (PIPE-01).
  3. An open-loop guard asserts the swap-replay/simulate step performs no in-loop parameter updates, keeping the closed-loop controller out of this milestone (PIPE-02).
**Plans**: TBD

Plans:
- [ ] 07-01: TBD

## Progress

**Execution Order:**
Phases execute strictly in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7. No Phase 1∥Phase 2 parallelism (repo-identity race).

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Repository Restructure & Sanitize | 0/TBD | Not started | - |
| 2. Vendoring, Shared Kernel & Toolchain Pin | 0/TBD | Not started | - |
| 3. Encoding Contract & Theory Grounding | 0/TBD | Not started | - |
| 4. Plank Bridge-Surface Implementation & Compile | 0/TBD | Not started | - |
| 5. GAMS Plumbing (stub solver) | 0/TBD | Not started | - |
| 6. Open-Loop Runtime Bridge | 0/TBD | Not started | - |
| 7. End-to-End Plumbing Run | 0/TBD | Not started | - |

## Coverage

All 30 v1 requirements in REQUIREMENTS.md are mapped to exactly one phase:

| Phase | Requirements | Count |
|-------|--------------|-------|
| 1 | REPO-01, REPO-02, REPO-03, REPO-04, REPO-05 | 5 |
| 2 | GAMS-01, KERN-01, KERN-02, KERN-03, TOOL-01, TOOL-02 | 6 |
| 3 | MAP-01, MAP-02, MAP-03, MAP-04, MAP-05, MAP-06, REF-01, REF-02 | 8 | 5/5 | Complete    | 2026-07-19 | 4 |
| 5 | GAMS-02 | 1 |
| 6 | BRDG-01, BRDG-02, BRDG-03, BRDG-04 | 4 |
| 7 | PIPE-01, PIPE-02 | 2 |

**Total mapped: 30/30** — no orphans, no duplicates.

## Scope Boundary

This is **open-loop plumbing only**. Explicitly out of this milestone (v2):
- Correct payoff **replication** proof, replication-error metric + tolerance (`PROOF-*`)
- Real GAMS optimization model — Phase 5 is a **stub objective** (`PAY-01`)
- LDF conformance / `SwapAmtGen` overflow fix (`LDF-*`)
- Closed-loop adaptive controller + V4 `beforeSwap` hook (`CTRL-*`) — Phase 7's PIPE-02 guard actively keeps in-loop updates out
- Production / mainnet deployment, multiple-payoff library (`PLIB-01`), formal literature review (`RIG-01`), secure on-chain randomness (`RIG-02`)

## Deferred Review Findings (do NOT block roadmap; resolve during phase planning)

The two-step review confirmed all original BLOCKERs/MAJORs resolved. The following finer findings were surfaced on the revised roadmap and are **deferred to phase planning** (by user direction — not blocking initialization):

- **Selector `0xd9c112ef` is likely wrong** (Phase 3 / MAP-05, Phase 6 / BRDG-02): no plausible `initVolTermStructure` signature reproduces it. At Phase 3, treat the kernel-derived **signature string as authoritative**, recompute the selector, and correct the constant; reference all path selectors symbolically. Extend the signature pinning to the lens getters (BRDG-04).
- **Single quantization boundary** (Phase 3 / MAP-02, Phase 5 / GAMS-02, Phase 6 / BRDG-01): decide one place that does fixed-point encoding — recommended: **GAMS emits raw decimals, the bridge owns all encoding** — and define the off-chain exchange format in Phase 3 so Phase 5 emits against it.
- **Round-trip should be exact** (Phase 6 / BRDG-03): with the replication metric descoped to v2, require **exact equality on the stored integer** for `{priceElasticity, statePartitionDelta, baseTick}` via the lens (hop-1 only); drop the `≈`/tolerance language and the `/LDF` read-back (LDF is a v2 stub).
- **REPO-05 verification** (Phase 1): scan tracked file **contents** (`git grep -InE '/home/[a-z0-9_-]+/'`), not filenames; relativize/URL-ify the local home-absolute paths in `.planning/` docs; vendor GAMS (GAMS-01) before the public flip so no `../experiments/gams` path remains.
- **PIPE-02** (Phase 7): the v1 e2e path has no simulate-update step — phrase the open-loop guard as a **structural** assertion (no controller/update code on the path), not a runtime guard on a non-existent step.
- **Minor:** pin the concrete scale base for `alpha`/`priceElasticity` (MAP-02); add Phase 4 `Depends on: Phase 2`; define the PIPE-01 "payoff spec" as a fixed v1 input fixture; for KERN-02 prefer the checked field-by-field cross-reference (GAMS `$include` and Plank `import` can't share one file).

### Phase 8: panoptic vol-claim lean4 formalization

**Goal:** Formalize `spec/panoptic.md` in the `lean/` Lake project: the contract as a volatility option (payoff π^σ = ΔQ_v·(σ²(i(t)) − σ²_K)⁺), the vol-claim price as an option-replication cost (Demeterfi et al. variance-swap decomposition + Panoptic streaming-premium θ kernel), and identification of the vega-like greek υ ≡ Δπ/Δσ² in its analytical/contract-level form (econometric identification via the Panoptic subgraph is scoped during discussion). Owned by the Lean4+math session (worktree `lean4-spec`, branch `feat/lean4-spec`).
**Requirements**: no formal REQ-IDs — the locked decisions in `08-CONTEXT.md` are the requirements (CTX-HYGIENE, CTX-VENDOR, CTX-PAYOFF, CTX-REPLIC, CTX-PREMIUM, CTX-CRR-THETA, CTX-UPSILON, CTX-CONJ, CTX-ECONO, CTX-THETA-PROOF)
**Depends on:** Phase 1 only (Lean4 track — builds on the conglomerated `lean/` Lake project, independent of Phases 2–7 owned by other sessions)
**Plans:** 5/5 plans complete

Plans:
- [ ] 08-01-PLAN.md — Spec hygiene (fix θ sign, Demeterfi citekey, de-path NOTE) + vendor cfmm-discrete notes; commit the pinned spec [Wave 1]
- [ ] 08-02-PLAN.md — Panoptic.lean: π^σ payoff + ΔQ_v identity + structural replication + premium Finset.sum + CRR operator + lattice θ (center column) + sorry'd θ_ATM theorem [Wave 2]
- [ ] 08-03-PLAN.md — Econometric υ-identification model spec via the structural-econometrics skill (markdown; not Lean) [Wave 2]
- [ ] 08-04-PLAN.md — Upsilon.lean: υ finite-difference + ΔQ_v dimensional bridge + ATM/OTM Prop conjecture [Wave 3]
- [ ] 08-05-PLAN.md — Aristotle stage: strictly-serial NEW-project θ_ATM = kσ/√(8πτ) derivation, integrate proof, verify sorry-free + axiom-clean [Wave 4]

### Phase 9: upsilon econometric estimation lean-aware

**Goal:** Execute the approved υ-identification econometric spec (`notes/structural-econometrcics/specs/2026-07-19-panoptic-upsilon-identification.md`) **in conjunction with the Lean formalization**: build the position-epoch panel from Panoptic on-chain data (premium π_it, variance estimator σ̂²_t, moneyness |i_K − i_t|), run the NLS/GMM estimation with the committed tests (υ₀ > 0, κ > 0, κ⁺ = κ⁻) and the four scheduled alternative specifications — with Lean-awareness made literal: the estimated objects mirror the Lean definitions (`Upsilon.upsilon` finite difference, `Upsilon.ATMOTMNullHypothesis`), including a bridging lemma that the exponential-moneyness family with κ > 0 satisfies `ATMOTMNullHypothesis` (so κ̂ > 0 ⇒ the fitted profile witnesses the Lean conjecture). Owned by the Lean4+math session (worktree `lean4-spec`, branch `feat/lean4-spec`).
**Requirements**: CTX-PANEL, CTX-VAR, CTX-EST, CTX-TEST, CTX-ALT, CTX-BRIDGE, CTX-XCHECK, CTX-AUDIT (CTX-* tags minted at planning, per the Phase-8 convention)
**Depends on:** Phase 8 (Lean modules + approved econometric spec); independent of Phases 2–7 (other sessions)
**Plans:** 11 plans in 6 waves

Plans:
- [ ] 09-01-PLAN.md — Haskell `econometrics/` Stack scaffold (hmatrix + hmatrix-gsl) + hspec harness + sandwich-SE golden fixture (CTX-EST) [Wave 1]
- [ ] 09-02-PLAN.md — Data-source discovery gate: mainnet/L2 subgraph endpoint + BigQuery + Swap topic0 [checkpoint] (CTX-PANEL, CTX-VAR) [Wave 1]
- [ ] 09-03-PLAN.md — Lean: correct `ATMOTMNullHypothesis` conjunct 3 (slope-centered) + state sorry'd bridging lemma (CTX-BRIDGE) [Wave 1]
- [ ] 09-04-PLAN.md — CTX-PANEL: subgraph client + cumulative→delta position-epoch panel (λ=1.0001 grid) [Wave 2]
- [x] 09-05-PLAN.md — CTX-VAR: σ̂²_t + disjoint-window EIV instrument from Base V4 eth_getLogs RPC swap ticks (BigQuery dropped) [Wave 2]
- [ ] 09-06-PLAN.md — CTX-BRIDGE: single serial Aristotle proof of the bridging lemma, integrate sorry-free/axiom-clean [Wave 2]
- [ ] 09-07-PLAN.md — CTX-EST: Lean-mirrored model + GSL-LM primary NLS (+ ad cross-check) + EIV IV/GMM [Wave 3]
- [ ] 09-08-PLAN.md — CTX-EST/CTX-TEST: hand-rolled cluster-robust sandwich SE (golden 1e-9) + υ₀>0, κ>0, κ⁺=κ⁻ tests [Wave 4]
- [ ] 09-09-PLAN.md — CTX-ALT: four alternative specs + live estimation run → self-describing analysis output + witness [Wave 5]
- [ ] 09-10-PLAN.md — CTX-XCHECK: GAMS point-estimate cross-check handoff via claude-peers [checkpoint, non-blocking] [Wave 6]
- [ ] 09-11-PLAN.md — CTX-AUDIT: audit-econ gate (3 agents) on the analysis output; fix Critical/High → PASS [checkpoint] [Wave 6]

### Phase 10: streaming premium reconstruction and reestimation

**Goal:** Fix the measurement failure that made Phase 9's estimate uninformative. Reconstruct the per-position, per-epoch **streaming premium π_it** accrued inside each position's tick range, replacing the subgraph's absent/zero `premiaSettled*` fields. **ROUTE AMENDED 2026-07-20:** the original full-V4-replay-from-cached-swap-logs route is **WITHDRAWN** — `swap-ticks-base-v4-full.csv` is a two-column `timestamp_unix,tick` file carrying no fee amount, no liquidity and no block number, and exact replay from events alone is impossible because `feeGrowthGlobal` updates per swap *step* with a step-varying liquidity divisor that the `Swap` event does not expose. The approved route reads the exact per-liquidity premium accumulator (X64, utilization multiplier ν = 1/VEGOID = 1/8 included) from the deployed `SemiFungiblePositionManagerV4.getAccountPremium` via archive `eth_call`s on the keyless Base endpoint — evaluating the identity inside the contract that defines it. Full replay survives only as an optional, non-blocking cross-check. This restores the approved spec's **position-epoch panel** (≈55 positions × ~119 epochs vs. 61 lifetime spells) and its within-position variation, then re-runs the unchanged Phase-9 estimator (GSL-LM NLS, tokenId-clustered CR0 sandwich SEs, the three committed tests, the four alternatives incl. the now-identifiable position-FE diagnostic). Success is an **informative** estimate — a υ₀ confidence interval materially tighter than Phase 9's [−2.48e-4, +2.48e-4] — whether or not κ̂ > 0 obtains; if it does, the fitted profile witnesses the proved `Upsilon.exp_family_witnesses_ATMOTM`. Owned by the Lean4+math session (`lean4-spec`, `feat/lean4-spec`).
**Requirements**: CTX-SIZE (width!=0 panel-size blocker), CTX-FEE (chain layer: ABI, RPC, feeGrowthInside, block index), CTX-PREM (SFPM getAccountPremium read + premium identity), CTX-GATE (hard reconciliation gate: median rel. error <=1% on OptionBurn.premium0 in ETH wei, stratified short/long), CTX-PANEL2 (restored position-epoch panel), CTX-EST2 (re-estimation under the pre-committed, result-independent stopping rule), CTX-XWALK (Lean/Haskell cross-walk multiplier wedge), CTX-REPLAY-OPT (optional, non-blocking replay cross-check)
**Depends on:** Phase 9 (estimator, inference, Lean witness, cached swap logs — all reused unchanged; only the LHS construction changes)
**Phase outcome (2026-07-27, FINAL):** Wave-0 census **GO** (hourly re-scope; daily grid returned STOP and it was honoured). Reconciliation gate **PASS** — 61/61 spells, short-stratum median relative error 0.000000 in ETH wei, 53/61 exact to the wei, worst 5.447268e-4 against a tolerance of 0.01 that was never modified. Stopping rule **UNINFORMATIVE**, under BOTH LHS constructions (υ₀ CI half-widths 1.479533e-1 and 1.979569e-1 against the never-moved 6.2e-5 bar): **this market cannot identify υ.** The phase's own success criterion is therefore NOT met, and that is the reported result — no respecification, no subsample hunting, no estimator fishing. Genuinely new and reported without over-reading: **κ̂ > 0 rejects H₀ of a flat vega profile under both constructions** (p = 9.534719e-3 and 7.308348e-3), the first rejection in this project — a statement about the profile's SHAPE, not a substitute for the rule, which is about υ₀'s LEVEL. The **formal witness does NOT obtain** (`hk` supported, `hu` sign-only); `Upsilon.exp_family_witnesses_ATMOTM` stays proved and axiom-clean and `ATMOTMNullHypothesis` stays OPEN. The binding constraint is the **55-cluster ceiling**, which no LHS transformation can touch.
**Plans:** 11/12 plans complete

Plans:
- [x] 10-01-PLAN.md — CTX-SIZE: width!=0 census, achievable panel size, STOP/GO checkpoint (WAVE-0 BLOCKER)
- [x] 10-02-PLAN.md — CTX-FEE: Chain.Abi + Chain.Rpc, frozen golden eth_call returndata fixture
- [x] 10-03-PLAN.md — CTX-FEE/PANEL2: Chain.BlockIndex, epoch->block map, RPC throughput probe
- [x] 10-04-PLAN.md — CTX-PANEL2: Panoptic.Chunk getTicks/liquidity, deduplicated read schedule
- [x] 10-05-PLAN.md — CTX-PREM/GATE: Panoptic.Sfpm + Panoptic.Premium, X64 scaling, telescoping
- [x] 10-06-PLAN.md — CTX-PREM: checkpointed, resumable bulk accumulator read (~8k-15k eth_calls)
- [x] 10-07-PLAN.md — CTX-GATE: Panel.Reconcile + 5-spell pre-check
- [x] 10-08-PLAN.md — CTX-GATE: the hard 61-spell stratified gate + verdict checkpoint
- [x] 10-09-PLAN.md — CTX-PANEL2: position-epoch panel + zero-unmatched variance join
- [x] 10-10-PLAN.md — CTX-EST2: re-estimation (estimator UNCHANGED) + stopping-rule checkpoint — **TERMINAL: STOPPING_RULE UNINFORMATIVE under BOTH LHS constructions; this market cannot identify υ. κ>0 rejects in both (p 9.5e-3, 7.3e-3); Lean witness does NOT obtain.**
- [x] 10-11-PLAN.md — CTX-XWALK: multiplier-wedge cross-walk, ROADMAP/STATE close-out — wedge recorded as a MEASURED distribution (median 1.112500, p90 1.291667, 38.9% exactly 1, max R/N 2.333333), the quoted 1.125 bound corrected, witness status and the seller-side sign convention recorded
- [ ] 10-12-PLAN.md — CTX-REPLAY-OPT (OPTIONAL, NON-BLOCKING): _getPremiaDeltas cross-check — **SKIPPED 2026-07-27.** Reason: its purpose is an independent check that the reconstructed premium really is the protocol's, and that purpose is already served — the 10-08 gate reconciles all 61 spells against `OptionBurn.premium0` in exact Integer ETH wei with 53/61 exact to the wei, and two independent anti-fabrication reviewers returned CLEAN (live re-read against the Base archive, 32/32 integers exact; full offline recomputation in Python, no planted literals). A narrow-window replay would re-derive a quantity already validated wei-exactly against on-chain ground truth. The plan was optional and non-blocking by construction and nothing downstream depends on it. **CTX-REPLAY-OPT is therefore NOT satisfied and is not claimed to be.** The user may request the run later; the plan file stays in place, unexecuted.

### Phase 11: MEV hazard-rate metric and infimum program (λ_MEV)

**Goal:** Define a discrete λ_MEV hazard functional analogous to
`FlairOptimization.flairHazard` — anchored on Milionis–Moallemi–Roughgarden
*Arbitrage Profits in the Presence of Fees* (fee-DEcreasing arb-profit
rate; PDFs acquired in `../plank/refs/mev/`) — over the SAME multi-sigmoid
parameter space `Θ_φ = {γ, φ̄, β, α(, α_R)}` of `VolInstrument.multiFee`;
identify `Θ_{λ_MEV} ⊂ Θ_φ` and SOLVE the infimum program `inf λ_MEV`
(mirror of the solved `sup λ_FLAIR`; the level block `{φ̄, α, u}` has
OPPOSITE monotonicity — fees up ⟹ FLAIR up, MEV down); then state the
joint sup-FLAIR/inf-MEV program. The original intent is recorded and
CORRECTED: it read "where the shape block `(β, γ)` becomes essential",
and that expectation is **REFUTED, machine-checked** — the unconstrained
joint program is DEGENERATE (`joint_corner_degeneracy`,
`joint_beta_degeneracy`, `joint_scalarization_degeneracy`), so there is no
trade-off over `Θ_φ` and the shape block is NOT essential. The trade-off
appears only under a FIXED FLAIR fee budget, and even there only at
constant volatility (see the plan-11-05 verdict below).
Formalization is doc-driven via Aristotle
(`VOLATILITY_INSTRUMENTS.md ### MEV` is the reference note; notation
binding per LEAN_TRACEABILITY). Angstrom (SorellaLabs/angstrom,
angstrom-v4, l2-angstrom) is the implementation reference that minimizes
λ_MEV mechanically — its auction mechanism informs which parameters are
protocol-controllable.
**Requirements**: CTX-MEVDOC (λ_MEV LaTeX spec into `VOLATILITY_INSTRUMENTS.md ### MEV`,
user-approved), CTX-PTRADE (the fee-decreasing kernel `ptrade` + the MMR ARB/FEE/LVR split),
CTX-MEVHAZ (`mevHazard`/`mevMulti` discrete functionals + the CPMM instantiation), CTX-INF
(`Θ_{λ_MEV}` identification + the SOLVED infimum program), CTX-JOINT (the joint program:
degeneracy + the constrained/Jensen reformulation), CTX-ANGSTROM (τ-rebate argmin invariance,
the `Δt` cadence lever, sandwich nulling), CTX-TRACE (LEAN_TRACEABILITY rows + close-out),
CTX-REVIEW (two-reviewer gate on every pre-submission spec artifact)
**Depends on:** Phase 10 (and the FlairOptimization.lean layer, commits 6914fba/5e08578)
**Directory:** `.planning/phases/11-mev-hazard-inf-program/`
**Plans:** 6/6 plans complete
**Phase outcome (2026-07-31, FINAL):** All eight CTX-* requirements SATISFIED, and the two headline
results are both NEGATIVE ones, reported as results rather than softened. **(1) The unconstrained
joint program is DEGENERATE** — one admissible point simultaneously maximizes `λ_FLAIR` and
minimizes `λ_ARB`, in the levels and in the shape coordinate, robustly to every scalarization
`κ ≥ 0`; the phase brief's "the shape block becomes essential" expectation is machine-checked as
refuted. **(2) T24 — the σ-varying flat-fee optimality claim, the phase's declared main mathematical
risk — is REFUTED, not open**: `mev_ge_flat_under_flair_budget_false`, witness recomputed in exact
rationals (flat `31/22` vs tilted `4/3`). The `Θ_φ`-restricted isotone case remains OPEN and is not
claimed either way. What is positively proved: `ptrade` with all seven M1 properties (both strict
forms strict), the `mevHazard`/`mevMulti` functionals commensurable with FLAIR by construction, the
SOLVED infimum program `Θ_{λ_ARB} = {φ̄, α, u}` at its upper corner, the constant-σ path-level
constrained result, and the whole Angstrom bridge (`τ` and `Δt` formally outside `Θ_φ`;
`mevTotal := λ_ARB + λ_sandwich` as plain hazard addition). Two disclosed corrections
(T15's `hfee` guard, T17's admissibility constraint — both at `ptrade`'s negative-fee pole) and one
omission (T19: block M3(ii)'s exact CPMM kernel has no formal carrier, so the `σ²Δt < 8` guard lives
nowhere). `arb_add_fee_eq_lvr` is a bridge identity, NOT a formalization of MMR Theorem 3/4.

> **Planning correction (2026-07-30, from 11-RESEARCH.md F5; CONFIRMED MACHINE-CHECKED 2026-07-31):**
> the goal above anticipated that in the joint program "the shape block `(β, γ)` becomes essential".
> This is **refuted for the unconstrained functional** — `ptrade` is antitone in the fee, so
> `inf λ_MEV` and `sup λ_FLAIR` sit at the SAME point in every coordinate of `Θ_φ` (level corner top
> and `β → −∞`), robustly to linear scalarization. Research asserted it; `MevJointProgram.lean`
> (11-05) now proves it. The trade-off is recovered only under a FIXED FLAIR fee budget, where
> convexity of `ptrade` makes a flat fee the MEV minimizer — **and 11-05 further narrowed that
> recovery**: it holds at CONSTANT volatility over fee PATHS, while the general σ-VARYING
> schedule-level version is FALSE. The phase ships all three claims separately; the degeneracy and
> the refutation are reportable results, not failures.

Plans:
- [x] 11-01-PLAN.md — CTX-MEVDOC/CTX-REVIEW: λ_MEV doc spec (LaTeX blocks M0–M8), notation gate, two-reviewer gate, HEAVY USER APPROVAL — **COMPLETE** (4 BLOCKERs + 12 MAJORs resolved; user-approved; blocks landed in plank's `### MEV`, bytes pinned by `APPROVED-DOC-SHA256`; M6a REFUTES the "(β,γ) becomes essential" expectation)
- [x] 11-02-PLAN.md — CTX-PTRADE/CTX-MEVHAZ/CTX-INF/CTX-REVIEW: Aristotle bundle A + numbered T1–T19 prompt, prompt gate, serial submit — **COMPLETE, TASK IN FLIGHT** (project `cb371ee5`, task `d1c57297`, `IN_PROGRESS` at close; bundled doc PROVED byte-identical to the approved text by sha256 pin + M-block diff; prompt gate found 2 BLOCKERs — a dropped `·Δt` re-introducing 11-01's own defect, and a provably false T17 — plus 3 MAJORs, all resolved; queue proven empty, exactly one task in flight). CTX-PTRADE/MEVHAZ/INF are NOT yet satisfied: nothing is proven until 11-03 integrates the returned module
- [x] 11-03-PLAN.md — CTX-PTRADE/CTX-MEVHAZ/CTX-INF: integrate bundle A — build, axiom sweep, T1–T19 fidelity diff, push both remotes — **COMPLETE. CTX-PTRADE, CTX-MEVHAZ and CTX-INF are now SATISFIED** (`lean/vol_markets/MevOptimization.lean`, 1046 lines, 25 declarations, sorry-free, 25/25 axiom-clean, `lake build` green, pushed to origin `42c8e60` + `cfmm-lean4-spec` `19afcdd`). All ten bundled dependency modules returned byte-identical; T1–T18 all present with NONE narrowed (T6 strict, T13 a path SUM, T8 kept `·Δt`, T17 proves `ContinuousOn`). Two recorded qualifications: T15 needed an Aristotle-ADDED hypothesis because the limit as specified was FALSE at `ptrade`'s negative-fee pole, and optional **T19 was OMITTED** so block M3(ii)'s exact CPMM kernel has no formal carrier. Queue FREE ⟹ 11-04 unblocked
- [x] 11-04-PLAN.md — CTX-JOINT/CTX-ANGSTROM/CTX-REVIEW: bundle B + T20–T30 prompt (degeneracy, constrained/Jensen with σ-varying primary and σ-constant fallback, Angstrom bridge), gate, serial submit — **COMPLETE, TASK IN FLIGHT AT CLOSE** (project `19f777ab`, task `f8840dab`). The two-reviewer gate earned its keep: both reviewers independently found the SAME BLOCKER — the plan's own text specified `mevTotal := probOr lamARB lamSand`, which approved block M7 explicitly forbids, and which the project's already-proven `VolInstrument.probOr_hazard` refutes; corrected to plain addition with the correspondence kept as its own lemma. Executor-found before either reviewer ran: the plan's T25 was a TRIVIALITY at the schedule level, fixed by introducing path-level carriers. Doc fidelity re-proved against all three copies at submit time. CTX-JOINT/CTX-ANGSTROM NOT yet satisfied at close: nothing proven until 11-05 integrates
- [x] 11-05-PLAN.md — CTX-JOINT/CTX-ANGSTROM: integrate bundle B — build, axiom sweep, T20–T30 fidelity, the explicit T24 verdict, push — **COMPLETE. CTX-JOINT and CTX-ANGSTROM are now SATISFIED** (`lean/vol_markets/MevJointProgram.lean`, 481 lines, 27 declarations, sorry-free, 27/27 axiom-clean, `lake build` 8063 jobs green, pushed to origin `94e7fa9` + `cfmm-lean4-spec` `81b2729`). 11/11 bundled modules byte-identical; T20–T30 ALL byte-identical to the sha-verified prompt, none narrowed, ZERO corrective hypotheses. **THE T24 VERDICT IS REFUTED** — `mev_ge_flat_under_flair_budget_false`, Aristotle's outcome 3, flat `31/22` vs tilted `4/3` recomputed independently in exact rationals. The `Θ_φ`-restricted varying-σ case is recorded OPEN; the supporting numerics are labelled NOT machine-checked. The unconstrained degeneracy (T20–T22) is machine-checked
- [x] 11-06-PLAN.md — CTX-TRACE: LEAN_TRACEABILITY §0/§6/§7 rows, addendum back-annotation, ROADMAP/STATE close-out — **COMPLETE. CTX-TRACE SATISFIED.** §0 carries the MEV notation rows, the three resolved collisions and the λ_ARB/λ_MEV distinction; new §7.1 carries 14 claim rows, every backticked identifier grep-verified to be a real declaration in one of the two modules; `arb_add_fee_eq_lvr` is labelled a bridge identity and explicitly NOT a formalization of MMR Theorem 3/4; the degeneracy and the T24 refutation are recorded as RESULTS with `REFUTED`/`OPEN` statuses taken verbatim from the fidelity records; §6's stale "MEV section (empty in the doc)" clause is replaced by five precisely named gaps. Addendum back-annotated M1–M7 with M6b amended OPEN → REFUTED; the plank-owned `VOLATILITY_INSTRUMENTS.md` carries the same amendment, uncommitted, handed to `ul2inqpl`

### Phase 12: Optimal η for the FLAIR/MEV trade-off (interior curvature controller)

**Goal:** Derive and formalize the optimal `η` — the pricing-geometry
curvature / asset-demand substitution elasticity (`VolInstrument.priceEta`,
plank todo #227) — as the unique interior controller of the FLAIR/MEV
trade-off. Transcribe Capponi–Jia §5.1 (arXiv:2103.08842; PDF at
`../plank/refs/mev/CapponiJiaAdoptionDEX.pdf`) into the doc's geometry
under the binding notation-precedence rule (their curvature `k` maps ONTO
our `η`; our symbols never reassigned): the curvature family, the two-sided
lemma (arb-loss ratio ↓ curvature AND investor-surplus ratio ↓ curvature),
and the interior-optimum proposition (LP payoff single-peaked at `k*` —
our `η*`). Then state and solve the JOINT program over `(Θ_φ, η)`: the fee
block stays at its proven corner (Phase 11 M6a degeneracy), and `η` carries
the genuine interior trade-off — `λ_ARB` decreasing in `η` through the
slippage channel while the demand/volume side decreases too, yielding
`η* ∈ (0, 1)`-analog existence + first-order characterization where
provable, with honest OPEN labels where the doc's discrete geometry departs
from Capponi's continuum model. Doc-driven Aristotle (new doc block, HEAVY
USER APPROVAL, notation gate); results land beside the Phase 11 modules;
traceability + doc summarization close the cycle.

> **PLANNING CORRECTIONS (2026-07-31, from 12-RESEARCH's reading of the v4 PDF — the
> goal above is kept verbatim; these correct it in place rather than replacing it).**
> **(1) THERE IS NO FIRST-ORDER CHARACTERIZATION, and none may be requested.** `k*` is the
> BRANCH POINT `k₁ = 1 − √((1+f)/(1+α))`, where the investor's trade switches from draining
> the pool to an interior marginal condition. It is a KINK; the derivative jumps there and is
> not zero. `η*` is obtained by INVERTING a closed form, giving
> `η* = ln((1+ϱ_I)/(1+φ)) / (Δi²·ln λ)` — existence AND location in one step, no optimisation
> argument. A prompt asking for a stationary point would return a false or vacuous theorem.
> **(2) The anchor's results are Lemma 3, Proposition 5 and Proposition 6** — not "Lemma 1"
> and not "the curvature proposition". Lemma 1 is the unrelated one-token-shock arbitrage-profit
> result. **(3) Capponi's `α` and `β` are NOT arrival probabilities** (as 12-CONTEXT.md states):
> `α` is the investor's PRIVATE-USE PREMIUM and `β` the price-shock MAGNITUDE. This is
> load-bearing — `α` is the demand-side valuation parameter that `MevJointProgram`'s degeneracy
> docstring and `LEAN_TRACEABILITY` §6(b) both name as the missing layer, so this phase fills a
> gap the project had already identified. **(4) The mapping `k ↔ η` is not direct:** the bridge
> is the discrete curvature index `χ(η) = 1 − λ^(−Δi²η/2)`, a strictly monotone bijection
> `(0,∞) → (0,1)`, and Capponi's economics is transcribed over `χ` with every equilibrium
> aggregate frozen into a constant. **(5) The interior-optimum claim is not a first for the
> repository:** `lean/exp/DynamicsOptimization.lean` already carries an interior-`η` result in a
> DIFFERENT model, but it HYPOTHESIZES the maximizer and characterizes it by an FOC. What is new
> here is the CONSTRUCTION. **(6) `η = 1` is the standard sqrt-price grid, NOT Capponi's `k = 1`.**
> **(7) The equilibrium transfer — that our tick-grid AMM actually has Capponi's closed forms — is
> an ASSUMPTION and is labelled OPEN, not derived.**

> **BINDING USER DECISIONS FROM 12-01 (2026-07-31). These correct the goal above in place and
> GOVERN what 12-02 may ask Aristotle to prove.**
> **(8) THE CURVATURE INDEX IS `κ_φ` (`\kappa_{\varphi}`), NOT `χ`** — user amendment. Correction (4)
> above and every `χ` in 12-RESEARCH are superseded on the glyph. Lean binders are `kphiS`, `kphiI`,
> `kphiStar`, with `curvIndex` the definition and `curv` the bound variable. Applying it exposed a
> second, consequential collision: the draft used `\varphi` for the FEE, contradicting the master
> document's own M0 (`\varphi` is bound to the QUOTE FUNCTION), so **the fee is `\phi`** and `\varphi`
> appears only as `κ`'s subscript. Both reviewers missed this.
> **(9) CTX-DEGEN IS NARROWED — THERE IS NO LITERAL DE-DEGENERATION THEOREM.** The goal's "state and
> solve the JOINT program over `(Θ_φ, η)` … the de-degeneration" is NOT deliverable as written:
> `mevMulti` contains no `η`, no `κ_φ` and no `ϱ_I`, so nothing in the curvature layer moves the
> Phase-11 objective and the `Θ_φ` degeneracy stands exactly where Phase 11 left it. Contrasting
> Capponi's `arbLoss`-minimizer with the `λ_ARB`-minimizer is comparing two objects the document
> itself declares NOT IDENTIFIED. **What ships instead:** the interior optimum in the
> Capponi-anchored model, the `η`-bridge transport, and the Phase-11 contrast as an honest SCOPE
> statement — with `ϱ_I` a CANDIDATE for the demand-elasticity layer `LEAN_TRACEABILITY` §6(b)
> names, not a closure of it. A real de-degeneration needs one objective carrying both a
> demand-elastic investor and `λ_ARB`; that object exists in neither model and is OPEN.
> **(10) 12-RESEARCH.md CARRIES THREE DEFECTS FORWARD** — F8's interior-optimum mechanism (the peak
> comes from the LP revenue term's corner→interior regime switch, NOT from two antitone objectives
> having opposite corners, which is an UNSOUND scalarization argument), F8's de-degeneration
> framing, and F3's "curvIndex covers curvatures beyond his range" (the map covers `(0,1) ⊊ [0,1]`,
> so it neither reaches nor extends the anchor's corners). **Correct these at 12-04** so no later
> plan re-injects them.

> **PLANNING CORRECTION CONFIRMED AT CLOSE (2026-08-02).** Correction (1) above is no longer a
> reading of the PDF — it is **machine-checked**. `EtaCurvature.lpExcess_isMaxOn` establishes the
> maximum from the TWO ONE-SIDED strict monotonicity results `lpExcess_strictMonoOn` /
> `lpExcess_strictAntiOn`; `kphiStar_eq_kphiI` locates it at the branch point. **There is no
> first-order condition anywhere in the landed module** — `κ_φ⋆` is a KINK, and `η⋆` comes from
> INVERTING the `curvIndex` bijection in closed form (`curvIndex_etaStar`, an EQUALITY). The Goal's
> "first-order characterization where provable" is therefore answered: it was not provable, because
> it is not true, and the construction supersedes it. Correction (5) also stands as written —
> `exp/DynamicsOptimization` (`foc_eta`, `optimal_controls`) still carries its own interior-η claim
> in a different model with a HYPOTHESIZED maximizer and an FOC; what this phase added is
> CONSTRUCTION, and `LEAN_TRACEABILITY` §7.2 says so explicitly so the two are never conflated.
> Correction (10)'s three 12-RESEARCH defects were handled by neutralization at 12-02 (the false E7
> sentence was quoted as approved-doc text and explicitly PROHIBITED from being formalized) and by
> the ESC-1 correction landing in both document copies; **`12-RESEARCH.md` itself was left unedited**
> — it is a dated research artifact, and the corrections live in the ROADMAP block above, in E7's
> `CORRECTION (2026-07-31, ESC-1)` line and in `LEAN_TRACEABILITY` §13.

> **CONTINGENCY DISPOSITION: `12-CONTINGENCY.md` WAS INVOKED, at 12-03.** The first Aristotle run
> (project `4878ca32`, task `e1c846ae`) returned **`OUT_OF_BUDGET`** with 36/51 declarations proven
> and 15 `sorry`s — resource exhaustion, not a payload or logic failure (all 18 bundled inputs came
> back byte-identical). The partial was **NOT integrated**, because `lean/vol_markets/` requires
> sorry-free axiom-clean modules and hand-proving the gap is barred. The contingency's **option 1
> (second bundle)** was taken over option 2 (close with 15 honest `OPEN` rows), at the user's
> `submit eta -b`: project `c3a617f3`, task `4ec89173`, the original 18 inputs plus the partial as
> working base, prompt scoped to the 15 gaps with a transport hint and a budget priority order.
> **Outcome: `COMPLETE` — 51/51, 0 sorries, declaration list identical to the submitted partial.**

**Phase outcome (2026-08-02, FINAL):** Six of the seven CTX-* requirements SATISFIED; **CTX-DEGEN
SATISFIED AS NARROWED** per the user's binding 2026-07-31 ruling (decision (9) above) — there is no
literal de-degeneration of the `Θ_φ` program and none was attempted. The phase delivered the
**first CONSTRUCTED interior optimum in this program**, `η⋆ = ln((1+ϱ_I)/(1+φ))/(Δi²·ln λ)`, where
everything in `Θ_φ` had been a corner or a saturation limit — and it delivered it without a
first-order condition, which is the opposite of what the Goal asked for and is recorded as such.
Two things the record refuses to overstate: the **equilibrium transfer is an ASSUMPTION** (every
theorem is about `lpExcess ∘ curvIndex`, none is about this project's AMM), and the user's
η-identity decision is only **PARTIALLY discharged** — exponent half PROVEN, factor-share half OPEN.

**Requirements**: CTX-CURVDOC, CTX-CAPTRANS, CTX-INTERIOR, CTX-ETABRIDGE, CTX-DEGEN, CTX-REVIEW, CTX-TRACE
> NOTE, UPDATED 2026-08-02: at planning time `REQUIREMENTS.md` carried no `CTX-` rows at all, so
> `requirements mark-complete` was a no-op for this phase. **That gap is now closed for Phase 12
> only:** a `### Lean4 + Math track (CTX-*)` section was added to `REQUIREMENTS.md` carrying these
> seven ids with their dispositions, plus traceability rows. Phases 8–11's CTX-* ids remain
> undeclared there and are still tracked only in this file — recorded rather than silently patched,
> since back-filling them belongs to the roadmapper, not to a phase close-out.
**Depends on:** Phase 11 (MevOptimization/MevJointProgram layer; the M6a degeneracy theorem is the motivation), EndogenousMaturity (independent)
**Directory:** `.planning/phases/12-eta-tradeoff-optimum/`
**Plans:** 4/4 plans complete — **PHASE COMPLETE 2026-08-02**

Plans:
- [x] 12-01-PLAN.md — CTX-CURVDOC, CTX-REVIEW: **COMPLETE.** E0–E8 authored from the PDF (Lemma 3 / Prop 5 / Prop 6), INVERTED notation gate written (η REQUIRED; proven to FAIL on the Phase-11 addendum with the Rule-1 message) and later hardened with negative-tested Rules 4b/4c for `κ_φ`; two reviewers ran blind in parallel and returned **3 BLOCKER + 9 MAJOR, all resolved** — two of the BLOCKERs were defects the PLAN and 12-RESEARCH had specified; HEAVY USER APPROVAL obtained plus a binding `κ_φ` notation amendment and the CTX-DEGEN narrowing; inserted at the user-authored `## FLAIR & MEV` stub — NOT a new `## ETA` section, per the user's placement ruling — and pinned `APPROVED-ETA-SHA256 4f5362c1…`. Plank file written, NOT committed (owner `ul2inqpl`). `autonomous: false`
- [x] 12-02-PLAN.md — CTX-CAPTRANS, CTX-INTERIOR, CTX-ETABRIDGE, CTX-DEGEN, CTX-REVIEW: **COMPLETE, TASK IN FLIGHT AT CLOSE** (project `4878ca32`, task `e1c846ae`, `IN_PROGRESS`). Bundle assembled as **EIGHTEEN** modules, not the planned seventeen — `JitLiquidity` landed mid-plan and the binding rule is doc + ALL proved modules — with the **import closure PROVEN** (14 distinct imports all resolving, the check that catches the `CESLongVolPayoff` class 12-RESEARCH F7.3 missed) and all 18 copies byte-identical to the landed modules; `12-02-MODULE-MAP.txt` written because 12-03's inverse rewrite is **NOT a single sed** (`RequestProject.eta` → `exp.eta` but `RequestProject.VolInstrument` → `vol_markets.VolInstrument`). A 1232-line, 35-item T1'–T31' prompt with E0–E7 spliced VERBATIM by script. **The two-reviewer gate found 2 BLOCKER + 1 MAJOR + 11 MINOR, 0 unresolved — and one BLOCKER was in the APPROVED, BYTE-PINNED DOCUMENT:** block E7's scalarization-impossibility sentence is FALSE on `[κ_φ,S, κ_φ,I]` (the two ratios switch branches at DIFFERENT points), recomputed independently to a stationary interior maximum at `κ_φ ≈ 0.2412`, at no branch point, and it had been mandated verbatim into a permanent Lean docstring. The second BLOCKER was a typechecking defect on the headline chain (`lpExcessEta` applying 8 args to a 7-param `lpExcess`, reintroducing `cOne` as free and silently falsifying the branch agreement the peak rests on); the MAJOR was T8' FALSE as displayed, missing the symmetric `Real.sqrt` guard on `premInv`. All fixed pre-submission. Doc fidelity re-proved at submit time (`APPROVED == BUNDLED == LIVE` = `4f5362c1…`) **while the live whole-file hash moved twice** — the section is the gate, not the file. Queue proven clear (20/20 IDLE, zero `eta-curvature` projects), exactly one task in flight. **USER RULING: the document amendment for ESC-1/ESC-2/ESC-3 is DEFERRED to 12-04** so the live doc cannot desync from the copy Aristotle proves against. **CTX-CAPTRANS/CTX-INTERIOR/CTX-ETABRIDGE/CTX-DEGEN are NOT yet satisfied: nothing is proven until 12-03 integrates the returned module.** CTX-REVIEW is satisfied by the gate itself. `autonomous: false`
- [x] 12-03-PLAN.md — CTX-CAPTRANS, CTX-INTERIOR, CTX-ETABRIDGE, CTX-DEGEN: **COMPLETE — and it took TWO Aristotle runs, which the plan did not anticipate.** `4878ca32` returned **`OUT_OF_BUDGET`** at 36/51 with 15 `sorry`s and was NOT integrated; the `12-CONTINGENCY` second bundle (`c3a617f3`, at the user's `submit eta -b`) closed the remaining 15 with the partial as its working base. Landed: `lean/vol_markets/EtaCurvature.lean`, **1269 lines, 51 declarations, 0 sorries, 51/51 axiom-clean**, root appended, `lake build` green (8067 jobs), origin `b02caf7` + mirror `lean4-spec main d25fd75`. All 18 bundled inputs byte-identical in BOTH runs; declaration list identical to the submitted partial (no renames, drops or additions). **Fidelity: 13/15 verbatim, 2 AMENDED with added hypotheses and conclusions intact, ZERO narrowed** — `lpExcess_strictAntiOn` gains E0's own ordering `φ < ϱ_S ≤ ϱ_I`, and `etaStar_pos_iff` gains `−1 < ϱ_I` because **Mathlib's `Real.log` is `log|x|`** (witness `ϱ_I = −3, φ = 0`), exactly the log-sign trap the 12-02 Model QA review predicted. **CTX-CAPTRANS, CTX-INTERIOR, CTX-ETABRIDGE SATISFIED; CTX-DEGEN SATISFIED AS NARROWED.** Optional **T28'b came back ABSENT** as pre-authorized ⟹ E8(6) OPEN and the η-identity decision is **PARTIALLY discharged**, not closed. Executed manually by the orchestrator; `12-03-SUMMARY.md` written retroactively at 12-04 and marked as such
- [x] 12-04-PLAN.md — CTX-TRACE: **COMPLETE. CTX-TRACE SATISFIED.** `LEAN_TRACEABILITY` §0 gained rows for `premInv`/`premShock` (**declared PREMIA, NOT probabilities** — the misreading that makes `κ_φ⋆` uninterpretable), the four absorbed `ϖ_*` constants, `kphiS`/`kphiI`/`kphiStar`, `cOne…cThree` and `etaStar`; a binding paragraph recording the Capponi remaps, the absorptions and their reasons, the `f ≡ φ` identification, the **η protection and the gate INVERSION of Phase-11's Rule 1**, the ν avoidance, the deliberate `λ` overload (tick base vs subscripted hazard) and the **`arbLossRatio` / `mevMulti` NON-IDENTIFICATION**; and the η-identity outcome recorded as **PARTIALLY discharged**, citing `exp/eta.lean`'s own `P_half` docstring ("η does not enter the tick→price map") as the reason the second half is a modelling claim. New **§7.2** is the ETA entry point plus the **nine-item E8 OPEN ledger**, and it **points at §13 rather than duplicating it** — §13 had already landed with the module at `b02caf7`, following the §8-onward convention, so a second claim table would have created two sources of truth. §6(b) **AMENDED, not deleted**: `ϱ_I` is a PARTIAL carrier; the equilibrium transfer and MMR eq. (27) stay OPEN. Every backticked identifier in §7.2 grep-verified to be a real declaration, scoped to that section (11-06's defect fixed, not repeated). The addendum carried **no** `> LEAN` annotation while the plank copy did — the two had DRIFTED — so the annotation was mirrored byte-identical, and the **sha-pin invalidation is now disclosed** (`4f5362c1…` → live `54d10b59…`, safe because both gates were already consumed and passed). `../plank/todo.md` line 227 answered with the quotable controller law, its four strict comparative statics, its carriers, and the unobservability / factor-share / equilibrium-transfer caveats — **no on-chain proxy invented, deliberately**. Plank HEAD `08039da` before and after; M0→end-of-M8 bytes proven unchanged; **no `.lean` file touched**
