---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: milestone
status: executing
stopped_at: Completed 08-01-PLAN.md (Algebra reference pin, 4 mutants observed RED)
last_updated: "2026-07-16T12:52:21.609Z"
last_activity: "2026-07-16 — 08-01 executed: Algebra 4-file reference closure pinned + wired first into `make test-vol-prereqs`; 4 mutants OBSERVED red and restored green"
progress:
  total_phases: 11
  completed_phases: 1
  total_plans: 5
  completed_plans: 4
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-15)

**Core value (v2.0):** The Plank realized-volatility oracle's variance surface (`volatilityCumulative` / `averageTick`) is proven bit-exact against Algebra's `VolatilityOracle` — the reference of record — the way the tick-average surface already is (Phase 0–1, merged). Every proof is a passing/failing test or a killed mutation; `make compile-plank` green is NOT evidence.
**Current focus:** Phase 8 — Reference Integrity & Scalar-Vol Reconciliation

**Track note:** v2.0 is a separate, parallel track from the v1.0 GAMS-plumbing milestone (Phases 1–7), which remains incomplete/paused. The v1.0 core value and 30-requirement plumbing roadmap are preserved intact in ROADMAP.md and REQUIREMENTS.md.

## Current Position

Phase: 8 of 11 (Reference Integrity & Kernel Mock) — first v2.0 phase
Plan: 3 of 3 in Phase 8 (08-01 and 08-03 COMPLETE; 08-02 in flight)
Status: Executing — 08-01 (pin) and 08-03 (VDIFF-03) closed; Phase 8 completes when 08-02 (mock) lands its summary
Last activity: 2026-07-16 — 08-01 executed: Algebra 4-file reference closure pinned + wired first into `make test-vol-prereqs`; 4 mutants OBSERVED red and restored green

Progress (v2.0 milestone): [█████░░░░░] Phase 8 — 2 of 3 plans complete (08-01, 08-03)

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
| Phase 08 P03 | 11min | 1 tasks | 1 files |
| Phase 08 P01 | 12m | 3 tasks | 4 files |

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
- [Phase 08]: [Phase 08 / VDIFF-03]: the 'incorrect assertion' diffing Plank's raw get_average_volatility against Algebra's window-normalized getAverageVolatility NEVER EXISTED — re-verified by grep before editing. The real target was an unused declaration in IRealizedVolatility (loaded gun, never called). Removed + documented; smoke suite unchanged 11/11. Algebra's window-normalized getter was NOT ported (deferred, verified: no Bessel in any .plk).
- [Phase 08]: [Phase 08]: 08-01 — pin mechanism is a sha256 manifest over the node_modules copy (the bytes foundry.toml:18 actually compiles), NOT vendoring under lib/: vendoring would guard a copy nothing links (pin theatre). Pinned bytes == compiled bytes by construction.
- [Phase 08]: [Phase 08]: 08-01 — the pin covers the WHOLE 4-file import closure, not just VolatilityOracle.sol. Proven necessary: Mutant A (transitive-only IVolatilityOraclePluginImplementation.sol) went RED where a single-file pin would have stayed green.
- [Phase 08]: [Phase 08]: 08-01 — checker accumulates failures instead of short-circuiting, so the closure-drift guard is observable independently of the content hash (resolved the plan's '(drift guard OR sha)' hedge to AND).

### Pending Todos

Phase 8 is planned (3 plans) and executing. 08-03 (VDIFF-03) is complete; 08-01 (reference pin) and
08-02 (`_volatilityOnRange` mock) are in flight. Next action: land 08-01/08-02, then verify Phase 8.

- Deferred items discovered during Phase 8 execution are logged in
  `.planning/phases/08-reference-integrity-kernel-mock/deferred-items.md` (not fixed in-phase).

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

Last session: 2026-07-16T12:51:46.269Z
Stopped at: Completed 08-01-PLAN.md (Algebra reference pin, 4 mutants observed RED)
Resume file: None
