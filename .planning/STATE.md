---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: milestone
status: completed
stopped_at: Completed 08-02-PLAN.md — Phase 8 COMPLETE (kernel mock + probe; arg-order mutant observed RED)
last_updated: "2026-07-16T13:02:37.170Z"
last_activity: "2026-07-16 — 08-02 executed: Algebra kernel mock + Plank ABI harness + differential probe (tolerance 0, anchor 819430); argument-order mutant OBSERVED red and restored green"
progress:
  total_phases: 11
  completed_phases: 2
  total_plans: 5
  completed_plans: 5
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-15)

**Core value (v2.0):** The Plank realized-volatility oracle's variance surface (`volatilityCumulative` / `averageTick`) is proven bit-exact against Algebra's `VolatilityOracle` — the reference of record — the way the tick-average surface already is (Phase 0–1, merged). Every proof is a passing/failing test or a killed mutation; `make compile-plank` green is NOT evidence.
**Current focus:** Phase 8 — Reference Integrity & Scalar-Vol Reconciliation

**Track note:** v2.0 is a separate, parallel track from the v1.0 GAMS-plumbing milestone (Phases 1–7), which remains incomplete/paused. The v1.0 core value and 30-requirement plumbing roadmap are preserved intact in ROADMAP.md and REQUIREMENTS.md.

## Current Position

Phase: 8 of 11 (Reference Integrity & Kernel Mock) — first v2.0 phase
Plan: 3 of 3 in Phase 8 — ALL COMPLETE (08-01 pin, 08-02 mock+probe, 08-03 VDIFF-03)
Status: Phase 8 COMPLETE — all 3 plans landed their summaries. VDIFF-01 marked complete (pin half by 08-01, mock half by 08-02). Ready for Phase 9 (VDIFF-02, the 5-D kernel fuzz).
Last activity: 2026-07-16 — 08-02 executed: Algebra kernel mock + Plank ABI harness + differential probe (tolerance 0, anchor 819430); argument-order mutant OBSERVED red and restored green

Progress (v2.0 milestone): [██████████] Phase 8 — 3 of 3 plans complete (08-01, 08-02, 08-03)

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
| Phase 08 P02 | 10m | 3 tasks | 4 files |

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
- [Phase 08]: 08-02 — the Plank kernel harness takes calldata in ALGEBRA's argument order, so ONE tuple drives both sides and the Algebra->Plank re-order is isolated to a SINGLE commented call site. That makes the parameter-order footgun mutable-in-one-place and therefore falsifiable; the swap-order mutant was OBSERVED red (exit 2) and restored green (exit 0).
- [Phase 08]: 08-02 — the probe asserts BOTH mock==Plank (tolerance 0) AND ==819430 (independently derived 3x). The differential assertion ALONE is insufficient: a mock that merely echoed Plank would satisfy it. The anchor pins Algebra to a value neither implementation can influence.
- [Phase 08]: 08-02 — non-degeneracy requires k!=0 AND b!=0. 08-CONTEXT phrases it as tick0!=tick1, which only secures k; b!=0 additionally needs tick0!=avgTick0. dt=30,tick0=100,tick1=-400,avgTick0=50,avgTick1=-100 satisfies both (k=-350,b=1500).

### Pending Todos

Phase 8 is COMPLETE — all 3 plans (08-01 pin, 08-02 mock+probe, 08-03 VDIFF-03) landed their
summaries. VDIFF-01 is marked complete. Next action: verify Phase 8, then plan Phase 9 (VDIFF-02 —
the 5-D kernel fuzz over `(dt, tick0, tick1, avgTick0, avgTick1)`), which starts from the
proven-wired kernel pair 08-02 delivered (`make test-vol-kernel-probe`).

**Carry into Phase 9 — CORRECTED (the 08-02 claim was a MISDIAGNOSIS; do not act on it):**
08-02's SUMMARY warns that the probe deploys from `build/plank/*.hex`, that a `.plk` edit is
invisible until `make compile-plank` re-runs, and that the mutation battery must therefore
recompile between every mutant "or its kills are fiction". **This is FALSE.** Verified two ways:

1. *Code:* `deployPlank` → `PlankDeployer.plankDeployFFI` → `plankBuildFFI`, which shells out to
   `plank build <root> --backend sona …` over FFI **at test time**. It never reads
   `build/plank/*.hex`. That directory is written by `make compile-plank` and is read by
   **nothing in the test path** — `compile-plank` is a standalone gate, not a test input.
