# Milestone v2.0 — Static Control Kernel (Design & Specification)

> Scoped milestone. Lives under `.planning/milestones/v2-controller/` to avoid
> disrupting the shared, in-flight v1 (open-loop plumbing) planning that all peers
> work against. Branch `feat/evm-controller`; ships via PR→`develop`.

## Goal

Round out the **complete design basis** for an EVM-feasible **static** controller
that operates on the **tick lattice** (spatial index, not time) — so a downstream
*implementation* milestone can build the proof-case controller without further
research. This milestone is **design/specification + curated knowledge base**, not
implementation.

## Relationship to v1 and to the deferred CTRL-* implementation

- v1 (open-loop plumbing, Phases 1–7) builds the GAMS→encode→Plank write/read
  bridge this controller will eventually sit on.
- The *implementation* of the closed/Plank controller (`src/DynamicCFMM.plk`) and
  any V4 `beforeSwap` hook — the original `CTRL-01`/`CTRL-02` — remain **deferred to
  a future implementation milestone** that THIS spec milestone enables.

## Scope (locked)

- Static, low-level kernel layer only: fixed `L̄`, representative agent, **η = ½**
  (η-split `eta_split_kernel_identity` is the documented generalization path).
- Iteration index is **spatial** (tick / binomial lattice), not time.
- OUT: adaptive fee policy `φ(·;t)`, time feedback loop, V4 hook, general η≠½,
  stochastic order flow as a driver.

## Key decisions

| Decision | Rationale |
|----------|-----------|
| Theoretical frame = spatially-invariant control over the lattice (DFT-diagonalized, BPD) ≡ Carr–Madan/Breeden–Litzenberger static spanning | Only frame where the index is genuinely spatial; pushes synthesis off-chain, leaves one Toeplitz/circulant matvec on-chain |
| Design toolchain = **SymPy** primary + **Julia `Symbolics`/`ControlSystems`** secondary | SymPy = GAMS/Lean analog for static algebraic inversion, exact-rational quantization, already in-repo; Julia for matrix/DFT gains + C oracle |
| η = ½ now; η-split as path | Only EVM-testable / fully-proven case |
| Planning kept scoped, not in shared root docs | v1 is in-flight across 7 peers |
| Two-step review deferred (user choice, 2026-06-28) | User opted to proceed to requirements/roadmap first; review owed before any execution commit |

See `../../research/v2-controller/STATIC-CONTROL-KERNEL-SPEC.md` for the full basis.
