# Project State

## Project Reference

See: control/.planning/PROJECT.md (updated 2026-08-08)

**Core value:** The artifact under construction is the artifact under proof — return a *verdict* on the boxed `τ*_MEV` (PROVEN or REFUTED, axiom-clean, with the counterexample if it falls), and per the 2026-08-08 scoping decision a *corrected law* where it refutes. A refutation is a successful outcome; an unverified restatement is not.
**Current focus:** Phase 1 — Rulings & Ground Truth

## Current Position

Phase: 1 of 8 (Rulings & Ground Truth)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-08-08 — ROADMAP.md created; 34/34 v1 requirements mapped

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Full log in PROJECT.md Key Decisions. Recent decisions affecting current work:

- [Scoping 2026-08-08]: Verdict **+ salvage** — where an obligation refutes, derive the corrected law and verify it too (SAL-01…SAL-05).
- [Scoping 2026-08-08]: The τ↔λ bridge is promoted to a full obligation P5 (PRF-05), not an implicit substitution.
- [Scoping 2026-08-08]: EVM feasibility is split — E0 (primitive inventory) early in Phase 2, E1 (law-specific) only after a verified law exists.
- [Roadmap]: Research Phase A split into Phases 1 and 2 so PITFALLS's entrywise `∂`-check (NOT-04) completes *before* FRAME's underactuation resolution is relied on.
- [Roadmap]: On P2 REFUTED, Phase 5 stays live (the corrected law's sign needs the same composition) — a deliberate deviation from ARCHITECTURE's "skip C/D/E1".
- [Roadmap]: Execution is sequential by user choice (`parallelization: false`) so an early refutation halts downstream spend.

### Pending Todos

None yet.

### Blockers/Concerns

- **Phase 1 is blocked on the user.** All 13 blocking decisions (NOT-01) require rulings; they are the cheapest, highest-leverage items on the board and all four researchers flagged them unanimously.
- **Record correction:** REQUIREMENTS.md said 31 v1 requirements; the actual count is **34**. Traceability and coverage corrected.
- **Halt gate at Phase 4** on `PRF-02` — 4 of 4 researchers predict REFUTED. The refuted branch routes to salvage, never to abort.
- **Zero pipeline steps run here.** The Lean tree, bundle assembly and the Aristotle API key belong to the Lean4+Math peer session; every obligation ships as a PROOF-REQUEST hand-off (PRF-10). Re-verify peer identity with `list_peers` before acting on any PID.
- **Two stale prior-art docs** (`v2-controller/LEAN-MAP.md`, `EVM-CONTROL-PRIMITIVES-MAP.md`) must be marked do-not-cite in Phase 1 before anything consumes them.

## Session Continuity

Last session: 2026-08-08
Stopped at: ROADMAP.md and STATE.md written; REQUIREMENTS.md traceability populated
Resume file: None