2. *Empirically (decisive):* mutated the kernel coefficient (`6→7`) in
   `RealizedVolatilityLib.plk`, ran `forge test --match-contract RealizedVolatilityKernelProbe`
   with **no `make compile-plank`** — probe went **RED** (`729013 != 819430`). Restored →
   byte-identical → **GREEN**. Every `deployPlank` compiles the `.plk` fresh on every run.

**Therefore:** Phase 9's battery does NOT need to recompile between mutants. Recompiling is
harmless but pointless. More importantly, the false premise is corrosive — it would invite
someone to distrust VALID mutant kills (including the already-verified Phase 0-1 batteries, which
never ran `compile-plank` between mutants and were correct precisely because FFI recompiles).

The *underlying* instinct 08-02 had is still right and worth keeping: **a mutant that never
reaches the deployed bytecode proves nothing.** Here FFI guarantees it reaches. If a future test
ever deploys from a prebuilt artifact instead of `deployPlank`, this concern becomes real again —
check the deploy path before trusting a kill.

- Deferred items discovered during Phase 8 execution are logged in
  `.planning/phases/08-reference-integrity-kernel-mock/deferred-items.md` (not fixed in-phase).

### Blockers/Concerns

**v2.0 (from plank-voldiff-plan.md open risks):**
- ~~**Mutable, untracked differential reference** (Phase 8 / VDIFF-01)~~ — **RESOLVED by 08-01.** The whole 4-file import closure is pinned by `test/refs/algebra-volatility-oracle.sha256` and guarded by `make check-algebra-ref-pin`, wired as the FIRST prerequisite of `make test-vol-prereqs`. Red-on-divergence was OBSERVED (4 mutants, incl. the transitive-only file a single-file pin would miss), not assumed.
- **NEW — `package-lock.json` is UNTRACKED** (found by 08-01 Mutant D; CI/reproducibility track): the pin checker's own remediation, "run `npm ci` to restore", is **NOT executable on a fresh clone** — `npm ci` requires a lockfile, and the lockfile is not committed (the whole npm/hardhat surface is untracked on `feat/plank`). Pin checks #1 (sha over the actually-compiled bytes) and #2 (closure drift) are load-bearing and unaffected; check #3 (package identity) reads the untracked lockfile. **Must be resolved BEFORE Phase 9 relies on `make test-vol-prereqs` in CI.** See `.planning/phases/08-reference-integrity-kernel-mock/deferred-items.md`.
- **Falsifiability debt** (Phases 9–11 / VDIFF-08): a prior smoke suite was 6/6 green under deliberate bugs. No green is trusted until the mutation battery kills every mutant.
- **Vacuous-test traps** (Phases 9–10): constant-tick paths and `tick == 0` make assertions vacuous; corpora must force strict rises/falls by construction. `getTwapTick`-only assertions cancel compensating errors.
- **Parameter-order footgun** (Phase 9 / VDIFF-02) — **DE-RISKED, not closed, by 08-02.** The arg orders genuinely differ (`calculate_realized_volatility(avg_tick0, avg_tick1, tick0, tick1, dt)` vs `_volatilityOnRange(dt, tick0, tick1, avgTick0, avgTick1)`), but the re-order is now isolated to ONE commented call site in `RealizedVolatilityKernelHarness.plk`, and `make test-vol-kernel-probe` was OBSERVED red under the swap-order mutant. Phase 9's fuzz inherits that guard at a single point — it still owns the swap-order mutant across the 5-D domain, since one point cannot prove agreement everywhere.
- **Existing corpus never runs the windowed paths** (Phase 10 / VDIFF-05): the ≤2970 s corpus vs an 86400 s window never executes the binary search / interpolation / `window_start_index`; span > 2×WINDOW must be constructed and asserted.

**v1.0 (paused — carried forward):**
- Repo ownership inverted + destructive migration (Phase 1); publish-readiness leaks (Phase 1); Plank toolchain unpinned + silent-zero FFI (Phase 2); Plank sources stubs/parse-errors (Phase 4); bridge zero-line gap (Phase 6); GAMS solver deliberate stub (Phase 5).

## Session Continuity

Last session: 2026-07-16T13:02:37.167Z
Stopped at: Completed 08-02-PLAN.md — Phase 8 COMPLETE (kernel mock + probe; arg-order mutant observed RED)
Resume file: None
