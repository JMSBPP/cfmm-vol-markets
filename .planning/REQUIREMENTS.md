# Requirements: CFMM Payoff Replication — Plank ↔ GAMS Connection Layer

**Defined:** 2026-06-27
**Milestone scope:** Open-loop **plumbing**, end-to-end, with a **stub GAMS solver**. This milestone proves the connection layer carries parameters correctly (GAMS output → encode → Plank write → read-back round-trip), on one authoritative kernel. It does **not** yet prove correct payoff *replication* (real optimization model, replication-error metric, and LDF correctness are v2).
**Core Value:** A parameter set flows end-to-end — (stub) GAMS output → encoded to Plank fixed-point → written via `initVolTermStructure` → read back and round-trip-verified — with both tracks bound to one authoritative kernel.

## v1 Requirements

Each maps to exactly one roadmap phase.

### Repository

- [ ] **REPO-01**: `wvs-finance/cfmm-replicationPlank` exists as a **public** repo and is the canonical upstream
- [ ] **REPO-02**: `JMSBPP/cfmm-replicationPlank` is a fork of the `wvs-finance` canonical, achieved via a **documented, reversible migration sequence** (backup → create canonical → retire/rename the existing standalone `JMSBPP` repo → fork); the destructive step is called out and confirmed before execution
- [ ] **REPO-03**: local git remotes reflect the topology (`upstream` = wvs-finance, `origin` = JMSBPP fork)
- [x] **REPO-04**: a project `README.md` (replacing the Foundry boilerplate) describes the Plank/GAMS dual-track and setup
- [x] **REPO-05**: **publish-readiness sanitization** before the public flip — remove `refs/` `node_modules` and the `Counter` scaffold, fix-or-disable the broken CI, **scrub all local absolute paths** (no `$HOME/...` local home-absolute path in tracked files), and ensure `.gitignore` covers `node_modules`/build artifacts

### Toolchain & Reproducibility

- [ ] **TOOL-01**: the `plank` compiler version is pinned (e.g., `.plank-version`) and the canonical codegen backend (`sona`) is declared; the FFI build asserts `plank --version` matches the pin
- [ ] **TOOL-02**: the Plank deployer / `plankified-univ3` submodules are pinned to specific commits, and the FFI deploy guards the silent-zero failure mode (assert returned bytecode length > 0 and deployed address ≠ 0; fail loudly)

### Shared Kernel

- [ ] **KERN-01**: every type on the **bridge path — explicitly enumerated** (`VolatilityTermStructure` and its fields; the `NumberFormat`/`BoundedValue` they use) — carries number format, bounds, and unit semantics, with **no placeholder bounds** (the `baseTick` bound is resolved to a concrete int24 range)
- [ ] **KERN-02**: `VolatilityTermStructure` is fully specified **and** a concrete conformance mechanism binds the Plank type and the GAMS symbols to the single kernel definition (a generated shared constants file both sides include, or a checked field-by-field cross-reference) — not prose alone
- [ ] **KERN-03**: the kernel states the canonical fixed-point conventions (WAD `1e18`, Q64.96) and unit rules, using **one canonical name** for the Q64.96 format consistently (reconcile `Q64x96`/`Q64.96`/`Q96_ONE`)

### Encoding Contract & Parameter Map

- [ ] **MAP-01**: a GAMS↔Plank mapping table covers at least `xi`↔`priceElasticity`/LDF `alpha`, `iota`↔`statePartitionDelta`/`tickSpacing`, and `baseTick`, each with mapping direction
- [ ] **MAP-02**: a **per-hop** fixed-point encode/decode chain is specified for each parameter — every quantizing hop (e.g., GAMS `xi` → Q64.96 `priceElasticity` → state-scale `alpha`) with its scale base and rounding mode; the `priceElasticity` upper bound is **corrected so the type covers the full valid `alpha` range** (resolves `Q96_ONE` < `MAX_ALPHA`)
- [ ] **MAP-03**: signed `baseTick` encoding is specified — int24 two's-complement sign-extended to `u256`, rounded to a `tickSpacing` multiple, within the resolved int24 bounds
- [ ] **MAP-04**: a `tickSpacing` divisibility invariant is enforced — encoding validates or re-derives `tickLower`/`tickUpper` as valid multiples of the resolved `tickSpacing` (e.g., canonical ±120 vs spacing)
- [ ] **MAP-05**: the `initVolTermStructure` ABI + storage-layout contract is specified — canonical function signature string, ABI argument layout, and on-storage bit-packing of `VolatilityTermStructure`; selector `0xd9c112ef` is verified to equal `keccak(signature)[:4]`
- [ ] **MAP-06**: storage slots are **reconciled** — the write slot (`SLOT_VOLATILITY_TERM_STRUCTURE`) and the simulator's read slots are unified and declared (no undefined `SLOT_TICK_*`); any parameter is traceable from its GAMS symbol to a declared Plank slot

