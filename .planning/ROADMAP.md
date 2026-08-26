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
  5. Each mapped parameter has a reference markdown under `spec/protocol/refs/` citing its `cfmm-theory` grounding note (primary `KERNEL.md`) by URL/citekey with no code dependency on the theory tree, annotated with the behavioral theorem/assumption/regime it encodes (REF-01, REF-02).
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
| 3 | MAP-01, MAP-02, MAP-03, MAP-04, MAP-05, MAP-06, REF-01, REF-02 | 8 |
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

**Goal:** Formalize `spec/protocol/panoptic.md` in the `lean/` Lake project: the contract as a volatility option (payoff π^σ = ΔQ_v·(σ²(i(t)) − σ²_K)⁺), the vol-claim price as an option-replication cost (Demeterfi et al. variance-swap decomposition + Panoptic streaming-premium θ kernel), and identification of the vega-like greek υ ≡ Δπ/Δσ² in its analytical/contract-level form (econometric identification via the Panoptic subgraph is scoped during discussion). Owned by the Lean4+math session (worktree `lean4-spec`, branch `feat/lean4-spec`).
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

---

### Phase 12.1 (INSERTED): Definitional Re-Ordering of the Document Opening

**Goal:** Carry out the user's re-ordering of the doc's opening — formal definition of `θ`, then the
streamia assignment, then a named assignment for the time-integrated streamia — with `π^σ` promoted
to a DEFINITION (conditional on "if already formalized") and the replication weights renamed off `α`.

**Requirements**: CTX-DEFORDER
**Status:** BLOCKED — nothing may be started. TWO preconditions: HEAVY USER APPROVAL, and resolution
of the live θ exponent-sign FLAG (θ cannot become a definition while its display carries an
unresolved sign).
**Registered as a decimal insertion** so an indefinite user gate does not hold a phase open.
**Directory:** `.planning/phases/12.1-doc-definitional-reorder/`
**Plans:** 0/1 — none written; blocked.

