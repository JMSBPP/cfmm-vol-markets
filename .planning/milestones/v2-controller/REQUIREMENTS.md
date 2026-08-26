# Requirements: Milestone v2.0 — Static Control Kernel (Design & Specification)

**Defined:** 2026-06-28
**Milestone scope:** Design/specification + curated knowledge base for an
EVM-feasible **static** (tick-lattice) control kernel. NOT implementation.
**Core Value:** A complete, coherent design basis — theory, controller catalog,
toolchain, on-chain realization, and gap/hand-off plan — sufficient for a downstream
implementation milestone to build the proof-case controller (C2) without further
research. η = ½ (η-split as generalization path).

REQ-IDs use milestone-local prefixes (RES/LIT/CAT/TLC/SPEC/GAP) — distinct from the
v1 root requirements; the deferred implementation reqs remain `CTRL-01`/`CTRL-02`.

## Requirements

### Research & Mapping

- [x] **RES-01**: Existing work is mapped — branches/worktrees, proved Lean
  theorems, the GAMS model, and EVM/Plank control primitives — in evidence-cited
  map docs (`PROJECT-MAP`, `LEAN-MAP`, `GAMS-MAP`, `EVM-CONTROL-PRIMITIVES-MAP`).

### Theory & Literature

- [x] **LIT-01**: Curated bibliography for static payoff↔curve replication on CFMMs
  (AEC *Replicating Market Makers* Fenchel duality, Carr–Madan, Breeden–Litzenberger),
  with per-entry relevance to the static kernel (`LIT-CFMM.md`).
- [x] **LIT-02**: Curated bibliography for **static control on the tick/binomial
  lattice** — spatially-invariant systems, DFT decoupling, binomial backward
  induction, discrete BVP (`LIT-LATTICE-CONTROL.md`).
- [x] **LIT-03**: A single recommended theoretical frame is selected and justified
  against EVM constraints (spatially-invariant DFT control ≡ Carr–Madan spanning;
  on-chain = one banded Toeplitz/circulant matvec).

### Controller Catalog

- [x] **CAT-01**: A catalog of candidate static lattice controllers (target→actuator
  maps) derived from GAMS results + binomial periods + proven Lean inversions —
  each with formula, regime/feasibility, EVM cost, and source (`CONTROLLERS.md`).
- [x] **CAT-02**: Each controller is classified proven-and-EVM-ready vs gap, with a
  readiness×EVM-cost ranking (C1/C3/C5/C7/C9 ready; C2 needs fixed-point sqrt).

### Toolchain

- [x] **TLC-01**: A control-design modeling toolchain (the GAMS/Lean analog) is
  selected with rationale across symbolic / matrix / lattice / EVM-export /
  open-source criteria (`TOOLING-CONTROL-DSL.md`) — SymPy primary, Julia
  `Symbolics`/`ControlSystems` secondary.
- [x] **TLC-02**: The toolchain's place in the GAMS+Lean+Plank+`gamsDiff` pipeline
  is specified (design → exact-rational quantization → fixed-point evaluate → diff).

### Design Specification

- [x] **SPEC-01**: A consolidated static-control-kernel design basis integrates
  research/theory/catalog/tooling with the η=½ scope and η-split path
  (`STATIC-CONTROL-KERNEL-SPEC.md`, draft).
- [ ] **SPEC-02**: The on-chain realization is specified concretely — the banded
  Toeplitz/circulant matvec + per-position set-points + required fixed-point
  primitives (sqrt, signed mulDiv, clamp) + the saturate-never-revert rule + int24
  bounds/rounding per inversion.
- [ ] **SPEC-03**: A single end-to-end **proof case** (C2: σ_target→Δi⋆) is
  specified across every layer — SymPy derivation + exact-rational quantization →
  Lean existence (`sigma_xs_poly_target_exists`) → Plank fixed-point evaluation →
  `gamsDiff` fixture equality within tolerance.
- [ ] **SPEC-04**: The spec passes the mandatory two-step review (Reality Checker +
  Solidity Smart Contract Engineer). *(Deferred by user choice 2026-06-28; owed
  before any execution commit.)*

### Gap Register & Hand-off

- [ ] **GAP-01**: Open gaps are registered with severity and in-scope-to-close vs
  deferred: G1 stochastic swap-flow ground truth, G2 general-η impact/CES, G3 full
  σ_xs lift, G4 band-max interior hump, G5 fixed-point primitives, G6
  liquidity-kernel ξ/ι.
- [ ] **GAP-02**: A hand-off to the future *implementation* milestone is defined
  (it builds G5 primitives + the C2 proof case + eventually `CTRL-01`/`CTRL-02`),
  with `src/` layout coordination flagged for the Plank owner `ul2inqpl`.

### Controller-Design Intake (TODO.md)

- [x] **INTAKE-01**: A root `TODO.md` exists as the user↔agent worklist — it lists
  each merged GAMS/Lean optimization result on `develop` as a controller-design task
  (C1..C9 + blocked/awaiting), seeded from the `develop` merge history.
- [ ] **INTAKE-02**: A refresh mechanism is defined to append newly-merged GAMS
  optimization results since last sync (manual `gh`/`git log` block documented;
  automation script is a tracked follow-up).

## Out of Scope (this milestone)

| Item | Reason |
|------|--------|
| Implementing the controller in Plank (`src/DynamicCFMM.plk`) | Design/spec milestone; implementation is the next milestone (deferred `CTRL-01`) |
| V4 `beforeSwap` hook | Higher dynamic layer; deferred `CTRL-02` |
| Adaptive fee policy `φ(·;t)` / time feedback | KERNEL.md's dynamic layer, explicitly later |
| General η≠½ | Needs fixed-point pow/linearization (G2); η-split is the path |
| Stochastic order flow as a driver | Static layer assumes representative agent / fixed L̄ |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| RES-01 | Phase 8 | Complete |
| LIT-01 | Phase 8 | Complete |
| LIT-02 | Phase 8 | Complete |
| LIT-03 | Phase 8 | Complete |
| CAT-01 | Phase 9 | Complete |
| CAT-02 | Phase 9 | Complete |
| TLC-01 | Phase 9 | Complete |
| TLC-02 | Phase 9 | Complete |
| SPEC-01 | Phase 10 | Complete |
| SPEC-02 | Phase 10 | Complete |
| SPEC-03 | Phase 10 | Complete |
| SPEC-04 | Phase 10 | Deferred (review) |
| GAP-01 | Phase 11 | Pending |
| GAP-02 | Phase 11 | Pending |
| INTAKE-01 | Phase 11 | Complete |
| INTAKE-02 | Phase 11 | Pending |

**Coverage:** 16 requirements; 16 mapped (0 unmapped). 12 complete, 3 pending
(GAP-01, GAP-02, INTAKE-02 — Phase 11), 1 deferred (SPEC-04 review).

---
*Requirements defined: 2026-06-28 — scoped v2.0 controller design milestone.*