### Theory Grounding

- [ ] **REF-01**: each mapped parameter has a reference markdown under `spec/refs/` linking it to its grounding note in `cfmm-theory` — primary target `KERNEL.md`, extensible (`cfmm-control/ELASTICITY_CONTROL.md`, `cfmm-options/PAYOFF.md`, …) — cited by URL/citekey with **no code dependency** on the cfmm-theory tree
- [ ] **REF-02**: in the `spec/refs/` markdown, each key control parameter is annotated with the behavioral theorem/assumption/market regime it encodes (supporting level — not a formal review)

### Plank Bridge-Surface Implementation

- [ ] **PLNK-01**: `src/types/VolatilityTermStructure.plk` is implemented with a working `read` that decodes the stored struct per the MAP-05 layout
- [ ] **PLNK-02**: `IMarketDynamics.initVolTermStructure` has an implemented body that decodes calldata and stores into the reconciled slot per MAP-05/MAP-06 (not just a selector constant)
- [ ] **PLNK-03**: `IMarketDynamicsLens` getters are implemented — including **`getPriceElasticity`**, `getStatePartitionDelta`, and `getBaseTick` — providing a read-back view for **every** seeded field
- [ ] **PLNK-04**: all Plank sources on the bridge/pipeline path **compile cleanly** via the pinned FFI build — the parse/type stubs (`SELECTOR_… =;`, untyped fields, `uint256` vs `u256`, `u265` typo) blocking the path are fixed

### GAMS Plumbing (stub solver)

- [x] **GAMS-01**: GAMS sources are vendored into `model/` inside the repo and the pipeline references that location (not `../experiments/gams`) — ✓ **DONE** (already vendored: `model/*.gms`, `model/dynamic/InitState.gms`, `model/spec/*`, `model/BUILD.md` tracked). Residual `../experiments/gams` text references in `model/BUILD.md` + `docs/superpowers/` get cleaned in the Phase 1 path scrub.
- [ ] **GAMS-02**: the GAMS model **runs from `model/` and emits the parameter-output artifact** the bridge consumes, using a **stub/placeholder objective** (a trivial or fixed map is acceptable this milestone); the real optimization model is deferred to v2

### Open-Loop Runtime Bridge

- [ ] **BRDG-01**: GAMS output is serialized to a defined exchange format (e.g., JSON or ABI-encoded calldata) that the Plank side consumes
- [ ] **BRDG-02**: a bridge step encodes the parameters per the MAP-02 contract and writes them to Plank via `IMarketDynamics.initVolTermStructure()` (selector `0xd9c112ef`)
- [ ] **BRDG-03**: the Plank `ReferenceMarket`/LDF reads the seeded parameters back through the lens views and a **round-trip equality** holds: `decode(readback) ≈ original` within the stated quantization tolerance
- [ ] **BRDG-04**: a selector-conformance test asserts each Plank selector constant on the path equals `keccak(documented signature)[:4]`

### End-to-End Plumbing

- [ ] **PIPE-01**: a single command runs the full open-loop **plumbing** path end-to-end — payoff spec → (stub) GAMS solve → encode → Plank write → read-back — exiting success **only if** the FFI guards (TOOL-02) and the round-trip (BRDG-03) pass
- [ ] **PIPE-02**: an **open-loop guard** — the swap-replay/simulate step performs **no in-loop parameter updates** (keeping the closed-loop controller out of this milestone)

### Lean4 + Math track (CTX-*) — Phase 12 only