> All three user comments are blocked, including the `α → c₁,c₂` rename: `c₁`/`c₂` are ALREADY TAKEN
> as the E4 branch coefficients (13 sites, `c₁`'s sign load-bearing in four displays), so the rename
> as literally stated creates a collision. A free symbol pair must be proposed to the user first.

---

### Phase 13: Capponi `F` → `φ` Convention Closure

**Goal:** Close the `F → φ` transition the machine forced open — the CES lock, the Angeris canonical
form, and the curvature verdict machine-checked, with the document's notation corrected to match and
no false statements left behind.

**Requirements**: CTX-PHIDOC
**Status:** IN FLIGHT. Four Lean modules landed axiom-clean (`PhiCES` 12, `CanonicalCurve` 16,
`CurvatureTwo` 18, `EtaTilde` 23 — the last landed AFTER Phase 12 closed and was previously
registered nowhere). Rename set applied (`601e7ba`, `758e964`, `634ded6`, `838289f`).
**Depends on:** Phase 12 — this phase is its correction: `curvOfTilde_not_curvature` proves the
Phase-12 index was never a curvature, so E1–E7 stand as mathematics but read as SHARE statements.
**Directory:** `.planning/phases/13-phi-convention-closure/`
**Plans:** 0/3 — none written yet; see `TRACKS.md` OPEN items (a)–(j).

> Item (c), the stale `eta-notation-gate.sh`, is a **blocking predecessor of every doc insertion in
> the program** — Phases 12.1 and 14 both end in doc blocks and neither can be gated until it is
> refreshed. Items (e)–(g) are defects sitting in the already-committed document, including one FALSE
> LINE the rename itself created (repaired `838289f`) and a `χ` leg-orientation contradiction now
> FLAGGED in the doc for author decision.

---

### Phase 14: Kristensen Implied-Volatility Integration

**Goal:** Integrate Kristensen's implied-volatility LEVEL — the σ_IV extraction with anchors, the
VOL/AMT ↔ `u` relation as a proved lemma or recorded refutation, and the four new symbols declared
rather than smuggled.

**Requirements**: CTX-IVLEVEL
**Status:** RESEARCH DONE, GATED — not executable. Blocks V0–V9 drafted. The user's `2·√` hypothesis
is REFUTED as a CES specialization (both factors Gaussian); the headline is that Kristensen's
constant-`AMT_tick` assumption holds exactly iff `ξ = ξ⋆`, the log-contract ladder.
**Depends on:** Phase 13 (c) — notation gate; Phase 13 (g) — the signed-`ΔQ` ruling, which is a
Phase-13 doc defect this phase consumes.
**Directory:** `.planning/phases/14-kristensen-integration/`
**Plans:** 0/4 — none written; gated.

> Ordering constraint with Phase 12.1: 12.1 renumbers definitions and renames the replication
> weights, and the V-blocks are drafted against the current numbering. **12.1 runs strictly BEFORE
> all V-blocks or strictly AFTER them — never interleaved.**

---

### Phase 15: Greeks Formalization (the UNFORMALIZED bundle)

**Goal:** Formalize the Greeks layer the document already carries as blocks G0–G6 but which exists in
no Lean module — the `D_p` and `Γ` ladder displays, the θ split, the `Δθ_fee/Δσ` statics, and above
all the **G4 deficit lemmas**.

**Requirements**: CTX-GREEKS
**Core claim:** CC-GREEK
**Status:** NOT STARTED and **not yet bundleable** — two decisions must land first.
**Directory:** `.planning/phases/15-greeks-formalization/`
**Plans:** 0/3 — none written; gated on PR-CARRY and PR-THETA.

> **The headline is a NEGATIVE result and it is what is unformalized.** G4's underspecification
> deficit is **structural, not numeric**: the matrix is block-triangular and `(β_j,γ_j)`'s column is
> **zero on every shape row**, so the free `(β,γ)` provably **cannot** close it. That is the formal
> answer to "can Greeks bind the free (β,γ)?" — no, and by rank.
>
> **G2 is OFF-BUNDLE**: its skew law is an `η_L` statement and E8(6) (`η_L = η`) is OPEN (PR-ETAL).
>
> **PR-CARRY decides what gets proved**, not how — per-event (M6b) vs time-integrated (λ_FLAIR);
> G6(4) says decide before bundling, and the M2 hedge claim needs the time-integrated form.
>
> The Bunni-v2 LDF port (`ℓ(ξ,ι;·) ⇝ ℓ_LDF(θ_LDF;i_K)`) is the user-declared FUTURE MILESTONE that
> the deficit count points at — **not part of this phase**.

---

### Phase 15.1 (INSERTED): Intrinsic Liquidity and the General-φ Ladder

**Goal:** Make the trading curve's liquidity a **dimensionally consistent, local** object, and
establish the reduction that lets any member of the family run on the half-kernel machinery on-chain
protocols actually instantiate.

**Requirements**: CTX-ELL, CTX-HALFKERNEL
**Status:** IN FLIGHT — Aristotle project `9786b137-f7e7-4175-af83-738c330b4022`
(`scratch/ell-submit/EllIntrinsic.lean`, 8 targets, priority L1 > L7 > L4 > L2 > L3 > L5 > L6).
**Directory:** `.planning/phases/15.1-intrinsic-liquidity/`
**Plans:** 0/2 — none written; the bundle's verdict determines what they contain.
**Sources (vendored):** `plank/refs/cfmm/risk_tung_wang-pricing_hedging_liquidity_provision-2026.pdf`
(arXiv:2603.01344v1 §2.1), prerequisite
`plank/refs/cfmm/tung_wang-clmm_dynamics_continuous_time-2024.pdf` (arXiv:2412.18580, App. B).

> **WHY THIS PHASE EXISTS — Rule 5 is doing silent dimensional work.** The level of
> `φ_(χ,ε)` carries physical dimension `X^χ · M^(1−χ)`, so it is only comparable across curves at
> `χ = 1/2`. Every `L̄`-denominated statement in the document is therefore dimensionally valid ONLY
> because Rule 5 pins `χ ← 1/2`. Unpinning χ without adopting the intrinsic liquidity would break
> them as a TYPE ERROR, not as an approximation. The source's `ℓ` repairs exactly this: it always
> lands in the half-kernel dimension `√(X·M)`, it is LOCAL (a field `ℓ(x,y)`, not a global constant),
> and it is invariant under reparametrization of the curve.
>
> **ESTABLISHED BEFORE SUBMISSION (hand-derived, numerically verified — not conjecture):**
> their `ℓ = −2p^{3/2}/(dp/dQ_X)`, hence by the envelope relation `Γ = −½ ℓ p^{−3/2}` — which is the
> G1 ladder display VERBATIM. **Their `ℓ` IS our `L(i_K)`, and is NOT `κ_φ`**: dimensions decide it
> (`ℓ ~ √(X·M)` vs `κ_φ` dimensionless), and `ℓ`'s dimensionless factor depends on the SHARE while
> `κ_φ` is a function of the SUBSTITUTION parameter alone — orthogonal axes. Also established:
> `ℓ/√(xy)` is state-constant ONLY on the ρ = 0 slice (it sweeps 1.297→1.977 across the reserve ratio
> at ρ = 0.5), so off Cobb–Douglas the intrinsic liquidity is a genuine FIELD.
>
> **THE IMPLEMENTATION-FACING RESULT (L7).** The constant-product pool carrying `L ← ℓ` reproduces a
> general member's marginal price AND its first-order price impact: the half-kernel is the
> **osculating** instrument at every state, not an approximation to one. That is why
> `(sqrtPriceX96, per-tick L)` suffices on-chain to instantiate curves that are not constant-product —
> and it is the reason LDFs work at all. Honest limits, to be stated in any doc block: the match is
> local and second-order (it pins Γ, NOT `d²p/dQ_X²`), and value functions come from integrating, so
> a local match is not a global value match.
>
> **Notation ruling (binding):** the object is indexed by the parameters that characterize the family
> — `ℓ_(χ,ε)` — never by a family-name subscript. It is told apart from the ladder weight `ℓ(ξ,ι;i_K)`
> by its index tuple.

---

### Phase 15.2 (INSERTED): Bunni-v2 LDF Port

**Goal:** Replace the pinned geometric weight profile with a parametrized liquidity density —
`ℓ(ξ,ι;·) ⇝ ℓ_LDF(θ_LDF; i_K)`, `Σ ℓ_LDF = 1` — closing the G4 ladder deficit.

**Requirements**: CTX-LDF
**Status:** NOT STARTED — **downstream of Phase 15.1 and gated on it.**
**Directory:** `.planning/phases/15.2-bunni-ldf-port/`
**Plans:** 0/TBD.

> This was the user-declared FUTURE MILESTONE at G4. It is now SEQUENCED, not merely queued: Phase
> 15.1 supplies the geometric object (`ℓ_(χ,ε)`, the local intrinsic liquidity field) that an LDF
> parametrizes. Porting the engineering first would mean re-deriving that object afterwards.
> G4's arithmetic is unchanged — `dim θ_LDF ≥ ι − 2` ⟹ ladder deficit 0; hazard rows are already at
> deficit 0. Reference: `plank/refs/bunni-v2.pdf` §2.2 (`l_r = L · LDF_w(r)`), §2.2.1 the geometric
> base example.

---

### Research spike (NOT a phase): `T_ITM/T` occupancy

`.planning/occupancy/OCCUPANCY-SPIKE.md`. Demoted from a requirement 2026-08-03: it rests on one user
sentence with no research, and its own next action is to determine *whether Kristensen's `T` is a
maturity at all* given perpetual options have none. Promoted to a CTX requirement only if the spike
finds a connectable object.

---

## Resume ledger — read BEFORE this file

`.planning/IN-FLIGHT.md` records what is **handed off and waiting** (Aristotle bundles in flight)
and what is **parked as a leaf**, each with an explicit RESUME TRIGGER. The roadmap says what the
plan is; that file says what is owed. A hand-off adds a row there in the same action.

## Core claims & prerequisites

`.planning/PREREQUISITES.md` is the register: seven core claims (`CC-*`) grounded in the document's
own block structure, and fourteen prerequisites (`PR-*`) with their blocking edges. Read the critical
path off that file, not off the phase files.

**Two prerequisites sit underneath the program's central claim and neither is discharged.** `CC-REPL`
— the replication claim the whole document exists to support — rests on Theorem 1, which depends on
`PR-REGION` (an admissibility region **literally absent from the page**, leaving `u` ill-posed on
exactly the swaps it measures if the `ΔQ` legs are signed) and `PR-ORIENT` (a `χ` leg orientation
that contradicts itself between two displays).

**`PR-GATE` is the widest blocker** — the stale notation gate stops every pending doc insertion in
the program, making it the cheapest high-value item on the board.
---

# Milestone v2.0 — Realized-Volatility Oracle Differential Testing

## Overview

This is a **separate, parallel track** from the v1.0 GAMS-plumbing milestone above (Phases 1–7, which remain intact and are not renumbered). It finishes the **variance half** of the Plank realized-volatility oracle's differential proof against **Algebra's `VolatilityOracle` — the reference of record**. The tick-average surface (`getTwapTick` / `getTickCumulative`, three-way exact vs Algebra + UniV3) is DONE and merged (Phase 0–1 of `.planning/plank-voldiff-plan.md`). What remains is proving `volatilityCumulative` and `averageTick` bit-exact.

Phase numbering **continues at Phase 8**. These four phases derive solely from the v2.0 requirements **VDIFF-01..08** in `REQUIREMENTS.md` and formalize Phases 2/3/3b/4 of the two-review-passed `plank-voldiff-plan.md`.

**Hard constraints honored throughout (from PROJECT.md + plank-voldiff-plan.md):**
- **`make compile-plank` passing is NOT evidence** — Plank does not type-check code unreachable from `run{}`. A test only proves something by CALLING the module. Every success criterion below is a passing/failing test or a killed mutation, never "compiles."
- **Every new test MUST be mutation-verified falsifiable before it is trusted** (VDIFF-08). A prior reviewer found 3 of 6 smoke tests survived deliberate bugs. This falsifiability gate is embedded in the success criteria of every test-producing phase (9, 10, 11), not deferred to a single phase.
- **The differential reference is a mutable, untracked `node_modules` file** — pinning it (VDIFF-01) comes FIRST (Phase 8) so every later phase builds on a stable baseline.
- **The corpus is CONSTRUCTED, not `vm.assume`-filtered** (VDIFF-05/06); `span > 2×WINDOW` is required to execute `calculate_avg_tick`'s WINDOW-interpolation branch and `window_start_index` INSIDE `write_timepoint`, and a separate sub-WINDOW corpus is the only regime that reaches `u32_sub`.
- **The volatility diff is Algebra-vs-Plank ONLY** — UniV3 has no volatility accumulator, so its ref is NOT driven in the vol corpora (avoids ~11.5M gas/run of unused work). This is where v2.0 differs from the merged tick-average diff (which was three-way).
- **Tolerance-0 is regime-conditional and guaranteed within it.** Both reviewers confirmed bit-exactness over int24 ticks × uint32 spans (kernel numerator peaks ~2^149 ≪ 2^256; `@evm_sdiv` == Solidity `/`; max |tickCumulative| ≈ 3.8e15 < int56 max 3.6e16). It is NOT claimed in Algebra's deliberate int56-overflow regime (Plank's full-width in-flight accumulator doesn't replicate the `int56` wrap there) — the type bounds keep the corpus out of that regime, and `dt=0` is excluded from the kernel fuzz (Solidity reverts, SDIV returns 0).
- **Build on existing infrastructure, do not re-create it:** `PlankTestBase.sol`, the Algebra + UniV3 refs (`getTimepoint`/`lastIndex`/`oldestIndex`/`getTickCumulative`), Plank's `getTimepointPacked`/`lastIndex`/`oldestIndex`/`readWindow`, the Phase 0–1 driver `test/market_state_measurements/RealizedVolatility.diff.t.sol`, and the `make test-vol-prereqs` target.

## Phases

- [x] **Phase 8: Reference Integrity & Kernel Mock** - Pin the WHOLE Algebra baseline closure (plugin impl + storage lib + transitive) against silent `npm ci` swaps, stand up a distinctly-named mock exposing `_volatilityOnRange` (probe-diffed vs Plank), and remove the one wrong raw-vs-normalized scalar-vol assertion (window-normalized `getAverageVolatility` port deferred) (completed 2026-07-16)
- [x] **Phase 9: Variance Kernel Unit-Diff & Full-Timepoint Diff** - Fuzz `calculate_realized_volatility` vs Algebra's `_volatilityOnRange` for exact **full-uint256** equality (NOT uint88 — 09-01 showed the arg-order divergence lives in the high bits a uint88 compare discards), and after every write assert Algebra-vs-Plank agree field-by-field on the stored timepoint — each mutation-verified falsifiable (completed 2026-07-16)
- [ ] **Phase 10: Discriminating Corpora (span>2×WINDOW + sub-WINDOW)** - Construct the `span > 2×WINDOW` corpus that actually exercises the binary search / interpolation / `window_start_index`, plus a distinct sub-WINDOW corpus for the `u32_sub` regime — both non-vacuous and mutation-verified
- [ ] **Phase 11: Edges, Mutation Battery & Make Wire-Up** - Edge cases (dt-too-old revert, same-block idempotency, uint32 wrap, ring wrap via `vm.store`), the full mutation battery proving every new test falsifiable, and the suite folded into `test-vol-prereqs`

## Phase Details

### Phase 8: Reference Integrity & Kernel Mock
**Goal**: The differential baseline can no longer move under the suite, the internal variance kernel is callable in isolation, and the one wrong scalar-vol assertion is removed — so every later diff compares like-for-like against a stable reference. (Retitled from "…& Scalar-Vol Reconciliation": both reviewers flagged that porting Algebra's window-normalized `getAverageVolatility` is production work + redundant with VDIFF-04, so VDIFF-03 is descoped to a deletion+doc, and the port is deferred.)
**Depends on**: Phase 0–1 (merged tick-average diff + `RealizedVolatility.diff.t.sol` driver). First v2.0 phase.
**Requirements**: VDIFF-01, VDIFF-03
**Success Criteria** (what must be TRUE):
  1. The pin covers the WHOLE baseline the harness links — `VolatilityOraclePluginImplementation.sol` (the delegatecall target driving Algebra in VDIFF-04), `libraries/VolatilityOracle.sol`, `libraries/VolatilityOracleStorage.sol`, and their transitive imports — vendored under `lib/` or checksum/tarball-pinned. A build/CI check FAILS LOUDLY when the `node_modules` copy diverges — verified by deliberately editing a reference file and observing red. (VDIFF-01)
  2. A mock with a DISTINCT name (the package already ships a `MockVolatilityOracle` — do not shadow it) wraps Algebra's `internal pure` `_volatilityOnRange` (storage-free, value args — trivially exposable) as an external function, compiling under `solc =0.8.20`. A probe DIFFERENTIALLY asserts the mock's output against Plank's `calculate_realized_volatility` on a non-degenerate input (`tick0 ≠ tick1`, `b ≠ 0`) — proving it is CALLED and correct in one shot, not merely returns nonzero. (VDIFF-01 scaffolding)
  3. The incorrect assertion diffing Plank's raw `get_average_volatility` accumulator against Algebra's window-normalized `getAverageVolatility` is REMOVED, and the test file documents they are different quantities (Algebra's is Bessel-corrected + WINDOW-normalized). Any scalar vol check instead uses the stored `volatilityCumulative` field (VDIFF-04). Porting Algebra's `getAverageVolatility` to Plank is DEFERRED to a follow-on. (VDIFF-03)
**Plans**: 3 plans (2 waves)

Plans:
- [ ] 08-01-PLAN.md — Pin the 4-file Algebra reference closure via a sha256 manifest + closure-drift guard; wire into `make test-vol-prereqs`; PROVE red on divergence with 3 observed mutants (VDIFF-01) [wave 1]
- [ ] 08-02-PLAN.md — `AlgebraVolatilityKernelMock` exposing `_volatilityOnRange` + a Plank harness for `calculate_realized_volatility` + a non-degenerate differential probe (tolerance 0, k!=0, b!=0) (VDIFF-01 scaffolding) [wave 2, depends 08-01]
- [ ] 08-03-PLAN.md — Remove the raw-vs-window-normalized scalar-vol diff surface and document why the quantities differ; no `getAverageVolatility` port (VDIFF-03) [wave 1]

**Planning note (VDIFF-03):** the "incorrect assertion" this phase was chartered to delete does
not exist in the tree — the planner grepped every `.sol`/`.plk` under `test/` and `src/` and found
no site diffing Plank's raw `get_average_volatility` against Algebra's window-normalized
`getAverageVolatility`. What DOES exist is the surface that invites it: an unused
`getAverageVolatility` declaration in `RealizedVolatilitySmoke.t.sol`'s `IRealizedVolatility`
(declared, never called), one `assertEq` from the mistake. 08-03 removes that surface and documents
the trap — the faithful reading of VDIFF-03's intent against the actual code.

### Phase 9: Variance Kernel Unit-Diff & Full-Timepoint Diff
**Goal**: The variance kernel is proven bit-exact against Algebra in isolation, and the full stored timepoint is proven bit-exact after every write in the shared-driver sequence — with both proofs demonstrated falsifiable, not merely green.
**Depends on**: Phase 8 (pinned reference, `MockVolatilityOracle`, reconciled scalar getter).
**Requirements**: VDIFF-02, VDIFF-04
**Success Criteria** (what must be TRUE):
  1. A fuzz test drives `(dt, tick0, tick1, avgTick0, avgTick1)` through both the mock's `_volatilityOnRange` and Plank's `calculate_realized_volatility` and asserts exact equality (`assertEq`, tolerance 0), with `dt` bounded to `[1, 2^32)` (excluding the known `dt=0` divergence: Solidity `/` reverts even under `unchecked`, EVM SDIV returns 0) and ticks bounded to int24. Assert the full **uint256** return, not just uint88 — strictly stronger on a free axis. Tolerance-0 is GUARANTEED here (numerator peaks ~2^149 ≪ 2^256; SDIV == Solidity `/`; uint88 mask-after-add ≡ truncate-before-add), not merely hoped. (VDIFF-02)
  2. The kernel test guards the known parameter-order footgun (`(avg0,avg1,t0,t1,dt)` vs Algebra's `(dt,t0,t1,avg0,avg1)`): a mutant that swaps the call-site argument order is KILLED by the test (VDIFF-02, VDIFF-08 gate).
  3. Using an **Algebra-vs-Plank-only** driver against the same sequence (the UniV3 ref is NOT driven — it has no volatility surface), after EVERY write Algebra and Plank agree exactly (field-by-field `assertEq`, tolerance 0) on `volatilityCumulative`, `averageTick`, and `windowStartIndex` — read via `getTimepoint` (Algebra) and `getTimepointPacked` (Plank, needs test-side unpack of the vol@32 / avgTick@144-signed / windowStartIndex@224 offsets), NOT a Solidity storage mirror. `oldestIndex` is EXCLUDED: it is vacuously `0` on both sides below 2^16 writes, so this corpus cannot exercise it (covered Plank-side in Phase 11). (VDIFF-04)
  4. The falsifiability gate holds for this phase: mutating the volatility-kernel coefficient (`6→7`), corrupting the timepoint packing, and stopping `volatilityCumulative` accumulation each make at least one Phase 9 assertion FAIL; baseline and restored source are green (VDIFF-08 embedded).
**Plans**: TBD

Plans:
- [ ] 09-01: TBD

### Phase 10: Discriminating Corpora (span>2×WINDOW + sub-WINDOW)
**Goal**: The windowed paths the existing assertions never touch — `calculate_avg_tick`'s WINDOW-interpolation branch and `window_start_index` selection INSIDE `write_timepoint` — plus the `u32_sub` regime, are executed by constructed, non-vacuous corpora feeding the Phase 9 Algebra-vs-Plank full-timepoint diff. (Note: the Phase-0/1 test already drives `binary_search_timepoints` and `tick_cumulative_at` interpolation via interior `dt`; what it never touches is the `volatilityCumulative`/`averageTick`/`windowStartIndex` fields — do not claim the binary search itself is new coverage.)
**Depends on**: Phase 9 (the full-timepoint diff driver the corpora feed).
**Requirements**: VDIFF-05, VDIFF-06
**Success Criteria** (what must be TRUE):
  1. The corpus is CONSTRUCTED via `bound(...)` (per-write delta forcing total span > 2×WINDOW) with NO `vm.assume` conjunction, driving **Algebra + Plank only** (no UniV3 — the vol surface has no UniV3 counterpart, and driving its ~11.5M-gas ring is pure cost). The test body asserts `span > 2*WINDOW`. No `uniV3.lastIndex()+1 < 512` guard and no 512 write-cap — those were UniV3 artifacts. (VDIFF-05)
  2. The corpus forces ≥1 strict tick rise and ≥1 strict fall BY CONSTRUCTION (seeded indices, never rejection), so `avg_tick != tick` and the kernel's `k`/`b` are non-zero — the assertions are non-vacuous — and keeps strictly-increasing distinct timestamps (`delta ≥ 1`, on which the heuristic-free `window_start_index` equivalence depends). (VDIFF-05)
  3. Coverage of `calculate_avg_tick`'s WINDOW-interpolation branch and `window_start_index` selection is evidenced SOLELY by a targeted mutant in those paths being KILLED by this corpus — `forge coverage` cannot instrument FFI-deployed Plank bytecode under via-IR, so a coverage/trace check is NOT an option. The chosen mutant must be one the ≤~49-min Phase-0/1 corpus does NOT already kill (else false confidence). (VDIFF-05, VDIFF-08 gate)
  4. A SEPARATE sub-WINDOW corpus (`init_timestamp in [0, WINDOW)`, few writes, kept distinct from the span>2×WINDOW corpus) exercises the `u32_sub` regime, and a mutant deleting `u32_sub`'s 32-bit mask is KILLED by it. (VDIFF-06, VDIFF-08 gate)
**Cost note**: the span>2×WINDOW corpus (Algebra+Plank only) is the heavy one; keep it OFF the default gate if 256-run wall-clock is prohibitive — expose it as its own `make` target and fold a bounded-run variant into `test-vol-prereqs`.
**Plans**: TBD

Plans:
- [ ] 10-01: TBD

### Phase 11: Edges, Mutation Battery & Make Wire-Up
**Goal**: The edge behaviors agree across implementations, the whole new suite is proven falsifiable by an explicit mutation battery before any green is trusted, and it runs as part of `test-vol-prereqs`.
**Depends on**: Phase 9 and Phase 10 (the battery covers every new test; wire-up folds them all in).
**Requirements**: VDIFF-07, VDIFF-08
**Success Criteria** (what must be TRUE):
  1. Edge tests pass across Algebra and Plank: a lookback older than the oldest retained timepoint reverts on BOTH (bare `vm.expectRevert()`, since revert data differs); a same-block double write is idempotent (no second timepoint, no revert); a uint32 timestamp wraparound is handled by a SEPARATE hand-built test near `type(uint32).max` (the [1e6,3e6] corpus cannot reach it); and ring-buffer wrap is asserted by a **Plank-only** unit test that `vm.store`s the index to 65535 and writes once (NOT 65536 writes; NOT a differential — Algebra's library ring cannot be cheaply forced to a near-wrap state) (VDIFF-07).
  2. An explicit mutation battery is defined and EVERY mutant is KILLED before any green is reported: deliberate bugs in the variance kernel, the packing, and the accumulator (plus the `u32_sub` mask and the `@evm_signextend` corrections) each fail at least one test; baseline and restored source are green (VDIFF-08).
  3. The full v2.0 diff suite is wired into a `make` target folded into `test-vol-prereqs`, and `make test-vol-prereqs` runs it green under `--via-ir --optimize` (VDIFF-08).
  4. No test trusted by the suite is constant-tick-only or `tick == 0`-vacuous, and each new test names in-file the mutation it kills (falsifiability discipline; VDIFF-08).
**Plans**: TBD

Plans:
- [ ] 11-01: TBD

## Progress (Milestone v2.0)

**Execution Order:** Phases execute strictly in numeric order: 8 → 9 → 10 → 11. Reference integrity and the kernel/full-timepoint diff are prerequisites for the corpus work, which is a prerequisite for the edge + mutation-battery wire-up.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 8. Reference Integrity & Kernel Mock | 3/3 | Complete | 2026-07-16 |
| 9. Variance Kernel Unit-Diff & Full-Timepoint Diff | 2/2 | Complete | 2026-07-16 |
| 10. Discriminating Corpora (span>2×WINDOW + sub-WINDOW) | 0/TBD | Not started | - |
| 11. Edges, Mutation Battery & Make Wire-Up | 0/TBD | Not started | - |

## Coverage (Milestone v2.0)

All 8 VDIFF requirements map to exactly one phase:

| Phase | Requirements | Count |
|-------|--------------|-------|
| 8 | VDIFF-01, VDIFF-03 | 2 |
| 9 | VDIFF-02, VDIFF-04 | 2 |
| 10 | VDIFF-05, VDIFF-06 | 2 |
| 11 | VDIFF-07, VDIFF-08 | 2 |

**Total mapped: 8/8** — no orphans, no duplicates.

## Scope Boundary (Milestone v2.0)

Reference of record is Algebra's `VolatilityOracle`. Explicitly deferred (plan items 6–7): a Uniswap-V3 `OracleLib`-based volatility reference — UniV3's `Oracle` has no native volatility accumulator, so it would re-derive Algebra's own `_volatilityOnRange` on the same tick data and diff against itself (low value). `volatilityCumulative` / `averageTick` diffs are Algebra-vs-Plank only.

---

# Milestone v3.0 — VegaAccountMod Vault (H1 Issuance, Exogenous Risk Price)

✅ **SHIPPED 2026-07-19** — Phases 12–15, 7/7 plans, 13/13 requirements (RISK-01/02, VLIB-01..04, VMOD-01..05, VVER-01/02), every phase verified with an independent mutant re-kill. `VegaAccountMod.plk` is a live, proven deposit-only vault; `PLANK_SKIP` is empty; `make compile` 11 ok/0/0; `make test` 74 pass / 4 pre-existing pos_spec fails.

Full phase details: `.planning/milestones/v3.0-ROADMAP.md` · Summary: `.planning/MILESTONES.md` · Tag: `v3.0`

Deferred to future milestones: withdraw/redeem + per-account ledger, distance pipeline D2, P0/P2 risk-price composition, stateful setHaircut, oracle wiring to RealizedVolatilityMod (with setter auth), `p_vol(σ̄)` from pos_spec.

---

# Milestone v4.0 — VolOrderManagerMod + Best-Effort Multicall

## Overview

Peer-requested by the rpc_api Haskell track (`mv15a18k`): their `StochasticOrderGen` (Poisson order-arrival generator) needs an on-chain vol-order REGISTRY plus a BEST-EFFORT batch entrypoint. This milestone builds `VolOrderManagerMod.plk` — `create_order` (validate → pack → sequential id → derived-slot store, NO pricing) and `create_orders` (N of the same in one tx, invalid tuples skipped rather than reverting the batch).

Phase numbering continues at 16 (v3.0 ended at 15). v1.0 Phases 1–7 and v2.0 Phases 10–11 are other tracks, paused, untouched, never renumbered.

**THIS SECTION IS POST-REVIEW.** A two-step parallel review (Reality Checker + Solidity Smart Contract Engineer) found **2 BLOCKERs and 6 MAJORs** in the pre-review draft. All are resolved; the decisions are recorded in REQUIREMENTS.md and restated here. What the review caught, because it explains why several criteria below look unusually specific:

1. **The packed layout was transcribed backwards.** The draft claimed `skew|strike|width @ 0/16/104, bits 128-151 zeroed`. `VolOrder.plk:35-40` is actually `width@128 | tickSpacing@104 | strike@16 | skew@0` — so "store the low 128 bits" would have kept tickSpacing and **silently dropped `width`**, the field every caller supplies and the validator checks. Resolved: store the FULL 152-bit word via the existing `pack_vol_order` verbatim, with `TICK_SPACING = 20` pinned as a module constant.
2. **The batch guard formula assumed a flat calldata layout** incompatible with any standard ABI encoder (a `uint256[]` param has an offset word the guard never validated — leaving the phantom-order hole the guard existed to close). Resolved: standard ABI `create_orders(uint256,uint256[])` = `0x81357911`, three independent guards.
3. **A "reduced width check" would have made the composed validator identically false** (`vol_range_width_is_complete` ANDs `tickSpacing > 0`, so a zeroed tickSpacing rejects 100% of traffic — under which the flagship totality fuzz passes trivially with all-fail results and looks green). Resolved by (1): with tickSpacing pinned to 20, the predicate is reused as-is.
4. **`tick_volatility_is_complete` is only `vol > 0`** — no upper bound — so an oversized strike passes validation and is then silently masked to 88 bits by `pack_vol_order`. A NEW `strike <= 2^88-1` bound must be authored; Phase 16 is therefore NOT "no new mechanism."
5. **The named precedent does not contain what was claimed of it.** `merkle_airdrop.plk` demonstrates the runtime `while` and the computed-offset `@evm_calldataload` (input side) — its three returns are 32/32/0 bytes. There is **no dynamic-array return precedent anywhere in this repo**, and `@evm_calldatasize` has **zero usages** in `src/`. The novel half of the batch has no precedent at all, which is why Phase 18 is split.

**Hard constraints (project-wide, enforced in every phase below):**
- **"It compiles" is NEVER acceptance.** `plank build` does not type-check code unreachable from `run{}`. Every criterion is a CALLED test outcome, a command exit, or an OBSERVED RED.
- Runtime `while` only — `inline while` (comptime unroll) is parsed but REJECTED by the lowerer (`lowerer/mod.rs:728`); do not design around it.
- Best-effort = pure-validation skip, NOT self-call containment. Strict and batch paths call the SAME `validate_order`.
- `array_slot` reused verbatim; the ring's index mask (in `StorageIndex.plk`) explicitly NOT imported.
- Corpora CONSTRUCTED, never `vm.assume`-filtered. ONE test file per surface. Non-fuzz anchor beside every fuzz. A `runs: 0` kill is a replay, not proof.
- Every forge invocation: `--via-ir --optimize --skip 'src/modules/protocol_integrations/PriceSetterHook.sol'` (untracked stray from PR #11's track; the skip is a no-op once they remove it).
- The mutation-falsifiability gate is embedded in EVERY test-producing phase (16, 17, 18a, 18b, 19) — not deferred to the last one.

## Phases

- [x] **Phase 16: Type Packing & Validation Foundation** - Pure `validate_order` lib (reused predicates + the NEW strike upper bound) over the verbatim 152-bit `pack_vol_order`, proven falsifiable through a 4-selector FFI harness (VORD-02) (completed 2026-07-20)

  > Correction, recorded at execution: the original "proven falsifiable with no FFI deploy" was FALSE — Plank does not type-check code unreachable from `run{}`, so a pure lib with no harness is unprovable. The harness was a required deliverable, not optional scaffolding (16-CONTEXT.md).
- [x] **Phase 17: Interface & Single-Call Module** - `create_order` CALLED-green: validate via lib, pack via type with `TICK_SPACING` pinned, sequential id, unmasked derived-slot store, readers, cast-sig-pinned selectors for BOTH entrypoints (VORD-01, VORD-03, VORD-04, VORD-05) (completed 2026-07-20)
- [x] **Phase 18a: Batch Input & State Effects** - Standard-ABI decode behind three guards, bounded `while`, validation-skip, MAX_BATCH, totality by structural enumeration + corroborating fuzz, zero-footprint proof — returns ONE word, so state effects are proven without trusting any encoder (MCAL-01, MCAL-02, MCAL-03, MCAL-04, MCAL-06) (completed 2026-07-20)
- [x] **Phase 18b: Typed Return Encoding** - The hand-rolled `(bool,uint256)[]` head/tail encoder (head `0x40`, stride `0x40`, total `64+64N`), N=0 edge, byte-level differential against `abi.encode` (MCAL-05) (completed 2026-07-21)
- [x] **Phase 19: Differential, Mutation Battery & Consumer Fixture** - Full reference-mock differential, observed-RED battery, consumer golden fixture, CALLED-green batch dispatch through FFI-deployed bytecode (MVER-01..04) (completed 2026-07-21)

## Phase Details

### Phase 16: Type Packing & Validation Foundation
**Goal**: The pure validation surface exists and is proven falsifiable in isolation — reusing the two sound predicates verbatim, authoring the one bound that is genuinely missing, over the existing 152-bit packer used AS-IS. **Correction to the pre-review draft:** this phase DOES require an FFI-deployed harness. The research claimed pure libs are "independently fuzz-testable with no FFI deploy" — that is false for Plank: there is no path from Foundry to a `.plk` pure function except `deployPlank` through a `run{}` entrypoint, and `plank build` does not type-check anything unreachable from `run{}`. Phase 13's harness header states this explicitly. A `VolOrderValidationHarness.plk` is therefore a deliverable of this phase.
**Depends on**: Nothing new (first v4.0 phase).
**Requirements**: VORD-02
**Success Criteria** (what must be TRUE):
  1. A constructed fuzz over `validate_order` CALLS the accept/reject boundary and at least one tuple is ACCEPTED (a validator that rejects everything must FAIL this phase — that is exactly the failure mode the pre-review draft would have shipped). Skew boundaries asserted at all four points: 0 REVERTS, 1 ACCEPTED, 65534 ACCEPTED, 65535 REVERTS (VORD-02).
  2. The NEW `strike <= 2^88-1` bound rejects an oversized strike that the existing `tick_volatility_is_complete` (`vol > 0`, no upper bound) would accept — asserted as a value that would otherwise be SILENTLY MASKED by `pack_vol_order` to a different stored value (VORD-02).
  3. `pack_vol_order` / `unpack_vol_order` round-trip at tolerance 0 over the constructed corpus with `TICK_SPACING = 20` in the tickSpacing field, confirming the byte-exact layout `width@128 | tickSpacing@104 | strike@16 | skew@0` — the type file is used VERBATIM, not modified (it is owned by the vol-type track, which has 4 red harness tests of its own) (VORD-02).
  4. **Mutation gate:** deleting the new strike bound, and flipping either skew boundary comparison (`>` ↔ `>=`), EACH produce an OBSERVED RED (cache cleared or killed by the non-fuzz anchor); restored byte-identical → green (VORD-02).

**Note:** This phase AUTHORS a new predicate. The pre-review draft classified it "standard pattern, no new mechanism" — that was wrong and is corrected here.

**Plans**: 1 plan (1 wave)

Plans:
- [ ] 16-01-PLAN.md — Pure `VolOrderValidationLib` (two predicates reused verbatim + the authored `strike <= 2^88-1` bound, `TICK_SPACING = 20` pinned, bool core + reverting wrapper), its FFI `VolOrderValidationHarness.plk`, the CALLED-green boundary/strike/round-trip suite, and a six-mutant observed-RED gate (VORD-02) [wave 1]

### Phase 17: Interface & Single-Call Module
**Goal**: `create_order` is a live, CALLED-green registry entrypoint — the base case the batch will compose N times — with both selectors pinned so the peer contract cannot drift silently.
**Depends on**: Phase 16 (the validation lib it calls).
**Requirements**: VORD-01, VORD-03, VORD-04, VORD-05
**Success Criteria** (what must be TRUE):
  1. `create_order(uint88,uint24,uint16)` is CALLED through FFI-deployed bytecode: `orderCount` advances 0→1, and raw `vm.load(array_slot(SLOT_ORDERS_BASE, 1))` decodes to the exact submitted tuple with `TICK_SPACING = 20` in its field — proving the store path end-to-end without trusting any getter (VORD-01, VORD-04).
  2. An invalid tuple REVERTS and leaves `orderCount` and every order slot untouched (asserted on STATE, never on return data); a second valid order gets id 2, demonstrating monotonic ids with no ring mask (VORD-01, VORD-03).
  3. Readers `orderCount()` and `getOrderPacked(uint256)` are each verified by CALLING the selector; `getOrderPacked` on a nonexistent id returns 0 without reverting, and the sentinel is justified in-code: a valid order always has `strike > 0` and `skew > 0`, so a validly packed word is never 0 (VORD-05, VORD-03).
  4. Both selectors are recomputed with `cast sig` from the exact signature strings in `interfaces/exposure/` — `create_order(uint88,uint24,uint16)` = `0x6501fe94` AND `create_orders(uint256,uint256[])` = `0x81357911` (the batch signature is a decision of record in the Overview, so this phase can pin it without waiting on Phase 18a); a compile-time test asserts `|S − keccak(SLOT_ORDERS_BASE)| > 2^64` for every scalar slot `S` (VORD-04).
  5. **Mutation gate:** reintroducing the ring's index mask into the slot derivation, moving the `orderCount` increment before validation, and aliasing a scalar slot onto the orders base EACH produce an OBSERVED RED; restored → green (VORD-03, VORD-04).

**Plans**: 1 plan (1 wave)

Plans:
- [x] 17-01-PLAN.md — `VolOrderManagerInterface` (both entrypoint selectors + both readers, cast-sig-pinned), `VolOrderManagerMod` (validate-then-id-then-unmasked-derived-slot store, zero domain arithmetic), the CALLED-green module suite incl. the id-65536 ring-mask discriminator, and a four-mutant observed-RED gate (VORD-01, VORD-03, VORD-04, VORD-05) [wave 1] — COMPLETE 2026-07-20 (17-01-SUMMARY.md)

### Phase 18a: Batch Input & State Effects
**Goal**: The batch decodes standard-ABI calldata behind three independent guards, loops with a bounded runtime `while`, skips invalid tuples with zero state footprint, and is bounded by `MAX_BATCH` — with all state effects proven via raw `vm.load` while returning only ONE word, so nothing here is observed through an untested encoder.
**Depends on**: Phase 17 (the internal create_order it composes N times).
**Requirements**: MCAL-01, MCAL-02, MCAL-03, MCAL-04, MCAL-06
**Success Criteria** (what must be TRUE):
  1. `create_orders(uint256,uint256[])` (`0x81357911`) is CALLED with a mixed valid/invalid batch: valid tuples are stored at sequential ids and `orderCount` advances by exactly the success count; invalid tuples leave NO footprint — for `k ∈ [orderCount_before+1, orderCount_before+N]`, raw `vm.load(keccak(base)+k)` is nonzero exactly for successful positions' ids and zero for every `k > orderCount_after` (MCAL-03, MCAL-01).
  2. All THREE calldata guards fire independently, each asserted with its own corpus: offset ≠ `0x40` REVERTS (the phantom-order hole — a non-canonical offset would point the loop at zero-padded space and fabricate orders); array length ≠ `count` REVERTS; `calldatasize < 100 + 32*count` REVERTS. A malformed batch reverts the whole tx — never a silent skip (MCAL-02).
  3. `count > MAX_BATCH (128)` REVERTS before any `sstore` (asserted on state); `N = MAX_BATCH` is gas-measured at **≤ 10,000,000 gas** — a real threshold, not "under the block limit." If the peer supplies a value above the 512 ceiling it is CAPPED and reported back, never silently adopted (MCAL-01).
  4. Containment is established by a WRITTEN structural enumeration of the post-validation store path in the phase artifact — each step named with its revert status (`orderCount+1` checked/unreachable; `pack_vol_order` **no revert**; `array_slot`'s checked add documented-unreachable at ~2^-192; `sstore` cannot revert) — PLUS a corroborating constructed fuzz recording "no batch-revert OBSERVED over N runs." The criterion is evidence, never "proven for all 2^256 values." The strict and batch paths demonstrably call the SAME `validate_order` (MCAL-04).
  5. Batch-of-1 produces state and id identical to a standalone `create_order`; `N = 0` completes without reverting and without touching state (MCAL-06).
  6. **Mutation gate:** deleting EACH of the three guards independently, deleting the validation branch (**corrected 2026-07-20:** the pre-review draft demanded this redden "as a BATCH REVERT, not a wrong value" — that is mechanically UNSATISFIABLE and is contradicted by MCAL-04's own structural enumeration, which this same phase produces. Verified at source: `pack_vol_order` is pure `@evm_shl`/`&`/`|` with no `require` and no trapping arithmetic, and `@evm_sstore` cannot revert on this path, so an unvalidated tuple is STORED WRONG and never reverts. The pitfalls framing assumed the store path contains revert-prone steps; the enumeration disproves that. The honest kill is a STATE red on the mixed-batch contiguity/count assertions — strictly stronger, since it pins *where* the wrong word landed. Manufacturing a revert to satisfy the old wording is forbidden; if a revert IS observed, that is an MCAL-04 finding — a step in the enumeration is not total — and must be investigated), and advancing `orderCount` on failure EACH produce an OBSERVED RED; restored → green (MCAL-02, MCAL-04).

**Plans**: 1 plan

Plans:
- [x] 18a-01-PLAN.md — create_orders dispatch branch (4 guards, bounded while, validate-then-skip, one-word return) + batch test surface + measured N=128 gas + 7-mutant gate (completed 2026-07-20 — 13 CALLED-green tests, 7/7 observed mutation REDs, N=128 total gas MEASURED at 3,247,452)

### Phase 18b: Typed Return Encoding
**Goal**: The hand-rolled `(bool,uint256)[]` return encoder — the one surface in this milestone with ZERO precedent anywhere in the repo — is byte-exact against the standard encoder.
**Depends on**: Phase 18a (the batch whose results it encodes).
**Requirements**: MCAL-05
**Success Criteria** (what must be TRUE):
  1. The batch returns `(bool,uint256)[]` with head `0x40`, stride `0x40`, total exactly `64 + 64N` bytes — verified by asserting `returndatasize` per N and by `keccak256(plankReturndata) == keccak256(abi.encode(expectedResults))`, where the expected side uses Solidity's STANDARD `abi.encode` while Plank hand-rolls. Byte equality, not decoded-value equality: a decoded comparison leaves the encoder unconstrained (MCAL-05).
  2. `N = 0` returns exactly 64 bytes (offset `0x20`, length `0`) and `abi.decode` on the consumer side succeeds — the failure here is invisible on-chain and lands in the Haskell client, which is what makes it the trickiest edge. Governing principle asserted in-doc: structurally impossible → revert; semantically empty → well-formed empty result (a zero-arrival tick is an in-distribution Poisson sample, not a client bug) (MCAL-05).
  3. Results are positionally aligned to input; `success` words are canonically 0 or 1 (a non-canonical bool passes a lenient Haskell decoder while `abi.decode` rejects it — silent disagreement); a failed tuple returns `(false, 0)` (MCAL-05).
  4. The results buffer is allocated BEFORE the loop, and a test with `N = MAX_BATCH` confirms no corruption — `array_slot` mallocs 32 bytes every iteration (`storage.plk:232`), so interleaving allocations under a bump allocator is a live corruption path (MCAL-05).
  5. **Mutation gate:** head `0x40`→`0x20` (the likeliest real bug — emitting the length word but forgetting the outer offset), stride off-by-one-word, and emitting a non-canonical success word EACH produce an OBSERVED RED against the byte-equality assertion; restored → green (MCAL-05).

**Plans**: 1 plan

Plans:
- [x] 18b-01-PLAN.md — hand-rolled `(bool,uint256)[]` return encoder: the Plank encoder (buffer before the loop, head 0x40 / stride 0x40 / total 64+64N), the byte-level differential against solc's standard `abi.encode` incl. the N=0 64-byte edge and the N=128 allocation probe, and a six-mutant observed-RED gate (completed 2026-07-21 — 8 CALLED-green tests, 6/6 observed mutation REDs, N=128 gas re-measured at 3,275,765, M7 equivalence-checked and excluded)

### Phase 19: Differential, Mutation Battery & Consumer Fixture
**Goal**: The milestone acceptance bar — a full independent-mock differential over sequences, the complete observed-RED battery, a consumer fixture that cannot be satisfied by doing nothing, and a CALLED-green batch dispatch through FFI-deployed bytecode.
**Depends on**: Phases 17, 18a, 18b.
**Requirements**: MVER-01, MVER-02, MVER-03, MVER-04
**Success Criteria** (what must be TRUE):
  1. An after-every-write driver runs identical `(create_order | create_orders)` sequences into the FFI-deployed module and an INDEPENDENT Solidity mock (standard `abi.encode`, never mirroring Plank's manual encoding), asserting `orderCount`, each stored packed word via raw `vm.load` + a single test-side `VolOrderDecoder`, and raw return-byte equality — at tolerance 0, after every write (MVER-01).
  2. The complete observed-RED battery runs with verbatim FAIL lines recorded and sources restored sha256-identical: deleted validation branch, missing strike upper bound, count-advance-on-failure, ring-mask reintroduction, each of the three calldata guards, return-head `0x40`→`0x20`, non-canonical success word. Equivalence-masked mutants documented and explicitly NOT counted as kills (MVER-02).
  3. A consumer golden fixture FILE exists containing byte strings produced by an encoder OUTSIDE this repo. If peer bytes are unavailable, a self-encoded stand-in is committed marked `NOT-PEER-VERIFIED` and the gap is listed in the milestone exit record — falsifiable either way, never satisfiable by inaction. Plus a cast-sig test for every selector string in the interface file (MVER-03).
  4. `VolOrderManagerMod`'s BATCH dispatch is CALLED green through FFI-deployed bytecode -- the real gate, and the one MVER-04's 2026-07-20 correction left standing. **CORRECTED at 19-05:** the pre-correction wording said the module "leaves `PLANK_SKIP`"; there is no exit to perform, because `PLANK_SKIP` is the Makefile's rescue queue for entrypoints that do NOT compile (Makefile:186-198) and a module dispatching a subset of its declared selectors compiles fine. The queue has been empty since Phase 15 and stays empty. `make compile-plank` reports 0 failed FOR THE POS_SPEC SURFACES this milestone owns; the suite has its own `make` target (`test-vol-order-acceptance`) and is folded into `make test`, whose comment block is updated to the newly MEASURED counts (MVER-04).

**Plans**: TBD

Plans:
- [x] 19-01: Interleaved sequence differential vs independent mock (MVER-01) — anchor ends at id 12, fuzz `runs: 256` cold-cache, module and mock agree at tol 0, `src/` sha256-identical
- [x] 19-02: Consumer golden fixture + selector completeness (MVER-03) — 5 `cast abi-encode` (alloy) cases re-derived and diffed against the committed file, all 4 `cast sig` outputs matched the pinned constants, 3 falsifiability modes OBSERVED (not the 1 mandated); alloy independently confirms 18b's layout incl. the N=0 64-byte edge. Cross-language peer gap remains OPEN and marked `NOT-PEER-VERIFIED`
- [x] 19-03: Mutation battery part A (MVER-02) — 5 observed REDs (M1a, M1b, M2, M3, M4), **0 survivors**, 0 unconstructible, each restored sha256-identical. Finding F1: M2 dies ONLY in the Phase-16 harness — no pos_spec test delivers an oversized strike, and on the batch path M2 is genuinely EQUIVALENT (strike masked to 88 bits before validation), so the strike bound at the `create_order` entrypoint is UNPROVEN. Reported, not fixed (this phase builds nothing)
- [x] 19-04: Mutation battery part B (MVER-02) — 5 observed REDs (M5/M6/M7 the three calldata guards deleted INDEPENDENTLY, M8 return element-base shift, M9 non-canonical success word), each restored sha256-identical. **Consolidated MVER-02: 10 applications, 10 REDs, 0 SURVIVORS, 0 unconstructible.** Guard 3's kill taken from the REVERT assertion with its state-invisibility RE-MEASURED. Finding: four mutants (M2, M4, M5/M6/M7) have a SINGLE point of failure — wave 1 structurally cannot cover the malformed-input or large-id surfaces
- [x] 19-05: Dedicated `make` target + re-measured counts (MVER-04) — `test-vol-order-acceptance` (plus `test-vol-order-diff`, `test-vol-order-fixture`) passes; fold-in PROVEN by observing all three Phase 19 contract names in plain `make test`; comment block re-MEASURED cold at **102 passed / 18 failed / 120 total (44 suites)** and **compile-plank 11 ok / 2 failed**, every red attributed (14 exposure draft, 4 vol-type track, **0 in `test/pos_spec/`**); the CALLED-green batch dispatch VERIFIED by three named passing tests through FFI-deployed bytecode; `PLANK_SKIP` verified byte-identically empty and the stale SC-4 "exit" wording corrected

## Progress (Milestone v4.0)

**Execution Order:** Strictly sequential: 16 → 17 → 18a → 18b → 19. Pure functions before FFI; single-call before batch; batch STATE before batch ENCODING (so a totality failure and an encoder off-by-one are never confounded); acceptance last.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 16. Type Packing & Validation Foundation | 1/1 | Complete    | 2026-07-20 |
| 17. Interface & Single-Call Module | 1/1 | Complete    | 2026-07-20 |
| 18a. Batch Input & State Effects | 1/1 | Complete    | 2026-07-20 |
| 18b. Typed Return Encoding | 1/1 | Complete    | 2026-07-21 |
| 19. Differential, Mutation Battery & Consumer Fixture | 5/5 | Complete    | 2026-07-21 |

## Coverage (Milestone v4.0)

| Phase | Requirements | Count |
|-------|--------------|-------|
| 16 | VORD-02 | 1 |
| 17 | VORD-01, VORD-03, VORD-04, VORD-05 | 4 |
| 18a | MCAL-01, MCAL-02, MCAL-03, MCAL-04, MCAL-06 | 5 |
| 18b | MCAL-05 | 1 |
| 19 | MVER-01, MVER-02, MVER-03, MVER-04 | 4 |

**Total mapped: 15/15** — no orphans, no duplicates.

## Research Flags (Milestone v4.0)

- **Phase 18a — focused research pass at plan time.** `merkle_airdrop.plk` is the precedent for the runtime `while` and the computed-offset `@evm_calldataload` (input side), and should be read line-by-line for those. Be explicit about what it does NOT provide: it has no `calldatasize` guard and no offset sanity check — followed literally it transplants an unguarded decoder into the one requirement (MCAL-02) that exists to prevent that. `@evm_calldatasize` has zero usages in `src/`.
- **Phase 18b — focused research pass at plan time.** There is NO dynamic-array return anywhere in this repo (all 11 `@evm_return` sites in `src/` are 32/64/96/0 bytes; the merkle file's are 32/32/0). Worth evaluating whether `std::abi`'s comptime machinery (`is_abi_dynamic`, `abi_head_size`, `unsafe_abi_encode_to`) is a partial reuse path rather than encoding fully by hand.
- **Phases 16, 17 — standard patterns**, skip research: near-verbatim mirrors of the v3.0 `VegaAccountMod` dispatch/slot/reader pattern and the existing pos_spec predicates. (Phase 16 does author one new predicate, but the mechanism is not new.)
- **Phase 19 — coordination checkpoint, not a research gap.** Proceed on the placeholder + stand-in fixture if the peer has not answered.

## Scope Boundary (Milestone v4.0)

Registry only — validate, pack, id, store, read, batch. Explicitly OUT: on-chain pricing (`tick_bucket_from_vol_order` and the pos_spec pricing pipeline, which has 4 red harness tests on the vol-type track); a generic `aggregate(address,bytes)` call router (a security surface with no consumer — the input is always tuples, never arbitrary calldata, which is what keeps reentrancy and delegatecall risk structurally absent); per-owner order books and any auth model (orders are anonymous in v1, like `setRiskPrice` in v3.0); events (no log-subscribing consumer); order cancellation/mutation (append-only registry).

**Forward-compat note recorded at design time:** the stored word carries `TICK_SPACING = 20` rather than a caller-supplied value. When pricing lands and orders need real tick spacings, that field becomes caller-supplied and this constant is removed — the layout does not change, only its source. This is why the full 152-bit word is stored rather than a 128-bit subset: a stored `tickSpacing = 0` would fail any future full `vol_range_width_is_complete` validation.

**Adjacent bug found during review, NOT ours to fix:** `wrap_spread_tick_assimetry` (`SpreadTickAssimetry.plk:9`) is `rawSpread << 0xffff` — a shift by 65535 that zeroes everything. It is off the `create_order` path and must stay off it; flagged to the vol-type-system track.

---

# Milestone v5.0 — VolOrder V2 Offchain Re-Pin + Stochastic Drivers (rpc_api workstream)

## Overview

The first **non-plank** milestone in this file. Where v4.0 built the on-chain vol-order
registry, v5.0 makes the **offchain Haskell client** speak that registry's **V2 (targetVega)
ABI** and drives both stochastic generators — price diffusion and Poisson VolOrder creation —
live against the four-script deploy rig, emitting the real event set.

Source: GitHub issue #13 (plank workstream handoff, `feat/plank` @ `df7088f`). Working branch
is `feat/rpc-api`; the code under change is `offchain/lib/` (Haskell), not `src/` (Plank).

Phase numbering continues at **20** (v4.0 ended at 19). v1.0 Phases 1–7, v2.0 Phases 10–11 and
the v3.0/v4.0 ranges are other tracks — paused, untouched, never renumbered.

**Verified at roadmap time (2026-07-31), and it is why Phase 20 exists as its own phase:** every
binding source-of-truth artifact this milestone consumes is on `origin/feat/plank` @ `df7088f`
and **is NOT present on `feat/rpc-api`**. Checked with `git ls-tree -r origin/feat/plank` against
the working tree: `foundry-scripts/deploy/` (5 files) is absent; `notes/` does not exist; the
handoff is absent; and the local `src/interfaces/pos_spec/VolOrderManagerInterface.plk` is still
the **v1** file (`SELECTOR_CREATE_ORDER = 0x6501fe94`, no event block at all) while the plank
branch's is V2 (`0x98d950ec` plus the E1 v2 topic0 constant). Any phase that assumes these files
are readable here will stall on its first step. Importing them is Phase 20's first deliverable —
**import, never re-type**: a re-typed selector is exactly the failure mode RPIN-04 exists to fix.

**Binding domain constraints — copied here so no phase re-derives them:**

- **Sources of truth, in strict precedence order:** (1) `src/interfaces/<namespace>/*.plk`
  (selectors + event topic0s, cast/solc-verified on the plank branch); (2)
  `.planning/rpc-api-volorder-v2-HANDOFF.md` (on `origin/feat/plank`, not yet on this branch);
  (3) `notes/DATA_CONTRACT.md`; (4) `notes/UNITS_AND_SCALES.md`. **Consume — never re-derive.**
  Where two disagree, the higher-precedence file wins and the disagreement is REPORTED, not
  silently reconciled.
- **`targetVega` is raw LIQUIDITY units** (ΔQ_v★, dimension (ii), `UNITS_AND_SCALES.md` §2),
  valid `[1, 2^96−1]`, realistic pool-L magnitudes 1e18–1e21. **NOT X96, NOT WAD, NOT
  collateral.** A unit slip here is invisible on-chain (any u96 stores fine) and only surfaces
  as nonsense downstream — which is why VEGA-01's bounds are asserted on the generator's output.
- **Retired-never-live, must never appear as a live constant:** the v1 `create_order` selector
  `0x6501fe94`, the v1 E1 topic0 `0x6a5dc726…`, and the stale `Decode.hs` topic0 `0xa8892769…`
  (which was wrong even against v1). Nothing was ever deployed under them.
- **The offchain code lives in `offchain/lib/`** (Haskell, GHC 9.10.3). **Zero `-Wall` warnings
  is a hard requirement**, not a nicety — a phase with warnings is not complete.
- **The existing supervisory-layer disciplines carry forward into the V2 re-pin UNCHANGED**
  (they are already shipped in `VolOrder/Rpc.hs` and `Encoding.hs`; the re-pin extends them to
  the fourth field, it does not rewrite them): strict **field-width validation** before packing;
  the **preview success-PATTERN delta check** (anchored on the locally-read counter and the
  pattern, never the preview's absolute ids); **receipt-block-pinned readbacks** (never
  `Latest`); and the **`receiptStatus` gate** (a reverted batch must not read as a healthy
  all-invalid one).
- **"It type-checks" is NEVER acceptance**, the project-wide rule in its offchain form: every
  success criterion below is a passing test, an observed live RPC result, or an observed
  failure — never "it builds."

## Phases

- [x] **Phase 20: Deploy Rig & Source-of-Truth Import** - Bring the plank branch's four deploy scripts, V2 interfaces and notes onto `feat/rpc-api` by import (never re-typed), stand the full contract set up on a local anvil, and capture addresses + selectors + topic0s into one rig manifest the drivers consume (RIG-01) (completed 2026-07-31)
- [x] **Phase 21: V2 ABI Re-Pin & targetVega Generation** - Re-pin `VolOrder/{Types,Encoding,Decode,Rpc}.hs` to the V2 4-arg ABI across all four byte layouts, kill the stale topic0 with a signature-derived pin test, carry `target_vega` end-to-end, and draw it per order in raw L units (RPIN-01..06, VEGA-01) (completed 2026-08-01)
- [x] **Phase 22: Live Stochastic Drivers** - Both drivers run end-to-end against the rig: price diffusion writing timepoints (E3 per step) and Poisson V2 VolOrder creation single + batch, with preview/readback consistency including targetVega and E1 v2 observed under the pinned topic0 (DRIV-01, DRIV-02) (completed 2026-08-02)

## Phase Details

### Phase 20: Deploy Rig & Source-of-Truth Import
**Goal**: The full V2 contract set is standing on a local anvil and every address, selector and event topic0 the drivers need exists in ONE place on this branch, traceable to the interface file it came from — so no later phase has to guess at, or re-type, a value that lives on another branch.
**Depends on**: Nothing new (first v5.0 phase). Consumes the plank workstream's artifacts at **`origin/develop` @ `9f5ccba9…`** (recorded on disk at `offchain/rig/import-ref.txt`). **CORRECTED at 20-01/20-02:** this line and SC-1 below originally named `origin/feat/plank` @ `df7088f`; PR #15 merged `feat/plank` into `develop` at 2026-07-31 18:17 UTC, and the 20-CONTEXT locked decision pins the import to the recorded `develop` ref. The df7088f wording is SUPERSEDED — content is identical (all 14 binding-path sha256 prefixes measured on df7088f match the develop ref), but the ref actually imported and verified against is `9f5ccba9…`.
**Requirements**: RIG-01
**Success Criteria** (what must be TRUE):
  1. The binding artifacts are present on `feat/rpc-api` with content **identical to the RECORDED ref `origin/develop` @ `9f5ccba9…`** (per `offchain/rig/import-ref.txt`; supersedes the original `origin/feat/plank` @ `df7088f` wording — see "Depends on" above), verified by a content comparison (`git diff` / sha256 against that ref) rather than by inspection: the five `foundry-scripts/deploy/` files (`PlankDeployBase.s.sol`, `DeployVolOrderManagerMod`, `DeployRealizedVolatilityMod`, `DeployDynamicFeeMod`, `DeployDynamicFeeHook`), the V2 `src/interfaces/<namespace>/*.plk` set, `.planning/rpc-api-volorder-v2-HANDOFF.md`, `notes/DATA_CONTRACT.md`, `notes/UNITS_AND_SCALES.md`. **Imported, never re-typed**, and not edited on this branch — a diff against the plank ref is the acceptance test, and it is what makes "consume, do not re-derive" checkable rather than aspirational. The now-superseded v1 `VolOrderManagerInterface.plk` (`0x6501fe94`) is replaced, not kept alongside (RIG-01).
  2. All four deploy scripts RUN to completion against a fresh local anvil, each printing its deployed address, and each deployed contract is proven LIVE by a read that could not pass against an empty address — not by the script's exit code: `orderCount()` answers on VolOrderManagerMod, and RealizedVolatilityMod (seeded via `INIT_TS`/`INIT_TICK`) returns a NONZERO packed timepoint at its seeded index. A script that "succeeds" while deploying zero-length bytecode is the known silent-failure mode of this FFI path (RIG-01).
  3. The printed addresses, selectors and event topic0s are captured into a SINGLE machine-readable rig manifest consumed by the Haskell drivers, and **no address, selector or topic0 is hardcoded anywhere else under `offchain/`** — asserted by a grep-style check, so the manifest cannot be quietly bypassed the way `Sample.hs`'s literals are today (RIG-01).
  4. Every selector and topic0 in the manifest is **recomputed in a test from the signature string** in the corresponding `src/interfaces/<namespace>/*.plk` file and matched — a consumption check, not a re-derivation: `create_order(uint88,uint24,uint16,uint96)` → `0x98d950ec`, `create_orders(uint256,uint256[])` → `0x81357911`, `writeTimepoint(uint32,int24)` → `0xb09b2297`, E1 v2 → `0x18bd4d46…`, E3 `TimepointWritten` → `0x44d3c76a…`. If a manifest value and its interface file disagree, the check FAILS (RIG-01).
  5. The whole rig is reproducible on a clean machine from one documented command sequence starting at a fresh anvil, and a second run from scratch produces the same contract set (RIG-01).
**Plans**: 5 plans in 4 waves

Plans:
- [x] 20-01-PLAN.md — Upstream gate (BLOCKING), npm/submodule preflight, cold pre-import forge + plank baselines [wave 1]
- [x] 20-02-PLAN.md — Import the 36 binding paths + transitive .plk closure from the recorded develop ref, pin sha256 provenance, prove the closure compiles, record the forge delta [wave 2]
- [x] 20-03-PLAN.md — deploy-rig.sh (owns anvil, 5 scripts, manifest from broadcast JSON + console cross-check), verify-rig.sh liveness probes, SC-5 double-run reproducibility [wave 3]
- [x] 20-04-PLAN.md — generate-pins.sh + committed rig-pins.json (generated from the imported interface files), Rig.Manifest aeson loader, cabal wiring [wave 3]
- [x] 20-05-PLAN.md — Literal purge into the manifest, SC-3/SC-4 cabal test-suite (keccak recomputation + falsifiability), the documented one-command sequence [wave 4]

### Phase 21: V2 ABI Re-Pin & targetVega Generation
**Goal**: The Haskell client speaks V2 on every byte layout that crosses the wire — call, batch input word, storage word, and log — with each selector and topic0 pinned by a test that COMPUTES it from the signature string, so this surface cannot rot silently again; and `StochasticOrderGen` supplies the fourth field in the right units.
**Depends on**: Phase 20. Not for the layouts (those come from the interface files), but because **RPIN-05 must verify against the LIVE module** — the requirement says verify, don't assume from the handoff, and that needs a deployed V2 `create_orders` to call.
**Requirements**: RPIN-01, RPIN-02, RPIN-03, RPIN-04, RPIN-05, RPIN-06, VEGA-01
**Success Criteria** (what must be TRUE):
  1. `encode_create_order` emits V2 calldata whose leading 4 bytes equal `0x98d950ec` **and** equal `keccak("create_order(uint88,uint24,uint16,uint96)")[0:4]` computed IN THE TEST from the signature string — the pin is DERIVED, never a transcribed literal. Its four argument words decode back to `(strike, width, skew, targetVega)` in that order (RPIN-01).
  2. Both bit layouts are correct and demonstrably DISTINCT from each other. **Input word** (`pack_vol_order_input`): `skew@0..15 | strike@16..103 | width@104..127 | targetVega@128..223`, bits ≥ 224 zero BY CONSTRUCTION, with strict field-width validation on all four fields — each rejecting its own out-of-range value with an attributable message rather than OR-ing silently into a neighbour. Note `width` is now an INTERIOR/masked field (in v1 it was the top field and deliberately left unmasked for on-chain dirty-bit rejection); `targetVega` is now the unmasked TOP field and inherits that role. **Storage word** (`unpack_vol_order_storage`, 248-bit): `skew@0 | strike@16 | tickSpacing@104 (read, discarded) | width@128 | targetVega@152..247`. Round-trip holds over a constructed field-boundary corpus, and at least one order is exhibited whose input word ≠ its storage word — so the two layouts can never be conflated by a passing test (RPIN-02, RPIN-03).
  3. `decode_order_created` accepts E1 v2 — `VolOrderCreated(uint256 indexed orderId, uint88 strike, uint24 width, uint16 skew, uint96 targetVega)`, topic0 `0x18bd4d46…` **computed in the test from the signature string**, data = 4 words, `orderId` read from the indexed topic. Both retired topic0s are REJECTED by the decoder, and the pin test is shown FALSIFIABLE by observing it go RED when the constant is set to the stale `0xa8892769…` — the bug this requirement exists to fix must be demonstrated caught, not merely overwritten (RPIN-04).
  4. `decode_create_orders_result` is verified byte-unchanged against a `(bool, uint256)[]` return **captured from the live Phase-20 module** by a real batch call — not from the handoff text, not from v4.0's fixture alone — including the `N = 0` case at exactly 64 bytes. If the live bytes disagree with the v4.0 golden fixture, that is a FINDING to report, not something to paper over (RPIN-05).
  5. `target_vega` flows end-to-end: the `VolOrder` record carries it; `encode_create_order`, `encode_create_orders`, the storage readback and the mined-order content check all include it — a mined order whose targetVega differs from the submitted one FAILS the readback check (proven by feeding a deliberately mismatched value and observing the failure, so the new field is genuinely compared and not merely carried). `StochasticOrderGen` draws a targetVega per order in **raw LIQUIDITY units**, with `[1, 2^96−1]` and the 1e18–1e21 realistic band asserted over the generator's output (RPIN-06, VEGA-01).
**Plans**: 5 plans in 4 waves

Plans:
- [x] 21-01-PLAN.md — V2 record + V2 calldata encoder + V2 input word + V2 storage unpack, V1 deleted; RPIN-01/02/03 checks [wave 1]
- [x] 21-02-PLAN.md — capture-batch-return.sh + committed provenance-bearing capture off the LIVE rig (the only chain-touching work) [wave 1]
- [x] 21-03-PLAN.md — E1 v2 decoder rewrite (2 topics, 4 data words) + Report.hs; stale-topic0 and perturbed-targetVega observed-RED demos [wave 2]
- [x] 21-04-PLAN.md — VegaDraw = LogUniform[1e18, 1e21] + draw_target_vega guard + OrderShape + generator wiring; fixed-seed band checks [wave 3]
- [x] 21-05-PLAN.md — RPIN-05 assertions over the capture (suite stays chain-independent) + peer-bytes artifact + cross-track findings + phase gate [wave 4]

### Phase 22: Live Stochastic Drivers
**Goal**: Both drivers run end-to-end against the live rig under the V2 ABI and produce the real event set — the milestone's acceptance bar, and the input the queued v6.0 subgraph will index.
**Depends on**: Phase 20 (the rig they drive) and Phase 21 (the V2 ABI the order driver speaks).
**Requirements**: DRIV-01, DRIV-02
**Success Criteria** (what must be TRUE):
  1. **MECHANISM SUPERSEDED at plan time (2026-08-02, 22-CONTEXT locked decision) — the required OUTCOME below is UNCHANGED.** The original wording was: "A stochastic price path drives `RealizedVolatilityMod.writeTimepoint(uint32,int24)` (`0xb09b2297`) once per step against the rig-deployed module." That is exactly the offchain intervention the user does NOT want. The hook SELF-WRITES: `DynamicFeeHook.beforeSwap` (`src/modules/protocol_integrations/DynamicFeeHook.plk:129`) calls `rv_write_timepoint` on the pre-swap tick it reads via `extsload`. The driver's job is to make the hook FIRE — cheat slot0 to the desired tick, advance the clock, send a minimal swap — and then OBSERVE E3. There is NO offchain `writeTimepoint` client; the pin and selector stay in `rig-pins.json` and stay checked, they are simply never called. The roadmap's "focused research pass on the E3 side" flag is CANCELLED by this decision. **The outcome required is unchanged:** a stochastic price path produces one E3 per step against the rig. Every step's receipt has `receiptStatus == 1` and carries exactly ONE E3 `TimepointWritten` log under topic0 `0x44d3c76a…`, whose decoded `(timestamp, tick)` equals the step the driver submitted. The existing `write_price` / PriceSetterHook flow still runs unchanged — this driver is ADDED beside it, not a replacement (DRIV-01).
  2. Stochastic V2 VolOrder creation runs SINGLE against the rig: a `create_order` receipt with status 1, one E1 v2 log under the pinned topic0, whose four decoded data words equal the submitted `(strike, width, skew, targetVega)`, and a **receipt-block-pinned** `getOrderPacked` readback that unpacks to the submitted order including its targetVega (DRIV-02).
  3. Stochastic V2 VolOrder creation runs BATCH against the rig: a live batch returns `(True, id)` entries positionally matching the preview's success PATTERN; `orderCount` moves by exactly the success count; and every mined id's receipt-block-pinned `getOrderPacked` readback content-matches its submitted order **including targetVega**. A mixed batch (at least one contract-rejected tuple) is exercised, so best-effort skip semantics are observed live rather than assumed. Any mismatch is reported with the tx hash — never silently (DRIV-02).
  4. A **zero-arrival Poisson tick (`N = 0`) completes cleanly against the live rig** — the 64-byte empty return decodes to an empty result list, not a decode failure and not a crash. This is carried directly from v4.0's exit record, which named it "the single clause in the return contract most likely to break `StochasticOrderGen`"; it is invisible on-chain and can only be caught here, and a zero-arrival tick is an in-distribution Poisson sample, not a client bug (DRIV-02).
  5. Both drivers run from one documented command against a fresh Phase-20 rig, and the run is reproducible from a RECORDED seed — a driver whose failures cannot be replayed is not debuggable, and the v6.0 subgraph will need a reproducible event stream to index against (DRIV-01, DRIV-02).
**Plans**: 6 plans in 5 waves

Plans:
- [x] 22-01-PLAN.md — Re-import + re-pin 37 paths to `origin/develop @ 2039f27`; upstream gate names `InitSwappableRig.s.sol`; the two vendored v4-core routers PROVEN to compile under `--via-ir` [wave 1]
- [x] 22-02-PLAN.md — The pure offchain surface: E3/E5 decoders with signed int24/int56 decoding (none exists anywhere in `offchain/` today), slot0 word composition, `cast`-shelled extsload + swap calldata [wave 1]
- [x] 22-03-PLAN.md — Swappable rig: `deploy-rig.sh` 6th step (`InitSwappableRig`), `anvil --timestamp`, nine manifest contracts, router binding probes, SC-5 re-measured, README's three stale spots fixed [wave 2]
- [x] 22-04-PLAN.md — THE BLOCKER DISCHARGE: `cheat_and_swap`, and an OBSERVED E3 carrying a non-zero cheated tick — plus the wrong-pool counter-measurement and the G1 same-second no-op, committed as evidence [wave 3]
- [x] 22-05-PLAN.md — DRIV-01: `run_cheat_swap_path` + seeded RNG (`RIG_SEED`) + `driver-run-capture.json` with flush-on-failure; SC-1 asserted by value offline [wave 4]
- [x] 22-06-PLAN.md — DRIV-02: single / MIXED batch (`skew = 65535`) / direct `create_orders _ _ []`; SC-2/3/4 checks; SC-5 seed replay; the documented command and the phase gate [wave 5]

## Progress (Milestone v5.0)

**Execution Order:** Strictly sequential: 20 → 21 → 22. The rig comes first because it is the only thing that can make RPIN-05's "verify against the live module" satisfiable, and because every source-of-truth file the other two phases read is imported by it. The re-pin precedes the drivers so that a live driver failure is never confounded with a layout bug.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 20. Deploy Rig & Source-of-Truth Import | 5/5 | Complete    | 2026-07-31 |
| 21. V2 ABI Re-Pin & targetVega Generation | 5/5 | Complete    | 2026-08-01 |
| 22. Live Stochastic Drivers | 6/6 | Complete    | 2026-08-02 |

## Coverage (Milestone v5.0)

| Phase | Requirements | Count |
|-------|--------------|-------|
| 20 | RIG-01 | 1 |
| 21 | RPIN-01, RPIN-02, RPIN-03, RPIN-04, RPIN-05, RPIN-06, VEGA-01 | 7 |
| 22 | DRIV-01, DRIV-02 | 2 |

**Total mapped: 10/10** — no orphans, no duplicates.

**ID collision — RESOLVED at roadmap approval (2026-07-31):** the deferred v2 "formal
literature review deliverable" was renamed `LIT-01` in `REQUIREMENTS.md`; `RIG-01` now
uniquely means this milestone's deploy rig.

## Research Flags (Milestone v5.0)

- **Phase 20 — coordination + environment, not a research gap.** The four scripts and their
  `PlankDeployBase` already exist and are the plank workstream's deliverable. The open question
  at plan time is mechanical: how to bring them onto `feat/rpc-api` (cherry-pick, merge, or
  subtree checkout) without dragging the rest of the plank branch. Decide it at plan time and
  record the choice; do not re-author the scripts.
- **Phase 21 — skip research on the layouts, they are GIVEN.** All four byte layouts, both
  selectors and the E1 v2 topic0 are pinned in the interface file and the handoff. Re-deriving
  any of them is explicitly forbidden. The one genuine unknown is the `-Wall`-clean shape of the
  `VolOrder` record change across its five dependent modules — a mechanical refactor, sized at
  plan time.
- **Phase 22 — CLOSED at plan time (2026-08-02). The flag as written is SUPERSEDED.** It asked for
  a focused pass on building a `writeTimepoint` client; the user's locked architecture decision
  cancels that client entirely (see the SC-1 note above). `22-RESEARCH.md` was produced instead and
  found the phase's highest-severity item, which the flag could not have anticipated:
  **`write_price` cheats the WRONG pool.** `PriceSetterHookScript` stands up a SECOND `PoolManager`
  (manifest `PriceSetterPoolManager`) and binds `PriceSetterHook` to a pool there, while
  `DynamicFeeHook` lives on a different manager — so cheat-then-swap writes one pool and swaps
  another, and fails SILENTLY (E3 still fires, status 1, only the tick is wrong). The fix is
  entirely inside `offchain/`: compose the slot0 word from
  `PoolManager.extsload(keccak(poolId‖6))` OR-ed with `PriceSetterHook.packSlot0For(tick)` masked
  at bit 184. Plan 22-04 discharges it by MEASUREMENT before any loop is built on it. The
  `INIT_TS` observation still holds but is now about the CHAIN clock, not a `uint32` argument: the
  hook's buffer is seeded at `block.timestamp`, so `deploy-rig.sh` passes `anvil --timestamp
  "$INIT_TS"` to give both series one origin. The E1/batch side needs no research — Phase 21
  delivered it — but two roadmap success criteria are unreachable through `run_order_gen` and need
  direct calls (a zero-arrival tick sends nothing, `chunk _ [] = []`; and every generated shape is
  valid so no batch is ever mixed).

## Scope Boundary (Milestone v5.0)

Offchain client + drivers only. Explicitly OUT: the **v6.0 subgraph** (issue #14 — it consumes
the event stream this milestone generates, and is sequenced behind it); **E2 `PortafolioMinted`
decode** (the event is not shipped on-chain, so there is nothing to decode against);
**re-deriving any selector, topic0 or bit layout** (forbidden by the handoff — consume the
interface files); **replacing the legacy `write_price` driver** (it stays available and
unchanged); **any edit to `src/` Plank sources or the deploy scripts** (plank workstream's
files — this branch imports and consumes them, and a local edit would silently fork the source
of truth); and **PR #9 merge mechanics** (a separate human-approval gate).

**Carried from v4.0's exit record, and now live consumer contracts rather than test details:**
the batch's **canonical array offset `0x40` at byte 36** is a HARD encoding requirement (a
legally-padded head is rejected with an empty revert); **`N = 0` returns exactly 64 bytes**, not
0 and not 32; and **success words are canonically 0 or 1** (a lenient decoder that accepts a
truthy 2 would silently disagree with `abi.decode` about the same bytes). The shipped
`decode_create_orders_result` already enforces the last of these — RPIN-05 confirms it against
the live V2 module rather than re-litigating it.

---

# Milestone v6.0 — Model Output Store + VolumePath Bridge (rpc_api workstream)

## Overview

A Postgres/JSONB **keyed store for model outputs** whose key is the shock that produced them,
so an identical shock skips the solve and a re-solve that disagrees is caught — and, on top of
it, the issue #25 bridge that carries a live Anvil `next` event through the GAMS VolumePath
prover to the fixture the forge test reads.

Source: GitHub issue #25. Binding reference: `model/mev_tax_model_one/VOLUME_PATH.md` (§2 the
seven inputs, §3 the output shape and determinism guarantee, §4 every abort named and gated on
exit code, never log text). **Consume, do not re-derive.** Working branch `feat/rpc-api`; the
code under change is `offchain/` (Haskell). The only thing written into `test/` is one fixture
file.

Phase numbering continues at **23** (v5.0 ended at 22). Earlier ranges are other tracks —
paused, untouched, never renumbered.

## What changed from the six phases approved in brainstorm — and why

The approved shape was: (1) Postgres foundation + Haskell client, (2) keyed store, (3) GAMS
invocation, (4) Anvil read layer, (5) fee splitter, (6) resident loop + publication. **Still six
phases, same six bodies of work.** Research found ordering defects; three things moved.

| # | Change | Why |
|---|---|---|
| **1** | **GAMS invocation moved from 3rd to 2nd — ahead of the store.** | The key contains the GAMS and CONOPT versions (KEY-01), so GAMS-03/GAMS-04 are a **prerequisite** of STORE-01, not a later phase. An emptily-succeeding detector (`"" == ""`, this repo's defect #1, verbatim) poisons every row written before it is fixed, and the poisoned rows are indistinguishable afterwards unless the version was also stored in its own column. Sequencing the detector after the first production write makes the recovery cost MEDIUM–HIGH instead of zero. |
| **2** | **Byte-exactness and `key_scheme` moved INTO the earliest schema phase (23), out of the store phase.** | BYTE-01/02/05 are schema decisions (`bytea` authoritative, `jsonb` derived, the `Binary` newtype), and KEY-07 is literally a column inside a unique constraint. Every later phase consumes them and each is expensive to retrofit: an artifact stored only in `jsonb` is unrecoverable as bytes, and a key-formula change without `key_scheme` is a full-table rebuild with no way to identify affected rows. Phase 23 is therefore **not plumbing** — it owns the milestone's headline guarantee. |
| **3** | **Fee splitter and Anvil read layer swapped (5th ↔ 4th), and CHAIN-04 pulled OUT of the Anvil phase into the fee-splitter phase.** | Consequence of the hard blocking constraint, not a preference. The Anvil phase is BLOCKED on the plank worktree emitting `next` (`SELECTOR_NEXT` is a stub today, issue #26); the fee splitter is not. Putting the unblocked phase first makes phases 23–26 a contiguous chain-free block. CHAIN-04 is explicitly *not* blocked — decoding is exercised against synthetic logs, a pattern the suite already uses for the Phase 21 event re-pin — so it belongs with the unblocked work, beside the other pure producer of shock fields. |

**Unchanged and load-bearing:** the byte-reproduction proof — this milestone's headline
falsifiable claim — lands at the end of **Phase 25, with no chain and no upstream**. The shock
is seven values and can be supplied by hand. If the plank block persists indefinitely, phases
23–26 still deliver the store, the prover integration, the determinism check and the fee
splitter as a complete, verified subsystem.

## Binding domain constraints — copied here so no phase re-derives them

- **`jsonb` cannot carry a byte-identity guarantee, and `PROJECT.md` as written asked it to.**
  MEASURED on PG 18/18.4 against the real §3 output shape: the `jsonb` round trip reorders every
  key and the two sha256s differ (`4075758e…` vs `dd8a3e26…`). `bytea` is authoritative;
  `jsonb` is a derived projection for querying only. A determinism check reading `jsonb` tests
  **Postgres's normalizer, not GAMS**.
- **aeson's `decode → encode` is NOT the identity** at GHC 9.10.3 — measured, four mutations in
  one round-trip including `0.00318353 → 3.18353e-3` (aeson *introduces* exponent notation).
  aeson and `jsonb` normalize in **opposite directions**, so three mutually incompatible
  canonical forms sit between the solver and the forge test. The prover's bytes pass through
  `Data.Aeson.Value` nowhere. This rules out reusing `Driver.Capture.write_json_atomically` on
  the publication path.
- **`dQx`/`dQM` as `[Double]` loses 32 wei on the first element** — measured. The forge test
  would execute the wrong amounts. `[Integer]` is exact. Non-negotiable.
- **Exit code `0` means "GAMS ran", not "the model solved"** (GAMS's own docs). §4's exit-code
  gate is a property of `volume_path.gms`'s abort coverage, not of GAMS — and that file is under
  active development in another worktree. Exit 0 is the FIRST conjunct, never the only one; the
  supplement is **absence of the output artifact**, which is not log text.
- **`ToField ByteString` sends a quoted text literal, not `bytea`.** The `Binary` newtype is
  required and **nothing complains at compile time**.
- **`postgresql-migration` exits 0 on a checksum mismatch** — it returns `MigrationError` and
  the process still exits 0. The caller must pattern-match and `exitFailure`.
- **Polling is FORCED, not chosen.** `eth_subscribe` is absent from the `hs-web3` Eth API and
  `jsonrpc-tinyclient` is structurally request/response. The loop is a watermark-driven fold
  over closed `[b, b]` ranges. `newFilter`/`getFilterChanges` is rejected: node-side state with
  its own expiry, returning "changes since last poll" — un-pinnable and un-replayable.
- **`ExceptT` over `Web3` is REJECTED.** `runWeb3'` catches only `Web3Error`, which
  `web3-ethereum` **never constructs** (0 occurrences in `src/`); real failures throw
  `JsonRpcException` or `IOException`. Its `Left` branch is unreachable and the handlers at
  `offchain/app/Main.hs:235` and `offchain/lib/VolOrder/Rpc.hs:279` are dead code. Adding
  `ExceptT` would advertise a guarantee the runtime does not provide — the exact
  advertised-but-dead class `every_advertised_override_is_honoured` already guards against.
- **No Postgres server on this machine** (`psql` yes; `postgres`/`initdb`/`pg_ctl` no). Docker
  works; `postgres:18-alpine` ready in 3 seconds. **Postgres is never a `cabal test` dependency** —
  three tiers, with the conformance verdicts committed as evidence.
- **The `haskell` gate job has NEVER executed** (v5.0 merged `--admin`). Its first run debuts
  both the gate and the Postgres wiring.
- **"It type-checks" is NEVER acceptance.** Every success criterion below is a passing test, an
  observed failure, or an observed live result — never "it builds", and never "the suite is
  green" (a suite that skips is also green).

## The one defect class every criterion below is written against

> **A guard that passes must have *read information*. A comparand that is empty, zero,
> defaulted, absent, or derived from its own comparison target proves nothing.**

Found six times across three review rounds, each after the previous sweep was declared complete:
`"" == ""`, `tickSpacing = 0`, a count-preserving rename defeating a count floor, an empty ref
file, a CI `grep -q` over an empty log, and `0x00…00` passing every hex-shape guard. Plus a
seventh: a recorded field derived from the same expression as the thing it would be checked
against, making the assertion a tautology.

This milestone hands that class **five brand-new representations it has never worn**: a content
hash (`H("")`); a version string (`""` from a failed parse); a subprocess exit code (`0` because
GAMS *ran*); a determinism check (`bytes == bytes` where both sides came from the same cached
row); and a DB-backed test that is green because it **skipped**. Every criterion below is
therefore stated as something that can FAIL — "X is rejected", "Y aborts when absent", "the
mutant Z is OBSERVED caught" — never as "the tests pass".

## Phases

- [x] **Phase 23: Postgres Foundation & the Byte-Exact Schema** - The schema that returns the bytes it was given, migrations that fail loudly, `key_scheme` inside the unique constraint, and a suite that goes RED rather than skipping when its subject is absent (DB-01..04, BYTE-01, BYTE-02, BYTE-03, BYTE-05, KEY-07) (completed 2026-08-16)
- [x] **Phase 24: GAMS Invocation & Toolchain Identity** - The prover as a controlled subprocess gated on evidence not log text, with version detection that aborts rather than yielding an empty key component — landed BEFORE the store's first production write (GAMS-01..06, BYTE-04) (completed 2026-08-17)
- [x] **Phase 25: The Content Key & Keyed Store** - Framed, edge-normalized keys that refuse to be built from an absent input; cache elision, abort safety and a scoped reset the solve path cannot name — chain-free (KEY-01..06, STORE-01, STORE-06, STORE-08) (completed 2026-08-17). **SCOPE CUT 2026-08-17, user ruling:** on-demand verification, quarantine, pinning and the append-only run log — **STORE-02, STORE-03, STORE-04, STORE-05, STORE-07** — are DEFERRED to a later milestone, not dropped, each with a written reason in `REQUIREMENTS.md`'s Store deferral block. The byte-reproduction proof they carried is deferred with them; what lands here is the bridge's cache.
- [x] **Phase 26: Shock Assembly — Fee Split & Event Decode** - The two pure producers of a shock's fields: the closed-form splitter that refuses infeasibility before the solver is spawned, and the `next` decoder proven against synthetic logs before the event exists (FEE-01..04, CHAIN-04) (completed 2026-08-17)
- [x] **Phase 27: Anvil Read Layer** - A shock read off a live chain is a snapshot of ONE block or it is an error (CHAIN-02, CHAIN-03, CHAIN-05, CHAIN-06, CHAIN-07 shipped; CHAIN-04 landed at 26-02) (completed 2026-08-22). **CHAIN-01 alone remains BLOCKED** on the plank / mev-migrate worktree emitting a mined `Shock` (issue #26, `SELECTOR_NEXT 0xd3827b0b`) — recorded by name in `27-SUMMARY.md` with what would discharge it. **TEXT CORRECTED AT CLOSE:** this line read "**BLOCKED** … (CHAIN-01, CHAIN-02, CHAIN-03)", which was wrong twice — CHAIN-02 and CHAIN-03 were never blocked (a pinned read needs a POOL, and `deploy-rig.sh` has stood one up since 22-03; the status was inherited from CHAIN-01's row rather than measured), and the phase also carried CHAIN-05, CHAIN-06 and CHAIN-07.
- [x] **Phase 28: Resident Loop & Fixture Publication** - A loop that survives its own crash, never double-counts an event, and publishes one file the forge test can never observe half-written — **COMPLETE 2026-08-23, chain-free; the LIVE half of all five requirements is BLOCKED on issue #26 (no deployable `Shock` emitter) and issues #24/#25 (the publication directory is on neither tree)** (LOOP-01..05)

## Phase Details

### Phase 23: Postgres Foundation & the Byte-Exact Schema
**Goal**: A migrated Postgres schema whose artifact column returns exactly the bytes it was
given, and a test suite that goes RED — never green, never skipped — when the database or its
committed evidence is absent. This phase owns the milestone's headline guarantee; phases 24–28
consume it and every decision here is expensive to retrofit.
**Depends on**: Nothing (first v6.0 phase).
**Requirements**: DB-01, DB-02, DB-03, DB-04, BYTE-01, BYTE-02, BYTE-03, BYTE-05, KEY-07
**Success Criteria** (what must be TRUE):
  1. An adversarial byte corpus — containing `0x00`, `0xFF`, invalid UTF-8, a CRLF and a trailing newline — round-trips through the store **byte-identically**, verified by hashing on the way in and on the way out; and the same corpus sent as a bare `ByteString` instead of through the `Binary` newtype is OBSERVED to fail that round-trip. A guard that has never been seen to reject is the empty-log `grep -q` finding again (BYTE-01, BYTE-05).
  2. The `bytea` column is authoritative and `jsonb` is derived, each half demonstrated by the case that would break it: a `jsonb` round-trip of the real `volume_path.json` shape is exhibited FAILING a sha256 comparison; a check reddens if any identity comparison reads the `jsonb` column; and `Data.Aeson.Value` is absent from the storage path, asserted by a check that fails when an `encode`/`toJSON` is introduced onto it. The aeson `0.00318353 → 3.18353e-3` mutation is re-measured here, not cited (BYTE-02, BYTE-03).
  3. Migrations are applied by an explicit command, run twice from a **completely empty** database (which `git clean -ffdx` makes CI's normal case) and concurrently by two migrators with only one applying; a **deliberately corrupted checksum makes the command exit NON-ZERO** — observed, because `postgresql-migration` returns the error and still exits 0 (DB-01).
  4. A row written under a superseded `key_scheme` is OBSERVED to be **orphaned** — never returned by a lookup under the current scheme, never silently matched — proving the unique constraint is `(model, key_scheme, key)` and that a future key-formula change is additive rather than corrupting (KEY-07).
  5. `cabal test` passes with **no database present** and the store checks still discriminate: with `CFMM_REQUIRE_DB=1` and no database reachable the suite is **RED**, naming the missing prerequisite; a sentinel store deliberately wired wrong is caught; the law **SET** (not a floor — "a floor of thirty is satisfied by thirty pins of which one has been swapped") fails when a law is renamed away; a count floor on executed store checks fails on skip-inflation; and `PGSTORE_DSN`/`STORE_CONFORMANCE` resolve from the environment with no credential in a tracked file, each registered in `advertised_overrides` with the consumer proven to fail loudly naming the path (DB-02, DB-03, DB-04).
**Plans**: 5 plans (5 waves — a genuine serial chain: every plan but the first edits
`offchain/test/Main.hs`, and each consumes the previous plan's artifact)

Plans:
- [x] 23-01-PLAN.md — The store contract: `.cabal` deps, `Store.{Types,Config,Class,Memory}`, the
  adversarial corpus with its measured behaviour tags, and `DerivedDoc` made uncomparable at the
  type level (BYTE-02, BYTE-05, DB-02) [wave 1]
- [x] 23-02-PLAN.md — `Store.Laws` executing for real against `Store.Memory` inside `cabal test`;
  the law SET asserted in both directions; the corpus behaviour SET; BYTE-03's two aeson guards
  (DB-03, BYTE-03, BYTE-05, KEY-07) [wave 2]
- [x] 23-03-PLAN.md — The two migration `.sql` files with the `(model, key_scheme, key)`
  constraint, the pure migration manifest, `Store.Postgres` (the sole `postgresql-simple`
  importer, `Binary`-only writes, `pg_advisory_lock`, `exitFailure`), and the three
  `sc3_literal_purge` constants moved in the SAME task (DB-01, KEY-07, BYTE-01..03) [wave 3]
- [x] 23-04-PLAN.md — The capture executable + Docker script + the real 606-byte golden bytes;
  every DB-only guard DRIVEN and recorded in the committed `store-conformance.json`
  (DB-01, DB-04, BYTE-01, BYTE-02, BYTE-05, KEY-07) [wave 4]
- [x] 23-05-PLAN.md — Ten Tier-C checks making the artifact load-bearing, the computed freshness
  oracle, two new `advertised_overrides` probes, the fifth swept artifact and the re-MEASURED
  sentinel floors (DB-02, DB-03, DB-04, BYTE-01, BYTE-02, BYTE-05, KEY-07) [wave 5]

**Three planning-time corrections to the criteria above, from `23-RESEARCH.md`'s measurements.
These are deviations of record, not drift:**

1. **SC-1's corpus is inadequate and is EXTENDED.** MEASURED on PG 18.4: of the five members SC-1
   names, `0x00`/`0xFF`/invalid UTF-8 raise a LOUD `SqlError` (a shape indistinguishable from a
   dead connection) and CRLF/trailing-newline **round-trip correctly through the broken path** and
   prove nothing. The only input that produces the failure the requirement is about — a wrong
   value returned with no complaint — is `a\101b`: 6 bytes in, 3 bytes out, no error. It is added
   to the corpus, and the assertion is on **length and digest**, never on "an exception was thrown".
2. **SC-3's concurrency criterion is not delivered by the library.** `postgresql-migration`
   0.2.1.8 contains **no advisory lock** (source-read: `checkScript` is a bare `SELECT`, zero
   `advisory` hits). It is implemented as `pg_advisory_lock(872304)` in `Store.Postgres`.
3. **SC-5's `CFMM_REQUIRE_DB=1` mechanism is REPLACED.** It fails open — a drifted CI `env:` block
   silently restores skip-mode, which is `RIG_MANIFEST` advertised-and-dead one layer up. It is
   RELOCATED to the capture script (where it means "refuse to emit an artifact at all"), and
   `cabal test`'s discrimination comes instead from a structural guarantee that no check opens a
   socket, `store_laws` against `Store.Memory`, the law SET asserted in BOTH directions, and a
   **computed** freshness oracle that recomputes the migration digests from the repo's own `.sql`
   files. The other SC-5 clauses are adopted unchanged.

**Also of record:** adding the first `.sql` file under `offchain/` reddens `sc3_literal_purge`
immediately (`purge_file_floor = 36` against exactly 36 scanned files, zero slack; the extension
census is exactly the five present types). Plan 23-03 moves all three constants in the same task
as the migrations. And `.github/` belongs to the CI track — no CI change is needed, because under
the three-tier decision nothing in `cabal test` touches a database.

### Phase 24: GAMS Invocation & Toolchain Identity
**Goal**: The prover runs as a controlled subprocess whose success is decided by evidence rather
than log text, and the toolchain versions the content key depends on are either read for real or
the run aborts. Sequenced **before** the store so no production row can be written under a key
component that a broken detector silently emptied.
**Depends on**: Phase 23 (the run-log table an aborted run lands in; the `Integer`-not-`Double`
artifact discipline). Structurally independent of the store — `Store.Key` takes version *strings*
as arguments, so this phase is a leaf, not a store dependency.
**Requirements**: GAMS-01, GAMS-02, GAMS-03, GAMS-04, GAMS-05, GAMS-06, BYTE-04
**Success Criteria** (what must be TRUE):
  1. A stub that **exits 0 and writes nothing** is REFUSED, and a stub that exits 0 while a valid-looking `volume_path.json` pre-exists at the expected path is REFUSED — the run works in a fresh per-invocation temp directory so the stale file is unreachable. Model-level codes (`2` compile error, `3` `abort$`) are distinguished from environmental ones (licence, disk, missing binary), so an expired licence is never recorded as an infeasibility verdict. No decision anywhere reads solver stdout/stderr; both are captured for diagnosis and labelled non-authoritative in a comment (GAMS-01, GAMS-02).
  2. The version parser REJECTS every member of a garbage battery — `""`, `"\n"`, a help banner, a localised banner, output on stderr rather than stdout — and no `GamsVersion`/`ConoptVersion` value is constructible empty or whitespace-only. Detection that finds nothing **aborts the run**; there is no `fromMaybe "unknown"`, no `<|> pure ""`, no `catch (\_ -> return "")` on the version path. The absolute resolved binary path and a sha256 of the `gams` executable are recorded alongside the version, because that is the one component a wrapper script or `PATH` shadow cannot lie about (GAMS-03).
  3. CONOPT detection is shown to read the **true solver version** (`C O N O P T version 4.39.0`): a case is exhibited in which the adjacent GAMS-side link version and the `.so` filename differ from it, and both wrong candidates are REJECTED. The method that produced the value is recorded, since §4 forbids *gating* on log text and this is key material, not a gate (GAMS-04).
  4. A child that never exits is terminated by the timeout **and reaped** (no orphan process survives, observed), and a child writing >1 MB to stderr completes without deadlock — the pipe hazard is demonstrated closed, not argued. A timed-out run produces an aborted run-log row and never an output row (GAMS-05).
  5. The invocation environment is an explicit whitelist with `LC_ALL=C` and is recorded: a run with a hostile ambient variable set produces byte-identical output to one without, and a run inheriting the environment is OBSERVED to differ. `dQx`/`dQM` decode as `Integer` — a golden vector proves the `[Double]` decode loses exactly **32 wei** on the first element while `[Integer]` is exact, so the check cannot pass under a tolerance (GAMS-06, BYTE-04).
**Plans**: 6 plans (6 waves — a genuine serial chain: every plan edits `offchain/test/Main.hs`
and each consumes the previous plan's modules or artifact, the Phase-23 shape)

Plans:
- [ ] 24-01-PLAN.md — `Gams.{Config,Version,Exit}`: a version unconstructible empty, anchored on
  the banner's JOB NAME; the CONOPT spaced-letter parse rejecting both decoys; the total
  `ExitCode -> Verdict` taxonomy; six Tier-A checks (GAMS-01, GAMS-03, GAMS-04) [wave 1]
- [ ] 24-02-PLAN.md — `Gams.{Argv,Env,Artifact}`: the canonical renderer that decides the bytes,
  the environment whitelist, the `[Integer]` decoder, BYTE-04's golden vector and the aeson scan's
  scope-growth guard; nine Tier-A checks (GAMS-02, GAMS-06, BYTE-04) [wave 2]
- [ ] 24-03-PLAN.md — `Gams.Run`, the one IO edge (fresh exclusive run dir, group-owning timeout,
  drained pipes, `Aborted` carrying no artifact) and five Tier-B stub checks (GAMS-01, GAMS-02)
  [wave 3]
- [ ] 24-04-PLAN.md — the hung GRANDCHILD, the 2 MB stderr flood, the two environment vectors, the
  missing-banner abort, the GAMS-free structural grep and the three override registrations
  (GAMS-03, GAMS-05, GAMS-06) [wave 4]
- [ ] 24-05-PLAN.md — Tier C: `Gams.Invoke`, the capture executable and script, the committed
  `gams-conformance.json`, nine Tier-C checks and the sixth swept artifact with all floors
  re-measured (GAMS-01..06, BYTE-04) [wave 5]
- [ ] 24-06-PLAN.md — migration `003` making an empty version unstorable, the re-captured store
  evidence, and the phase-closing guard ledger (GAMS-03) [wave 6]

**Four planning-time corrections to the criteria above, from `24-RESEARCH.md`'s measurements.
These are deviations of record, not drift:**

1. **SC-4's "aborted run-log row" is not deliverable in this phase and is restated at the TYPE
   level.** `offchain/migrations/` contains `001_model_run.sql` and `002_byte_corpus.sql` and
   nothing else — the append-only run log is STORE-07, mapped to Phase 25. `ProverOutcome` is a
   total sum type whose `Aborted` constructor carries no `Artifact` and has no conversion to one
   (the `DerivedDoc` idiom Phase 23 OBSERVED catching its subject at compile time), so "never an
   output row" is unrepresentable rather than merely untested. Phase 25 persists the row.
2. **SC-5's "a run inheriting the environment is OBSERVED to differ" has no byte-level witness on
   this machine and is restated against the CHILD'S ENVIRONMENT VECTOR.** MEASURED: four hostile
   ambient variables (`GAMSTHREADS=8 GDXCOMPRESS=1 LC_NUMERIC=de_DE.UTF-8 GAMSDIR=/nonexistent`)
   changed nothing, a `curdir` `gamsconfig.yaml` lost to an explicit CLI parameter, and `locale -a`
   offers only `C`, `C.utf8`, `en_US.utf8` and `POSIX` — there is no comma-decimal locale to
   observe a difference with. Writing the criterion against bytes would produce a check satisfiable
   only by inventing a variable that matters. The first half — a hostile ambient variable produces
   byte-identical output — is adopted unchanged and lands in the capture.
3. **The garbage battery's strongest member is REAL captured output, not an invented string.**
   MEASURED: `gams` with NO arguments exits **0** and prints a 1239-byte banner carrying the version
   **three times** — exit 0, non-empty, correctly shaped, WRONG SUBJECT. `gams --version` is parsed
   as an input filename (exit 6). **Stderr is 0 bytes in every mode**, so a stderr-reading detector
   gets `""` always. The discriminator is the banner's JOB NAME (`volume_path.gms` vs `?` vs
   `--version`), which rejects both wrong-subject banners without a denylist.
4. **GAMS-05's test as normally written CANNOT FAIL, and the plan says so.** MEASURED:
   `readProcessWithExitCode` drains 2 MB of stderr and `timeout` reaps a DIRECT child with no
   orphan — but a **grandchild survives at PPID 1**, and GAMS runs CONOPT at `Solvelink=2` as a
   separate process. The stub is therefore a grandchild, `/usr/bin/timeout -k 1` owns the group,
   and the negative control (the same stub surviving a direct-child-only kill) is a required
   observation.

**Also of record:** the artifact bytes are a function of the argv TOKEN — `volume_path.gms:206`
emits `"%sqrtPriceX96%"` VERBATIM, so a leading zero gives exit 0, every §4 gate green, and sha256
`d64a7b32…` instead of the golden `e7b14f38…`. Edge normalization is not key hygiene; it decides
the bytes, and this phase owns the `execve`. `volTgtWad` is a `Scalar` and is NOT token-sensitive
(`28e18` and `2.8e19` are byte-identical). **`volume_path.gms` does not exist in this worktree** —
it lives in the sibling `cfmm-wt/gams` worktree, so `GAMS_MODEL` is mandatory here and the capture
freshness oracle's model half is a named, asserted gap. `volume_path.gms` has **0 `$include`
directives**, VERIFIED at plan time, and the deliverable is the sorted `(path, sha256)` LIST so a
future include is covered without a code change.

### Phase 25: The Content Key & Keyed Store
**Goal**: A key that describes exactly the invocation that ran and refuses to be built from
anything absent, and a store that elides the solve on a hit, reports and preserves a
disagreement, and never records a run that did not complete. **This is where the milestone's
headline falsifiable claim — same inputs + same toolchain → same bytes — is proven, with no
chain and no upstream.**
**Depends on**: Phase 23 (schema, `key_scheme`, byte fidelity) and Phase 24 (validated toolchain
versions — the key cannot be constructed without them, which is the whole reason 24 precedes 25).
**Requirements**: KEY-01, KEY-02, KEY-03, KEY-04, KEY-05, KEY-06, STORE-01, STORE-06, STORE-08

> **SCOPE CUT 2026-08-17 — user ruling. This phase is RE-PLANNED from 9 plans / 28 tasks to 3
> plans / 8 tasks.** STORE-02, STORE-03, STORE-04, STORE-05 and STORE-07 are **DEFERRED** (rationale
> and per-requirement reasons in `REQUIREMENTS.md`). The goal statement and success criteria 4 and 5
> below are the PRE-CUT text and are retained for the record; the clauses covering verification
> modes, quarantine, pinning and the append-only run log **no longer bind this phase**.
>
> What survives: the key (KEY-01..06), **cache elision** (STORE-01 — the requirement the user called
> critical), explicit reset (STORE-06), and **a failed run never becoming a cache entry** (STORE-08).
>
> The nine pre-cut plans are preserved under `plans-precut/` rather than deleted — the reviewer
> findings against them (`25-REVIEW-FINDINGS.md`) stay valid for whoever picks the deferred work up.
>
> Discipline also relaxed on new work: ordinary test practice, no mandatory mutation-and-observed-
> firing per guard, no positive control per absence claim, and **no growth of the sentinel swept-
> artifact set**. Existing shipped infrastructure is untouched — it is green and already paid for.
**Success Criteria** (what must be TRUE):
  1. A crafted pair of **distinct** shocks whose unframed decimal renderings concatenate identically (`"1"‖"23"` vs `"12"‖"3"`) produce **different** keys; and one shock rendered `28e18` and the same shock rendered `28000000000000000000` produce the **same** key. Framing and edge-normalization are each demonstrated by the case that would break them, and no `show`/`printf` on a floating value appears on the key path (`LC_NUMERIC` cannot participate) (KEY-03, KEY-04).
  2. One renderer feeds both the `execve` argv and the hash preimage, proven by reconstructing the argv actually passed to the prover from the stored preimage and comparing — with a mutant that renders the two independently OBSERVED caught. The paired cross-check reads the echoed input fields back out of the **solver's JSON**, not out of the request record, so it is not the tautology. The **pips denominator is in the preimage**: changing it changes every key rather than silently reinterpreting the existing ones (KEY-01, KEY-02, KEY-05).
  3. Every one of the seven inputs has a **negative test**: omitting it, or supplying an unparseable value, makes key construction FAIL naming the field — never `0`, never `""`, never an in-file default silently standing in. The key type carries no `Maybe` and no defaultable field, so `nEvents = 0`, `liquidity = 0` and `sqrtPriceX96 = 0` are refused rather than hashed as shape-valid nothings (KEY-06).
  4. An identical shock returns the stored artifact with the solver **never spawned** — proven by a store whose invoke callback fails the check if it is called at all, not by timing. Verification is a separate explicit mode off the hot path; its two comparands are **distinct newtypes** with `FreshlySolvedBytes` constructible only by the subprocess layer, so comparing a cached row to itself does not type-check. A deliberately corrupted cached row is REPORTED as a determinism failure with a non-zero exit, the original survives, and the divergent bytes are found in **quarantine**. Both sides are asserted non-empty and above a length floor before comparison, so `"" == ""` is unreachable. A determinism-check history with zero rows fails the phase (STORE-01, STORE-02, STORE-03, STORE-04).
  5. A pinned run **survives** `reset`; bare `reset` REFUSES (mandatory scope) and is unreachable as a side effect of a solve or a publish; the run log is append-only and the **same key seen twice yields two log rows** while a single cache entry; and a run that aborts — non-zero exit, timeout, or exit-0-with-no-artifact — produces a run-log row and **no cache entry**, each observed by driving the failure rather than by inspecting the happy path (STORE-05, STORE-06, STORE-07, STORE-08).
**Plans**: 9 plans (9 waves — strictly serial)

**Planning note (three of this phase's own success criteria are UNSOUND as worded; the plans deviate
deliberately and each deviation is stated in the plan that carries it):**
1. **SC-1's framing test cannot fail.** MEASURED: 343 shock tuples through `render_argv`'s token
   form give **0** collisions — every token is `--<literal name>=<digits>` and `-`/`=` are outside
   the digit alphabet, so the `--name=` prefixes are an ACCIDENTAL framing. The same tuples under
   bare-decimal concatenation give **30**. 25-01 points the evidence at the FRAMER, at a named
   bare-decimal negative control, and at the free-form components.
2. **SC-2's "reconstruct the argv actually passed" is most satisfied by the design that makes the
   store useless.** `Gams.Run.spawn_into` puts `curdir=<per-run temp dir>` into `wrapper_argv`, so
   hashing the argv that ran gives a hit rate of exactly zero while passing that check. 25-02 ships
   TWO instruments that fail on OPPOSITE designs: a two-directional token-set assertion and a
   hit-rate observation.
3. **SC-5's append-only run log cannot rest on `REVOKE`.** MEASURED on PG 18.4: after
   `revoke update, delete … from postgres` a superuser UPDATE LANDED and read back `TAMPERED` with
   no error — and the application connects as `postgres`. A `BEFORE UPDATE OR DELETE` row trigger
   refuses it; `truncate` then emptied the table with no error, needing a second
   `BEFORE TRUNCATE … FOR EACH STATEMENT` trigger. 25-03 ships both, and 25-07 OBSERVES all four
   refusals plus the REVOKE no-op as recorded values.

**Serialisation:** every plan edits `offchain/test/Main.hs` and most edit the `.cabal`, both of
which are single-writer surfaces, so the waves are 1..9 in order. Phase 26 also edits `Main.hs` and
is executed serially with respect to this phase.

Plans:
- [ ] 25-01-PLAN.md — `Store.Key`: the netstring framer, the tagged eight-component preimage, and a `KeyIdentity` that refuses an absolute path or an absent CONOPT version (KEY-01, KEY-04, KEY-05) [wave 1]
- [ ] 25-02-PLAN.md — `parse_shock` (KEY-06's omission clause finally has a subject), the argv/preimage token-set assertion and the hit-rate observation (KEY-02, KEY-03, KEY-06) [wave 2]
- [ ] 25-03-PLAN.md — migrations `004_run_log.sql` (both triggers, no FK) and `005_quarantine.sql`, `Store.Schema` extended, the lock probe renumbered to `900_`, and a re-capture (STORE-05, STORE-06, STORE-07) [wave 3]
- [ ] 25-04-PLAN.md — `Store.RunLog` plus the store seam grown by eight operations, implemented by BOTH stores, with the `xmax` discriminator (STORE-01, STORE-05, STORE-06, STORE-07) [wave 4]
- [ ] 25-05-PLAN.md — `Store.Verify`'s two unconstructible-from-each-other newtypes and the `store-admin` entrypoint whose failure is an exit code (STORE-02, STORE-03, STORE-04) [wave 5]
- [ ] 25-06-PLAN.md — `Store.Solver` and `Store.Cache`: the elision pair and four driven aborts behind a positive control that lands (STORE-01, STORE-04, STORE-08) [wave 6]
- [ ] 25-07-PLAN.md — capture blocks A: the append-only refusals, the REVOKE no-op, both triggers in the live catalogue, the `xmax` discrimination (STORE-01, STORE-06, STORE-07) [wave 7]
- [ ] 25-08-PLAN.md — capture blocks B: the quarantine exhibit with its agreement control, the abort-no-entry exhibit, the key round trip (KEY-01, KEY-02, STORE-03, STORE-04, STORE-08) [wave 8]
- [ ] 25-09-PLAN.md — carried guard #21 (`EchoMismatch`) CLOSED, the 50-row guard ledger reconciled, the phase gate measured cold (KEY-02, STORE-02) [wave 9]

### Phase 26: Shock Assembly — Fee Split & Event Decode
**Goal**: The two pure producers of a shock's fields exist and refuse rather than approximate:
the closed-form fee splitter, whose infeasibility is a refusal we explain rather than an exit
code we interpret, and the `next` decoder, proven against synthetic logs before the upstream
event exists. Zero dependencies beyond `base` and the existing decode idiom.
**Depends on**: Nothing structural — but **NOT parallelizable with 23–25**, and the original
"fully parallelizable" claim here was wrong. Every check in this project lives in the single
file `offchain/test/Main.hs`, so two phases editing it concurrently collide and lose work.
**26 executes AFTER 25** (`depends_on_phases: ["25"]` in all four plans), and every phase-26
task gate is expressed as `BASE + N` with `BASE` re-measured at the wave's start rather than
inherited — 25 adds ~56 checks to the same `core_checks`, which would invalidate any absolute
total pinned at plan time. Sequenced here so all chain-free work is contiguous and phases
27–28 carry the entire upstream block.
**Requirements**: FEE-01, FEE-02, FEE-03, FEE-04, CHAIN-04
**Success Criteria** (what must be TRUE):
  1. Over a grid of `(f, δ*)` including boundary points and one pip either side, the produced (φ_X, φ_M) satisfy `(1−φ_X)(1−φ_M) = 1−f` under a **rounding rule pinned in writing**; a rounding that breaks the level constraint by a pip is REPORTED rather than absorbed, and the derived pips (not `f`) are what reach the key, since they are what GAMS receives (FEE-01).
  2. The admissibility predicate is the PROVER'S OWN test transcribed from `volume_path.gms:100-108` — `(φ̄²+Δφ²)δ*² − (φ_X+φ_M)·φ̄·δ* + φ_X·φ_M ≤ 0` with **φ̄ = the COMPOSED fee `1−(1−φ_X)(1−φ_M)`** and **Δφ = the FULL gap `φ_M−φ_X`** (NOT the arithmetic mean and semi-axis — that reading is 2× too large and falsely refuses ~82,700 pips). Evaluated in exact INTEGER arithmetic over pips — never `Double` — and the Haskell verdict **AGREES with the GAMS prover's verdict on every grid point**, bracketing each boundary by one pip on each side. A disagreement is a bug in one of them and fails the phase; it is not absorbed by a tolerance (FEE-02).

  **CORRECTED 2026-08-17.** This criterion previously named "the `ρ* = 3.8198` / `δ* = 0.49` boundary". That number is a residue of the same arithmetic-mean/semi-axis misreading `c6c2646` corrected in the clause above: `3.8198417` is the root of the REFUTED `δ* = 2ρ/(1+ρ²)` form, and the corrected `δ* = ρ/(1+ρ²)` puts the leading-order boundary at `ρ ≈ 1.2234668` (MEASURED). Rather than substitute one closed-form point, the Tier-C differential brackets in the **δ\* direction** at four fixed `(f, δ*)` pairs with boundaries measured from the prover itself — `δ* ∈ {82803 … 495954}`, each with a `boundary±1` row. `δ* = 490000` is exercised in Tier A only: at that target the pair `(700, 800)` is inadmissible (boundary `495953`), so it cannot appear in a GAMS agreement grid. Rationale and leaf budget: `26-VALIDATION.md` §3c.
  3. An infeasible request is REFUSED **before any subprocess is spawned**, with the reason and the boundary value in the message — verified by a check that fails if the solver is invoked at all, so "checked before" is observed rather than assumed. The structurally infeasible `φ_X == φ_M` case (§1.2: equal fees are infeasible for *every* target) is among the refusals, caught in Haskell rather than read back as a GAMS abort (FEE-02, FEE-03).
  4. Re-running with the **recorded seed** reproduces the same ρ within the admissible band, and a **different** seed produces a different ρ — so the seed is proven load-bearing rather than decorative, which a same-seed-only test cannot establish (FEE-04).
  5. `decode_next` is exercised against **synthetic logs with no chain**: the 4-byte selector is COMPUTED in the test from the signature string `next(address,uint160,int24,uint24,uint24)` and matched against `0xd3827b0b` (derived, never a transcribed literal); signed `int24` decodes correctly including negative ticks; and a log with the wrong topic, the wrong data length, a truncated payload, or an **all-zero payload** is REJECTED rather than decoded into a plausible-looking shock — the zero-word trap, one type over (CHAIN-04).

#### ⚠ SUPERSEDING NOTE — the event signature is now pinned (issue #28, 2026-08-16)

`ShockLib.shock_emit` (`src/models/mev_tax_model_one/libraries/ShockLib.plk`, commit `341e409`)
emits the event the decoder is actually for. Spec:
`docs/superpowers/specs/2026-08-16-mev-tax-shock-library-design.md` §5.

```solidity
event Shock(address indexed pool, int24 tickDiff, uint24 txlVolmNormRate, uint24 txlVolmDecay);
```

| | |
|---|---|
| **topic0** | `0x21b0e4f81f5ef89be4325ca74966f2fb8f57a217e284dd3e0a276fff55987d64` — VERIFIED here with `cast keccak "Shock(address,int24,uint24,uint24)"`, not transcribed |
| **topic1** | `pool`, indexed `address` — shocks are keyed by pool |
| **data** | exactly 3 non-indexed 32-byte words, always all present (absent components emit `0`) |

Data words, in order: `tickDiff` (**int24, ABI sign-extended to int256 — decode SIGN-AWARE**),
`txlVolmNormRate` (uint24, zero-padded), `txlVolmDecay` (uint24, zero-padded). Rates are pips over
`FEE_DENOMINATOR = 1e6` (Algebra convention) — which independently confirms **KEY-05**'s
requirement that the denominator belong in the key preimage.

**Success Criterion 5 above is SUPERSEDED and was aimed at the wrong artifact.** It computes a
4-byte *function selector* from `next(address,uint160,int24,uint24,uint24)` = `0xd3827b0b`. That is
the selector of the CALL. The decoder's subject is an EVENT, matched on **topic0**. Everything
else in SC-5 stands — compute the value in the test from the signature string rather than
transcribing the literal, decode signed fields sign-aware, and reject a log with the wrong topic,
wrong data length, or a truncated payload rather than decoding it into a plausible shock.

**The v6.0-scope guarantee is a trap, and the plan must not walk into it.** Issue #28 states that
in v6.0 scope only `txlVolmNormRate` is nonzero: `tickDiff == 0` and `txlVolmDecay == 0` are
*guaranteed by construction* (on-chain hookData tagged `flags = 0b010`). So **two of the three
data words are always zero in production**. A decoder exercised only on v6.0-scope events cannot
distinguish "decoded 0 correctly" from "failed to decode and defaulted to 0" — and `tickDiff` is
precisely the sign-extended field, where a decode bug is INVISIBLE at zero. This is the
`tickSpacing = 0` finding again, arriving pre-guaranteed. Therefore the synthetic logs **MUST**
carry a non-zero, **negative** `tickDiff` and a non-zero `txlVolmDecay`, even though production
never emits either, and the all-zero payload must be REJECTED rather than decoded (already SC-5).

**What the event does NOT carry**, which confirms rather than changes phase 27: there is no
`sqrtPriceX96` and no `liquidity` in it. Those stay **CHAIN-02** pool-state reads, pinned to one
block, keyed by topic1's `pool`. And `txlVolmDecay` (α_trans) is **not a GAMS input** —
`VOLUME_PATH.md` §2 rules `txlDecayRate` out explicitly ("the closed loop is trusted"). Decode it,
record it in the run log, do not feed it to the prover. Only `txlVolmNormRate` becomes GAMS's
`txlVolumeRate` (δ_trans).

**Plans**: 4 plans (4 waves — every plan edits the single-file suite `offchain/test/Main.hs`, so they are strictly serial)

Plans:
- [ ] 26-01-PLAN.md — `Fee.Split`: the exact integer level constraint, the prover's own `ellTest` transcribed as `E <= 0`, exact-split rarity in both directions, and the float/aeson scan grown in the same commit (FEE-01, FEE-02) [wave 1]
- [ ] 26-02-PLAN.md — `Chain.Shock`: `Either`-returning decoder with an exact 96-byte length rule, per-word ranges and an explicit all-zero refusal; a 17-member named synthetic corpus carrying a NEGATIVE `tickDiff` and a nonzero `txlVolmDecay`; topic0 COMPUTED from the signature string; the `ShockLib.plk` merge trip-wire with a mandatory positive control (CHAIN-04) [wave 2]
- [ ] 26-03-PLAN.md — the NINTH refusal inside `Gams.Argv.render_argv` (after `distinct_fees`, so the section 1.2 diagnosis survives), the Tier-B marker-stub observation that no subprocess is spawned, and the seeded pick proven load-bearing over a band proven larger than one (FEE-01, FEE-03, FEE-04) [wave 3]
- [ ] 26-04-PLAN.md — the Tier-C differential: `render_argv_ungated` with exactly one consumer, `capture-fee-split.sh`, a 12-row two-sided boundary-bracketing grid with 4 controls against the real GAMS toolchain, the SEVENTH swept artifact, and the phase-close floor re-measurements (FEE-02) [wave 4]

**Planning corrections of record (2026-08-17, measured at plan time):**
1. `26-RESEARCH.md` guard 5's firing input does NOT fire. A `floor` rounder's worst residual over the
   whole band is 999799, strictly below the one-pip bound; `m + 1` fires for 0 of 44 members at
   f = 100. The input that fires for every member at every f measured is **`m + 2`**. The residual
   therefore gets two independent assertions and only one uses the bound.
2. `26-RESEARCH.md` guard 20's empty-band input does NOT fire. `f = 3000, delta* = 1000` measures a
   band of **4** (2 under `rho > 1`), not 0. The EMPTY case is `delta* = 200`; the SINGLETON case —
   the one that makes FEE-04 vacuous — is `delta* = 500`, sole member `(1, 2999)`.
3. The residual headroom under the one-pip alarm is **2x**, not the ~10^3 M4 implies: 10^3 is the
   BEST member's residual, while an arbitrary seeded pick measures up to 0.4997 pip.
4. `min_admissible_dstar 3000 3000 == Nothing` — at equal fees NO integer `delta*` is admissible,
   which is strictly stronger than section 1.2's prose and is why the ellipse gate must run AFTER
   `distinct_fees` or the specific diagnosis is silently lost.
5. The upper root of the prover's gate is **499999** for three of the four grid pairs — an
   independent reproduction of `VOLUME_PATH.md` section 1.1's `delta <= 1/2` ceiling. The mistaken
   arithmetic-mean reading gives 1.

### Phase 27: Anvil Read Layer
**Goal**: A shock read off a live chain is a snapshot of ONE block, or it is an error. The
decoder built in Phase 26 meets a real mined `next` event, and every pool read is pinned to the
block that event was in.
**Depends on**: Phase 26 (the decoder), Phase 23–25 (somewhere to put the result).
**BLOCKED** on the plank worktree emitting the `next` event — `SELECTOR_NEXT` is a stub today
(issue #26, plank workstream). Nothing in phases 23–26 waits on this.
**Requirements**: CHAIN-01, CHAIN-02, CHAIN-03, CHAIN-05, CHAIN-06, CHAIN-07
**Success Criteria** (what must be TRUE):
  1. A `next` event in a **mined** transaction's logs decodes into the shock it carries, and the decoded values are compared against what the emitting transaction was given — read from the log, never from the request record that produced it (CHAIN-01).
  2. Every read function **requires** a `BlockRef` argument: there is no arity at which a caller can omit it, `Latest` appears nowhere in the read layer (grep-asserted), and each read records the block it was **made at** — an unpinned tag surfaces as `null` in the artifact rather than as a plausible height, in the existing `readback_height` idiom (CHAIN-02).
  3. The pinning is proven by a case that would otherwise slide: with blocks mined between the event and the reads, the pinned read returns the **event-block** value while an unpinned read is OBSERVED returning a different one. On a single-writer local anvil this defect is invisible in every other recorded value, so it can only be caught by constructing the divergence (CHAIN-02).
  4. An absent, zero or unparseable read is an ERROR **naming the field**, never a value that flows into a key: `sqrtPriceX96 = 0`, `liquidity = 0`, an uninitialised pool, and a read against a block whose hash no longer resolves (`anvil_reset`/`evm_revert` replace history) each REFUSE — each demonstrated by driving that exact condition (CHAIN-03).
#### ⚠ CROSS-TRACK HANDOFF — issue #29 (2026-08-16)

`CHAIN-02` is where the fixture stops describing a hypothetical pool and starts describing a
**live one at a pinned block** — and that is where it collides with the consuming forge test.

`test/models/mev_tax_model_one/AlgebraIntegralMevTaxModelOneShocks.t.sol` runs entirely
**in-process** (verified: no `createFork`, no RPC, no `8545` anywhere in it). `_createPool()`
deploys two fresh `MockERC20`s and initializes at `SQRT_PRICE_1_1 = 2^96` / `UNIT_LIQUIDITY =
2^64`, then asserts the fixture agrees at **line 163**. **The test constructs its subject; this
bridge observes one.** Those are incompatible. Today it passes only because the fixture carries
the `volume_path.gms` self-test defaults, which are the same two numbers.

Benign here while the read happens to land on a genesis-state pool. **Fatal at phase 28**, when
the loop moves the price and `assertEq` hard-fails.

**Filed as issue #29** against the plank/test track, asking for three things: ATTACH to the
deployed pool rather than merely forking (forking alone cannot help — `_createPool()` mints new
token addresses every run, so its `poolId` can never match); assert Anvil is genuinely open and
**FAIL loudly naming the endpoint** rather than falling back to the in-process EVM (a silent
fallback passes while testing nothing — the defect class); and settle ONE endpoint resolution,
since `127.0.0.1:8545` is currently hardcoded at **10 sites** and the forge test would be the
11th.

**REQUIREMENT GAP ON OUR SIDE, and it is ours to close.** The fixture records `sqrtPriceX96` and
`liquidity` but **no pool identity** — no pool address, no token pair. A test that attaches has
nothing to attach *to*. Phase 27 must emit it. `LOOP-03` says publish to the path the test reads;
nothing anywhere guarantees the test can USE what we publish, and that is the actual gap.

#### ✅ ISSUE #29 CLOSED (2026-08-16) — plank landed `f713089`, and handed BACK a contract

The plank side is done: `test__priceInvarianceUnderVolumePath` now **attaches** to a live pool
(pool / blockNumber / chainId read from the fixture, `createSelectFork` pinned to the solved
block, tokens read on-chain), keeps line 163 as a determinism guard, and its **fail-loud guard was
OBSERVED firing** — fixture-present + Anvil-down FAILS naming the endpoint, never skips;
fixture-absent still skips. Spec:
`docs/superpowers/specs/2026-08-16-volumepath-attach-and-rpc-contract.md`.

**Three pieces of work came back to us, and they are binding on this phase.**

**(a) The fixture gains three fields** — this closes the gap I recorded above ("the fixture
carries no pool identity"), now specified exactly:

| Field | JSON type | Note |
|---|---|---|
| `pool` | **string** (address) | the pool the test attaches to |
| `blockNumber` | **string** (uint) | pins the fork to the solved block — **string**, because it can exceed the 53-bit double-exact ceiling |
| `chainId` | number | wrong-network guard; anvil default `31337` |

`sqrtPriceX96`/`liquidity` stay strings. **Do NOT add `token0`/`token1`** — the test reads them
from the pool on-chain (`IAlgebraPoolImmutables(pool).token0()/token1()`), so the pool is the
single source of truth. Note `blockNumber` as a string is the same 2^53 discipline BYTE-04 already
enforces for `dQx`.

**(b) One endpoint resolution:** `ETH_RPC_URL` if set, else `http://127.0.0.1:8545`. Shell:
`"${ETH_RPC_URL:-http://127.0.0.1:8545}"`. Haskell:
`fromMaybe "http://127.0.0.1:8545" <$> lookupEnv "ETH_RPC_URL"`. Nine `offchain/` files currently
hardcode the URL — the four `*/Rpc.hs` providers, `app/Main.hs`, `app/CheatSwapProof.hs`,
`deploy-rig.sh` and both `capture-*.sh` — and every one converts.

**(c) THE CRITICAL ONE — the producer must bind the SAME endpoint.** The resolver in (b) is for
**consumers**. `deploy-rig.sh` is the **producer**: it launches `anvil` with no `--port` (so always
8545) and deploys through the `local` alias literal. Both anvil's `--host`/`--port` **and** the
deploy `--rpc-url` must derive from the same `ETH_RPC_URL`. Plus a **`chainid` assertion before any
`--broadcast`**, mirroring the test's `require(block.chainid == fxChainId)`, so a stray
`ETH_RPC_URL` pointing at a real network cannot get pool deploys broadcast to it.

**Why (c) is not optional:** without it, `ETH_RPC_URL=…:9545` brings anvil up on **8545** while the
test attaches to **9545** — which is precisely the `RPC_PORT` desync issue #29 was opened to
prevent, reappearing through the fix for it. A consumer-only resolver does not retire the
divergence; binding producer and consumer to one source does. This is a sharper statement of the
problem than the one I filed, and it is correct.

**Still not in scope here:** swap replay and tick closure are **#26** (routed through the pool's
on-fork plugin, not `setUp`'s in-process writer). The happy-path attach E2E goes green only once
this phase deploys and drives a pool on Anvil; plank has proven the fail-loud guard alone.

#### 🔓 BLOCKER DOWNGRADED (2026-08-17) — the event EXISTS; what remains is a MERGE

Issue #28 landed `ShockLib.shock_emit` (`341e409`) and issue #29 closed with plank's test
attaching to a live pool. The `Shock` event is built and its signature is pinned. The blocker has
changed KIND, not merely status.

**MEASURED here, 2026-08-17:** `src/models/mev_tax_model_one/` is on `exp/mev_tax_model_one`
**only** — `git ls-tree -r origin/develop | grep -c 'models/mev_tax_model_one'` = **0**, absent
from this worktree, and `exp` is **153 commits ahead of develop**. So the emitter cannot be
deployed on Anvil from any branch we build from until that work reaches develop.

**What this phase can now do WITHOUT waiting:**

| Requirements | State |
|---|---|
| **CHAIN-05, CHAIN-06, CHAIN-07** | **Fully actionable.** These came back from issue #29's contract and are entirely ours — the fixture's pool identity, the `ETH_RPC_URL` resolution across nine sites, and the producer/consumer binding with the `chainid` guard. No plank dependency whatsoever. |
| **CHAIN-04** | Actionable, and always was — decoding is exercised against synthetic logs. It sits in Phase 26. |
| **CHAIN-01, CHAIN-02, CHAIN-03** | Blocked on the MERGE of `exp/mev_tax_model_one` → `develop` → here. Not on anyone writing code. |

**Consequence for sequencing:** this phase no longer has to wait as a unit. CHAIN-05/06/07 can be
planned and executed now; CHAIN-01/02/03 wait for the merge. A plan that bundles all six would
stall on the merge for no reason.

**Do NOT read this as "unblocked".** The live-read half still cannot be executed, and a plan that
claims otherwise would be asserting a capability the tree does not have.

**Plans**: TBD

Plans:
- [ ] 27-01: TBD

### Phase 28: Resident Loop & Fixture Publication
**Goal**: A loop that survives its own crash, never double-counts an event, never conflates
"already solved this shock" with "already saw this event", and publishes exactly one file the
forge test can never observe half-written.
**Depends on**: Phases 25, 26, 27. **BLOCKED** — inherits Phase 27's upstream block.
**Requirements**: LOOP-01, LOOP-02, LOOP-03, LOOP-04, LOOP-05
**Success Criteria** (what must be TRUE):
  1. New `next` events are discovered by polling `eth_getLogs` over an explicit closed `[b, b]` range from a **persisted** watermark (a row in the store, not an `IORef` and not a file). Killing the loop and restarting it resumes at the watermark and skips nothing — proven by a run in which events occur while the loop is down, which is the only way a restart-from-`latest` bug is visible (LOOP-01).
  2. Replaying the same `(txHash, logIndex)` produces exactly **one** run-log row and no second solve; two **distinct** events carrying identical shock values produce **one** cache entry and **two** run-log rows. Both directions are asserted, because collapsing them destroys the chronology the run log exists to provide and the content key cannot reconstruct (LOOP-02).
  3. A reader loop racing the publisher for 10 seconds observes **zero** unparseable or truncated fixtures — and a non-atomic write is OBSERVED producing a torn read in the same harness, so the atomic rename is demonstrated to be what prevents it. A fixture below a shape floor (parses, `length dQx == nEvents`, size above a minimum) is REFUSED rather than published (LOOP-03).
  4. Publication writes **exactly one file** plus its same-directory temp sibling into the other workstream's tree and nothing else — asserted by a before/after tree diff, not by reading the code. A missing `test/models/mev_tax_model_one/fixtures/` directory is a **loud failure naming the path and the owning workstream**; the loop never creates a directory there, because that is how a typo becomes a successfully-published-to-nowhere fixture (LOOP-04).
  5. A SIGINT and an injected exception at **each** stage of an iteration leave the store and the published fixture consistent: the watermark is unadvanced, no half-written row exists, the block is re-processed on restart, and the fixture still parses and carries the content key of a run that completed. A shutdown is only ever observed at a block boundary, never mid-block (LOOP-05).
#### ⚠ CROSS-TRACK HANDOFF — issue #29 (2026-08-16)

**This is the phase where the collision described under Phase 27 becomes fatal.** The resident
loop moves the pool price, so the published fixture's `sqrtPriceX96` stops being `2^96`, and
`AlgebraIntegralMevTaxModelOneShocks.t.sol:163`'s `assertEq` hard-fails — the consuming test goes
red precisely when this pipeline starts working.

Nothing in `LOOP-01..05` prevents that, because the fix is not ours: the test must ATTACH to the
live pool rather than construct its own. Tracked as issue #29. Do not "solve" it by loosening
line 163 — a fixture solved for a different pool than the one replayed is meaningless, and that
assertion is correct. The two pools must become the same pool.

#### ✅ ISSUE #29 CLOSED (2026-08-16) — the fatal-at-28 collision is retired

The collision recorded above no longer fires: plank's `f713089` makes the test **ATTACH** to the
live pool rather than construct its own, so a moving price no longer breaks
`AlgebraIntegralMevTaxModelOneShocks.t.sol:163` — that line survives as a determinism guard
against a fixture solved for a different pool.

What LOOP-03 must now publish is the fixture shape phase 27 emits, including `pool`,
`blockNumber` (**string**) and `chainId`. Publishing the old three-field shape would leave the
test unable to attach — so `LOOP-03`'s "publish to the path the test reads" is now a **typed**
obligation, not just a path one.

Carry into this phase: the loop is the thing that moves the price, so it is also the thing that
makes `blockNumber` matter. A fixture published without the block it was solved at cannot be
replayed against the chain state it describes.

**Plans**: 5 plans (5 waves — strictly serial: every plan edits the single-file suite
`offchain/test/Main.hs`, which is what bounds parallelism here, not the dependency graph)

Plans:
- [x] 28-01-PLAN.md — Spike seams S2/S3 closed in the library (`Loop.Solve`: a `Solver` over resolved paths, `classify` returning outcome + halt as data) plus migration `004`, the per-event ledger and single-row watermark, and a re-taken store-conformance capture (LOOP-02) [wave 1]
- [x] 28-02-PLAN.md — Seam S1 closed (`Gams.Detect.detect_toolchain`, a version-only hermetic probe driveable against a `/bin/sh` stub), the poll, the one iteration function with `--once`/resident, the complete exit-code table, and the restart-skips-nothing proof over events that occurred while the loop was down (LOOP-01) [wave 2]
- [x] 28-03-PLAN.md — Publication: `write_bytes_atomically` generalized from the existing JSON writer, the textual identity splice that keeps the artifact's bytes verbatim, the shape floor, and the ten-second race harness with its torn-read positive control OBSERVED (LOOP-03) [wave 3]
- [x] 28-04-PLAN.md — Exactly one file by before/after tree diff, the missing-directory precondition naming the path and the owning workstream, and the default path pinned byte-equal to the consumer's own `VOLUME_PATH_JSON` read live from `origin/develop` (LOOP-04) [wave 4]
- [x] 28-05-PLAN.md — SIGINT observed only at a block boundary, an exception injected at EACH stage leaving the watermark unadvanced, the live Tier-C `capture-loop.sh` written/gated/recorded as blocked on issue #26, and the phase close by hand (LOOP-05) [wave 5]

**Phase summary:** `.planning/phases/28-resident-loop-fixture-publication/28-SUMMARY.md`

**Note for `roadmap update-plan-progress 28`:** it counts `*-SUMMARY.md` in the phase directory and
this phase keeps its phase-level summary there, so it writes `6/5`. Phase 27 recorded `4/3` for
exactly the same reason. The table below is correct BY HAND at `5/5`; correct it again after any
re-run.

## Progress (Milestone v6.0)

**Execution Order:** 23 → 24 → 25 → 26 → 27 → 28, **strictly serial**. The earlier claim that
26 was parallelizable against 23–25 was wrong: 26's *dependencies* are indeed only `base`, but
parallelism is bounded by the single-file test suite (`offchain/test/Main.hs`), not by the
dependency graph. 23 → 24 → 25 is additionally a genuine chain: 24 must land before 25's
first production write, and 25 consumes 23's schema. **27 and 28 are BLOCKED on another
workstream**; 23–26 are the complete chain-free subsystem and the byte-reproduction proof lands
at the end of 25.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 23. Postgres Foundation & the Byte-Exact Schema | 5/5 | Complete    | 2026-08-16 |
| 24. GAMS Invocation & Toolchain Identity | 6/6 | Complete    | 2026-08-17 |
| 25. The Content Key & Keyed Store | 3/3 | Complete    | 2026-08-17 |
| 26. Shock Assembly — Fee Split & Event Decode | 4/4 | Complete   | 2026-08-17 |
| 27. Anvil Read Layer (6 of 7 shipped; only CHAIN-01 is blocked) | 3/3 | Complete   | 2026-08-22 |
| 28. Resident Loop & Fixture Publication (S1/S2/S3 all closed in the library; LOOP-01..05 proven CHAIN-FREE — 205/205 → 232/232 across the phase; the LIVE half of all five is BLOCKED on #26 for the `Shock` emitter and on the #24 track for the fixtures directory, and `offchain/rig/capture-loop.sh` is the unrun capture that would discharge it) | 5/5 | Complete | 2026-08-23 |

## Coverage (Milestone v6.0)

| Phase | Requirements | Count |
|-------|--------------|-------|
| 23 | DB-01, DB-02, DB-03, DB-04, BYTE-01, BYTE-02, BYTE-03, BYTE-05, KEY-07 | 9 |
| 24 | GAMS-01, GAMS-02, GAMS-03, GAMS-04, GAMS-05, GAMS-06, BYTE-04 | 7 |
| 25 | KEY-01, KEY-02, KEY-03, KEY-04, KEY-05, KEY-06, STORE-01, STORE-06, STORE-08 **shipped**; STORE-02, STORE-03, STORE-04, STORE-05, STORE-07 **deferred** (scope cut 2026-08-17) | 14 mapped, 9 shipped |
| 26 | FEE-01, FEE-02, FEE-03, FEE-04, CHAIN-04 | 5 |
| 27 | CHAIN-01, CHAIN-02, CHAIN-03 | 3 |
| 28 | LOOP-01, LOOP-02, LOOP-03, LOOP-04, LOOP-05 | 5 |

**Total mapped: 43/43** — no orphans, no duplicates.

**Count correction recorded at roadmap time (2026-08-16):** `REQUIREMENTS.md`'s header and its
Traceability footer both said *"39 v6.0 requirements defined"*. The actual checkbox count is
**43** (BYTE 5, KEY 7, STORE 8, DB 4, GAMS 6, FEE 4, CHAIN 4, LOOP 5). The stale figure is
corrected in `REQUIREMENTS.md` rather than reconciled by dropping four requirements — an
unexplained 4-requirement gap between a header and a body is exactly the kind of arithmetic
this project's review history says not to trust silently.

## Research Flags (Milestone v6.0)

- **Phase 23 — no research gap on the schema; it is MEASURED.** `bytea` vs `json` vs `jsonb`
  byte-fidelity was measured on PG 18/18.4 against the real §3 output shape, and
  `postgresql-simple` 0.7.0.1 (`+4` packages, the smallest of six candidates) was chosen by
  `plan.json` set-diff against the real 152-package baseline. The open items are operational,
  not architectural: the **pinned Postgres image tag** (`postgres:18-alpine`, and the server
  version belongs in the conformance evidence), and **whether GH Actions `services:` containers
  work on the `cfmm-build` executor** — unverified, which is precisely why the per-run-database
  strategy was chosen: it does not depend on the answer. Note `web3-crypto` caps **`aeson <2.3`**
  and `crypton <1.1`; `crypton-1.0.6` is already resolved, so hashing is `+0` packages.
- **Phase 24 — TWO genuine unknowns, both cheap and both settled by ONE prover run.**
  (a) **CONOPT version detection has no clean method** — `gams --version` does not report it and
  the only obvious source is listing/log text, which §4 forbids *gating* on (it is key material,
  not a gate, so it is permissible if total, non-empty and shape-checked; record which method
  produced it). LOW confidence. (b) **Is `volTgtWad` an integer or a float on the GAMS side?**
  §2's own example passes `28e18`. This decides the canonical key rendering and must be answered
  **before Phase 25 freezes the key formula**. One prover run against a scratch directory settles
  CONOPT detection, `volTgtWad`'s type, the trailing-newline question, whether §3's example JSON
  is byte-accurate (the prover emits `deltaRealized` via `dReal:0:10`, ten decimals, while §3
  shows `0.49`), and the exit-code behaviour — all at once. Do it first.
- **Phase 25 — the key formula's SCOPE is the open question, not its implementation.**
  `VOLUME_PATH.md` §2's seven inputs are not the complete set of things the output depends on:
  the **model source digest** and **solver options digest** are prior-art recommendations that
  KEY-01 adopts, and `nEvents` (§6 open ruling 1, fixture value 8) must have its production
  value confirmed before the first row lands or changing it invalidates the whole store. Also
  bounded here: `volume_path.gms:202` sets `fj.pw = 4000`, so the put line wraps around
  **N ≈ 180 events** — production `nEvents` must stay under that. The `splitter_version` is a
  Phase 26 product; `key_scheme` (Phase 23) is what makes adding it later non-destructive.
- **Phase 26 — the differential against the model is the work, not the closed form.** "Closed
  form, no optimizer" reads as trivially correct; closed forms are exactly where rounding
  conventions hide. The `(f, δ*)` grid differential against the GAMS prover, evaluated in
  `Rational`, is the deliverable. The `next` selector and signature are **known now** — consume,
  do not re-derive.
- **Phase 27 — blocked, not unresearched.** Everything needed is pinned; the gap is upstream
  emission (issue #26). Do not open research here; open coordination.
- **Phase 28 — coordinate the `test/` path with the owning track BEFORE planning, not during.**
  `test/models/mev_tax_model_one/fixtures/volume_path.json` **does not exist in this worktree**
  (`find test -path "*models*"` returns nothing); the precedent that does exist is
  `test/gamsDiff/fixtures/*.json`. Also: the repo has **no `.gitattributes` at all** — verified —
  so nothing today prevents EOL normalisation from rewriting a published fixture's bytes in
  transit. Whether the committed fixture comes from an explicit promotion or straight from the
  loop is a product decision to settle at plan time, not a technical one.

## Scope Boundary (Milestone v6.0)

The store lives under `offchain/` (ours). The **only** thing written into `test/` is the latest
fixture copy — one file into another track's tree, not a database.

Explicitly OUT: **changing `VOLUME_PATH.md`'s emitted JSON shape** (`model/` is the GAMS
workstream's territory; the §3 shape is their contract); **implementing `SELECTOR_NEXT`'s event
emission** (plank workstream, issue #26); **fixing the test's `shock(...)` signature mismatch**
(belongs with issue #26, which owns the alignment); **asserting the rig's computed payload**
(`e5.fee`, σ, accumulators — filed as issue #19, a different concern from this store); and
**`ExceptT` error plumbing over `Web3`** (`runWeb3'`'s `Left` is unreachable; it would advertise
a guarantee the runtime does not provide).

Deferred to v7.0+: a **numeric-aware diff** of divergent artifacts (byte inequality plus both
digests suffices until a mismatch actually happens); **garbage collection** of unpinned entries
(artifacts are low-KB, and its reachability predicate depends on pinning and the run log landing
first); **single-flight concurrent solves** (assumes one loop); and a **second store tenant**
(the `<model>/<key>` layout is model-agnostic from the start, but building a second tenant
before a second model exists is speculative).
