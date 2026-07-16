---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Realized-Volatility Oracle Differential Testing
status: executing
stopped_at: Roadmap created for milestone v2.0 (Phases 8–11)
last_updated: "2026-07-15T00:00:00.000Z"
last_activity: "2026-07-15 — milestone v2.0 roadmap appended: Phases 8–11 derived from VDIFF-01..08, 8/8 mapped; v1.0 Phases 1–7 preserved/paused"
progress:
  total_phases: 4
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-15)

**Core value (v2.0):** The Plank realized-volatility oracle's variance surface (`volatilityCumulative` / `averageTick`) is proven bit-exact against Algebra's `VolatilityOracle` — the reference of record — the way the tick-average surface already is (Phase 0–1, merged). Every proof is a passing/failing test or a killed mutation; `make compile-plank` green is NOT evidence.
**Current focus:** Phase 8 — Reference Integrity & Scalar-Vol Reconciliation

**Track note:** v2.0 is a separate, parallel track from the v1.0 GAMS-plumbing milestone (Phases 1–7), which remains incomplete/paused. The v1.0 core value and 30-requirement plumbing roadmap are preserved intact in ROADMAP.md and REQUIREMENTS.md.

## Current Position

Phase: 8 of 11 (Reference Integrity & Kernel Mock) — first v2.0 phase
Plan: none yet (Phase 8 not yet planned)
Status: Not started — roadmap approved/created; next step `/gsd:plan-phase 8`
Last activity: 2026-07-15 — milestone v2.0 roadmap appended (Phases 8–11 from VDIFF-01..08, 8/8 mapped)

Progress (v2.0 milestone): [░░░░░░░░░░] 0% (0/4 phases)

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0 hours

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

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

**Milestone v2.0 (oracle differential testing):**
- Reference of record is Algebra's `VolatilityOracle`. WINDOW touches only `averageTick` and `volatilityCumulative`; `getTwapTick`/`getTickCumulative` are DONE and merged (Phase 0–1).
- `make compile-plank` passing is NOT evidence — Plank does not type-check code unreachable from `run{}`. A test proves something only by CALLING the module.
- Every new test MUST be mutation-verified falsifiable before it is trusted (VDIFF-08). A prior reviewer found 3 of 6 smoke tests survived deliberate bugs. The falsifiability gate is embedded in the success criteria of every test-producing phase (9, 10, 11), not only Phase 11.
- The differential reference is a mutable, untracked `node_modules` file — pin it FIRST (Phase 8 / VDIFF-01) so later phases build on a stable baseline.
- The corpus is CONSTRUCTED, not `vm.assume`-filtered (VDIFF-05/06). span > 2×WINDOW is required to execute the binary search / interpolation / `window_start_index`; a separate sub-WINDOW corpus is the only regime reaching `u32_sub`.
- Build on existing infra (do NOT re-create): `PlankTestBase.sol`, the Algebra + UniV3 refs, Plank's `getTimepointPacked`/`lastIndex`/`oldestIndex`/`readWindow`, `RealizedVolatility.diff.t.sol` (Phase 0–1 driver), and the `make test-vol-prereqs` target.
- Deferred (plan items 6–7): a UniV3 `OracleLib`-based volatility reference (UniV3 has no volatility accumulator; would diff Algebra against itself — low value).

**Milestone v1.0 (paused/parallel — preserved):**
- Plumbing-first scope: prove the connection layer carries parameters correctly with a stub GAMS solver; real optimization model + replication proof + LDF conformance are v2.
- Phase 4 (Plank bridge-surface) implemented AND compiled BEFORE the bridge wiring (Phase 6) — resolves prior phase-order inversion.
- Phases 1 and 2 serialized (no parallelism) to avoid the repo-identity race during the public flip / fork migration.
- Theory grounding links to cfmm-theory `KERNEL.md` by URL/citekey (no submodule); refs under `spec/refs/`.
- [Phase 01]: 01-01 executed — MIT LICENSE (wvs-finance); orphan-branch squash to one sanitized baseline; GAMS paths relativized to in-repo `model/`; recovery bundle + backup/pre-squash captured before rewrite.

### Pending Todos

None yet for v2.0. Next action: `/gsd:plan-phase 8`.

### Blockers/Concerns

**v2.0 (from plank-voldiff-plan.md open risks):**
- **Mutable, untracked differential reference** (Phase 8 / VDIFF-01): `node_modules/@cryptoalgebra/.../VolatilityOracle.sol` is the oracle for the whole exercise and `npm ci` silently replaces it (already accidentally hand-edited once). Vendor/checksum-pin before any later diff work.
- **Falsifiability debt** (Phases 9–11 / VDIFF-08): a prior smoke suite was 6/6 green under deliberate bugs. No green is trusted until the mutation battery kills every mutant.
- **Vacuous-test traps** (Phases 9–10): constant-tick paths and `tick == 0` make assertions vacuous; corpora must force strict rises/falls by construction. `getTwapTick`-only assertions cancel compensating errors.
- **Parameter-order footgun** (Phase 9 / VDIFF-02): `calculate_realized_volatility` arg order differs from Algebra's `_volatilityOnRange`; the kernel diff must guard it with a swap-order mutant.
- **Existing corpus never runs the windowed paths** (Phase 10 / VDIFF-05): the ≤2970 s corpus vs an 86400 s window never executes the binary search / interpolation / `window_start_index`; span > 2×WINDOW must be constructed and asserted.

**v1.0 (paused — carried forward):**
- Repo ownership inverted + destructive migration (Phase 1); publish-readiness leaks (Phase 1); Plank toolchain unpinned + silent-zero FFI (Phase 2); Plank sources stubs/parse-errors (Phase 4); bridge zero-line gap (Phase 6); GAMS solver deliberate stub (Phase 5).

## Session Continuity

Last session: 2026-07-15
Stopped at: Milestone v2.0 roadmap created (Phases 8–11)
Resume file: None — next step is `/gsd:plan-phase 8`