**Added 2026-08-02 at the Phase-12 close-out.** Phases 8–12 mint their requirement ids as `CTX-*`
tags at planning time, declared in `ROADMAP.md` and in each phase's `CONTEXT.md`. Until now none of
them were declared here, so `requirements mark-complete` was a no-op for every phase in that track.
**This section closes the gap for Phase 12 only.** Phases 8–11's CTX-* ids remain declared solely in
`ROADMAP.md` — recorded rather than silently back-filled, because adopting the full table belongs to
the roadmapper, not to a phase close-out. These are **not** v1 plumbing requirements and are not
counted in the v1 coverage totals below.

- [x] **CTX-CURVDOC**: the curvature specification (Capponi–Jia arXiv:2103.08842v4 §5.1 — Lemma 3, Propositions 5 and 6) transcribed into `VOLATILITY_INSTRUMENTS.md` as blocks E0–E8 over a one-dimensional curvature index, under HEAVY USER APPROVAL and a notation gate — ✓ **SATISFIED** (12-01)
- [x] **CTX-CAPTRANS**: the anchor's curvature layer machine-checked — both Lemma-3 antitonicities, both branch points, branch agreements and continuity — ✓ **SATISFIED** (12-03: `arbLossRatio_strictAntiOn`, `surplusRatio_strictAntiOn`, `kphiS_le_kphiI_iff`, the branch-agreement lemmas)
- [x] **CTX-INTERIOR**: the interior optimum established, **with no first-order condition** — ✓ **SATISFIED** (12-03: `kphiStar_eq_kphiI`, `kphiStar_mem_Ioo_iff`, `lpExcess_isMaxOn` from the two one-sided strict monotonicities, `lpPayoff_isMaxOn`, `liquidity_freeze_minimal`, `depositEfficiency_isMaxOn`)
- [x] **CTX-ETABRIDGE**: the `κ_φ ↔ η` bridge and the closed-form controller — ✓ **SATISFIED** (12-03: `curvIndex` and its bijection lemmas, `curvIndex_etaStar` as an EQUALITY, the four strict comparative statics, the η-side transport, and T28'a `priceEta_eq_p_eta_half` / `priceEta_eq_P_half`). **NOTE:** the η-identity's FACTOR-SHARE half (T28'b / E8(6)) is OPEN, so the user's η-identity decision is **PARTIALLY discharged**; the requirement as scoped is satisfied, the decision is not closed
- [x] **CTX-DEGEN**: **SATISFIED AS NARROWED** — per the user's binding ruling of 2026-07-31 there is **no literal de-degeneration of the `Θ_φ` program** and none was attempted: `mevMulti` contains no η, no `κ_φ` and no `ϱ_I`, so nothing in the curvature layer moves the Phase-11 objective, and the Phase-11 degeneracy stands exactly where Phase 11 left it. What shipped is the interior optimum in the separate Capponi-anchored model, the η-bridge transport, and the Phase-11 contrast as an honest scope statement (12-03: `eta_no_common_argmax`, `etaStar_coupled_to_fee_corner`). Full de-degeneration needs one objective carrying both a demand-elastic investor and `λ_ARB`; that object exists in neither model and is **OPEN**
- [x] **CTX-REVIEW**: the two-reviewer gate (Reality Checker + a fitted specialist, run blind and in parallel) on every pre-submission spec artifact — ✓ **SATISFIED** (12-01: 3 BLOCKER + 9 MAJOR resolved; 12-02: 2 BLOCKER + 1 MAJOR + 11 MINOR resolved, one BLOCKER being a false sentence in the already-approved, byte-pinned document)
- [x] **CTX-TRACE**: the auditable record — traceability rows with statuses taken from the fidelity record and nowhere else, every named identifier verified to exist, every OPEN item labelled OPEN, plus the doc back-annotation and the plank answer — ✓ **SATISFIED** (12-04)

## v2 Requirements

Deferred to future milestones. Tracked but not in current roadmap.

### Real Optimization & Replication Proof

- **PAY-01**: `PayoffModule.gms` represents an **arbitrary parameterized contingent payoff** with a real objective/constraints/solver, plus a solver-status/feasibility check on the emitted artifact
- **PROOF-01**: the pipeline replicates a concrete contingent-payoff instance end-to-end
- **PROOF-02**: a **replication-error metric** — defined norm, units, sampling grid, on-/off-chain computation locus, and an acceptance tolerance — decomposing encoding-quantization error from CFMM-vs-target structural error

### Simulation Correctness

- **LDF-01**: `src/ldf/GeometricDistribution.plk` passes the bunni-v2 LDF conformance suite (normalization, monotonicity, inverse functions)
- **LDF-02**: `SwapAmtGen` arithmetic is overflow-bounded over the tested `timeIndex` range; fuzz runs raised to ≥ 1000

### Adaptive Control

- **CTRL-01**: closed-loop adaptive feedback controller in `src/DynamicCFMM.plk` that updates `xi`/`iota` as the simulated market evolves
- **CTRL-02**: V4 `beforeSwap` hook integration driving the controller on-chain

### Breadth & Rigor

- **PLIB-01**: a library of contingent payoffs replicable through the pipeline
- **RIG-01**: formal literature review deliverable on CFMM payoff replication
- **RIG-02**: cryptographically-secure on-chain randomness (VRF / commit-reveal) replacing the simulation proxy

## Out of Scope

Explicitly excluded this milestone.

| Feature | Reason |
|---------|--------|
| Correct payoff **replication** proof (metric + tolerance) | Plumbing-first milestone; replication correctness is v2 (`PROOF-*`) |
| Real GAMS optimization model | Stub solver this milestone; real model is v2 (`PAY-01`) |
| LDF conformance / `SwapAmtGen` overflow fix | Deferred to v2 (`LDF-*`); not on the plumbing critical path |
| Closed-loop adaptive controller + V4 hook | This milestone is the open-loop bridge it depends on (`CTRL-*`) |
| Production / mainnet hook deployment | Simulation-first; deployment is later |
| Multiple-payoff library | One path; design stays payoff-agnostic (`PLIB-01`) |

## Traceability

Every v1 requirement maps to exactly one phase. See `.planning/ROADMAP.md` for phase detail.

| Requirement | Phase | Status |
|-------------|-------|--------|
| REPO-01 | Phase 1 | Pending |
| REPO-02 | Phase 1 | Pending |
| REPO-03 | Phase 1 | Pending |
| REPO-04 | Phase 1 | Complete |
| REPO-05 | Phase 1 | Complete |
| GAMS-01 | Phase 2 | ✓ Complete (pre-done — vendored to model/) |
| KERN-01 | Phase 2 | Pending |
| KERN-02 | Phase 2 | Pending |
| KERN-03 | Phase 2 | Pending |
| TOOL-01 | Phase 2 | Pending |
| TOOL-02 | Phase 2 | Pending |
| MAP-01 | Phase 3 | Pending |
| MAP-02 | Phase 3 | Pending |
| MAP-03 | Phase 3 | Pending |
| MAP-04 | Phase 3 | Pending |
| MAP-05 | Phase 3 | Pending |
| MAP-06 | Phase 3 | Pending |
| REF-01 | Phase 3 | Pending |
| REF-02 | Phase 3 | Pending |
| PLNK-01 | Phase 4 | Pending |
| PLNK-02 | Phase 4 | Pending |
| PLNK-03 | Phase 4 | Pending |
| PLNK-04 | Phase 4 | Pending |
| GAMS-02 | Phase 5 | Pending |
| BRDG-01 | Phase 6 | Pending |
| BRDG-02 | Phase 6 | Pending |
| BRDG-03 | Phase 6 | Pending |
| BRDG-04 | Phase 6 | Pending |
| PIPE-01 | Phase 7 | Pending |
| PIPE-02 | Phase 7 | Pending |
| CTX-CURVDOC | Phase 12 | ✓ Complete |
| CTX-CAPTRANS | Phase 12 | ✓ Complete |
| CTX-INTERIOR | Phase 12 | ✓ Complete |
| CTX-ETABRIDGE | Phase 12 | ✓ Complete |
| CTX-DEGEN | Phase 12 | ✓ Complete **AS NARROWED** (user ruling 2026-07-31 — no literal de-degeneration of the `Θ_φ` program) |
| CTX-REVIEW | Phase 12 | ✓ Complete |
| CTX-TRACE | Phase 12 | ✓ Complete |

**Coverage:**
- v1 requirements: 30 total
- Mapped to phases: 30 ✓
- Unmapped: 0
- Lean4 + Math track: 7 Phase-12 `CTX-*` ids declared and complete (Phases 8–11's `CTX-*` ids are declared in `ROADMAP.md` only — a known, recorded gap)

---
*Requirements defined: 2026-06-27*
*Last updated: 2026-06-27 — traceability populated against plumbing-first 7-phase roadmap (30/30 mapped)*
