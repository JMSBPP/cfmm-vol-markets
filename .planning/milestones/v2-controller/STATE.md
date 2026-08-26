---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: static-control-kernel
scope: design-spec (not implementation)
branch: feat/evm-controller
status: defining
last_updated: "2026-06-28"
progress:
  total_phases: 4
  completed_phases: 2
  percent: 55
---

# Milestone v2.0 State — Static Control Kernel (Design & Specification)

> Scoped milestone state. Does NOT replace the shared root `.planning/STATE.md`
> (v1 open-loop plumbing, in-flight across peers). Branch `feat/evm-controller`.

## Reference

Milestone context: `MILESTONE.md` · Requirements: `REQUIREMENTS.md` ·
Roadmap: `ROADMAP.md` · Research base: `../../research/v2-controller/`.

**Core value:** A complete, EVM-feasible design basis for a static (tick-lattice)
control kernel — theory, controller catalog, toolchain, on-chain realization, gap
hand-off — sufficient for a downstream implementation milestone.

## Current Position

Phase: 10 (Consolidated Spec) — **content-complete**; SPEC-04 two-step review is the
lone deferred gate. Phases 8 & 9 complete; Phase 11 (gaps, intake & hand-off) in progress.
Status: SPEC-01/02/03 done — `STATIC-CONTROL-KERNEL-SPEC.md` (CONTENT-COMPLETE),
`ON-CHAIN-REALIZATION.md` (SPEC-02), `C2-PROOF-CASE.md` (SPEC-03), plus exercise
`exercises/EX-01-zero-slippage-spacing-controller.md` and root `TODO.md` intake.
Last activity: 2026-06-28 — executed Phase 10 waves 1–2 (3 plans); wave 3 / SPEC-04
review deferred per user. Nothing committed (commit + PR→develop gated/owed).

## Accumulated Context

### Decisions
- Scope: static, tick-lattice, η=½, fixed L̄, representative agent (NOT dynamic/hook).
- Frame: spatially-invariant DFT control ≡ Carr–Madan spanning; on-chain = one
  banded Toeplitz/circulant matvec; synthesis off-chain.
- Toolchain: SymPy primary + Julia `Symbolics`/`ControlSystems` secondary.
- Planning kept scoped to avoid disrupting in-flight v1 across 7 peers.
- Two-step review deferred by user (owed before any execution commit).

### Proven-and-EVM-ready controllers
C1 (zero-slippage Δi⋆), C3 (band-min clamp), C5 (small-signal gain),
C7 (η-split), C9 (realized-variance). C2 (σ_target→Δi⋆) pending fixed-point sqrt.

### Open gaps
G1 stochastic swap-flow ground truth · G2 general-η · G3 full σ_xs lift ·
G4 band-max hump · G5 fixed-point primitives (signed mulDiv/sqrt/clamp) ·
G6 liquidity-kernel ξ/ι.

### Pending
- SPEC-02 (on-chain realization detail), SPEC-03 (C2 proof-case spec).
- SPEC-04 two-step review (deferred).
- GAP-01/02 (gap register + implementation-milestone hand-off).
- Not yet committed/pushed; PR→develop is the gated step (awaiting user go-ahead).
