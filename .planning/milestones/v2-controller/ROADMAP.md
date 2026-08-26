# Roadmap: Milestone v2.0 — Static Control Kernel (Design & Specification)

**4 phases** (8–11, continuing v1's Phases 1–7) | **14 requirements mapped** | All covered ✓

This milestone is design/specification. Phases 8–9 are already complete (the
research base was produced this session); Phases 10–11 finish the consolidated spec
and the gap/hand-off plan. Implementation of the controller is a *separate future
milestone* that this roadmap hands off to.

| # | Phase | Goal | Requirements | Status |
|---|-------|------|--------------|--------|
| 8 | Mapping & Theory | Map existing work; curate theory + select frame | RES-01, LIT-01..03 | ✓ Complete |
| 9 | Catalog & Toolchain | Controller catalog; select control-design toolchain | CAT-01/02, TLC-01/02 | ✓ Complete |
| 10 | Consolidated Spec | Finish the static-control-kernel spec + on-chain realization + proof case | SPEC-01..04 | ✓ Content-complete (SPEC-04 review deferred) |
| 11 | Gaps, Intake & Hand-off | Gap register; controller-design TODO.md intake; implementation hand-off | GAP-01/02, INTAKE-01/02 | ◆ In progress |

## Phase Details

### Phase 8: Mapping & Theory  ✓
**Goal:** A complete, evidence-cited picture of the existing system and the theory
that grounds a static lattice controller; a single recommended theoretical frame.
**Delivered:** `PROJECT-MAP`, `LEAN-MAP`, `GAMS-MAP`, `EVM-CONTROL-PRIMITIVES-MAP`,
`MAPPING-SYNTHESIS`, `LIT-CFMM`, `LIT-LATTICE-CONTROL`.
**Success criteria:**
1. Existing work mapped across branches/worktrees, Lean, GAMS, EVM primitives.
2. Static-replication + lattice-control bibliographies curated with relevance notes.
3. One theoretical frame selected and justified vs EVM constraints.

### Phase 9: Catalog & Toolchain  ✓
**Goal:** An actionable list of candidate controllers and the chosen design toolchain.
**Delivered:** `CONTROLLERS.md`, `TOOLING-CONTROL-DSL.md`.
**Success criteria:**
1. ≥1 catalog of static lattice controllers (target→actuator) from GAMS+binomial+Lean.
2. Each controller classified proven-EVM-ready vs gap, ranked by readiness×cost.
3. A control-design toolchain selected with rationale and pipeline placement.

### Phase 10: Consolidated Spec  ✓ (content-complete; SPEC-04 review deferred)
**Depends on:** Phases 8–9.
**Goal:** A single design basis that an implementation milestone can build from,
including the concrete on-chain realization and one end-to-end proof case.
**Success criteria:**
1. Consolidated spec integrates research/theory/catalog/tooling (SPEC-01). *(draft done)*
2. On-chain realization specified: Toeplitz/circulant matvec + set-points +
   required fixed-point primitives + saturate-never-revert + int24 bounds (SPEC-02).
3. C2 (σ_target→Δi⋆) proof case specified across SymPy→Lean→Plank→gamsDiff (SPEC-03).
4. Two-step review (Reality Checker + Solidity Smart Contract Engineer) (SPEC-04).
   *(Deferred by user; owed before any execution commit.)*

**Plans:** 4 plans across 3 waves.
- [x] 10-01-PLAN.md — SPEC-02: ON-CHAIN-REALIZATION.md (matvec layout + set-points + G5 primitives + saturate-never-revert + int24 bounds) [wave 1] ✓
- [x] 10-02-PLAN.md — SPEC-03: C2-PROOF-CASE.md (SymPy→Lean→Plank→gamsDiff, with feasibility preconditions) [wave 1] ✓
- [x] 10-03-PLAN.md — SPEC-01: finalize STATIC-CONTROL-KERNEL-SPEC.md by integrating the two sibling docs [wave 2, depends_on 10-01,10-02] ✓
- [ ] 10-04-PLAN.md — SPEC-04: DEFERRED two-step review gate (blocked-on-user; tracked, not auto-run) [wave 3, depends_on 10-03, autonomous: false] ⏸ deferred

### Phase 11: Gaps, Intake & Hand-off  ◆
**Depends on:** Phase 10.
**Goal:** Every open gap registered with severity and disposition; the controller-
design TODO.md intake live; and a clean hand-off to the implementation milestone.
**Success criteria:**
1. Gap register G1–G6 with severity + in-scope vs deferred (GAP-01).
2. Implementation-milestone hand-off defined (G5 primitives + C2 proof case +
   eventual `CTRL-01`/`CTRL-02`), with `src/` layout coordination flagged for
   `ul2inqpl` (GAP-02).
3. Root `TODO.md` user↔agent worklist exists, seeded from merged GAMS results, with
   a defined refresh mechanism (INTAKE-01/02). *(INTAKE-01 done this session.)*

## Progress

| Phase | Status | Completed |
|-------|--------|-----------|
| 8. Mapping & Theory | ✓ Complete | 2026-06-28 |
| 9. Catalog & Toolchain | ✓ Complete | 2026-06-28 |
| 10. Consolidated Spec | ◆ In progress | — |
| 11. Gaps, Intake & Hand-off | ◆ In progress (INTAKE-01 done) | — |

Progress: ████████░░ ~55% (design milestone; research phases done)
