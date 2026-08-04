---
phase: 09-variance-kernel-unit-diff-full-timepoint-diff
plan: 01
subsystem: testing
tags: [forge, fuzz, differential-testing, plank, algebra, volatility-oracle, mutation-testing, ffi]

# Dependency graph
requires:
  - phase: 08-reference-integrity-kernel-mock
    provides: "AlgebraVolatilityKernelMock (Algebra's _volatilityOnRange exposed externally), RealizedVolatilityKernelHarness.plk (selector 0xc6342af0, Algebra arg order, single re-order call site), RealizedVolatilityKernel.probe.t.sol (single-point wiring proof + anchor 819430), test/refs/algebra-volatility-oracle.sha256 + make check-algebra-ref-pin"
provides:
  - "VDIFF-02 discharged: the 5-D variance-kernel differential fuzz, tolerance 0 on the full uint256, green at 1024 runs"
  - "make test-vol-kernel-fuzz, folded into test-vol-prereqs (pin still FIRST)"
  - "Observed-RED falsifiability proof for two mutants (arg-order swap; kernel coefficient 6->7), both restored byte-identical and green"
  - "Empirical re-confirmation that the mutation battery needs NO make compile-plank: deployPlank recompiles the .plk over FFI at test time"
  - "Corrected selector fact: 0xc6342af0 == volatilityOnRange(int256,int256,int256,int256,int256), NOT (uint32,int24,int24,int24,int24)"
affects: [09-02-full-timepoint-diff, 10-corpus-construction, 11-edges-and-mutation-battery]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CONSTRUCTED corpus via deterministic repair (no assume-cheatcode filtering) so every fuzz run is a live assertion"
    - "Non-degeneracy asserted in-test on BOTH k != 0 and b != 0, guarding against a vacuous assertEq(0, 0)"
    - "Falsifiability recorded IN-FILE (WHAT THIS KILLS docblock) with the observed counterexample, not merely in the summary"
    - "Mutant kills re-run against a CLEARED fuzz failure cache so a kill is on its own merits, not a replayed cached counterexample"

key-files:
  created:
    - test/market_state_measurements/RealizedVolatilityKernel.diff.t.sol
  modified:
    - Makefile

key-decisions:
  - "09-01: selector 0xc6342af0 is volatilityOnRange(int256 x5) -- VERIFIED with cast sig. 09-CONTEXT.md's (uint32,int24,int24,int24,int24) claim is FALSE (that hashes to 0x5fb3d926). int256 is also semantically right: the harness reads whole 32-byte words as sign-extended two's-complement, which is exactly Solidity's int256 ABI encoding. The harness's own header comment was correct; the CONTEXT doc is wrong."
  - "09-01: tolerance 0 held across 1024 runs with ZERO counterexamples -- consistent with the review's proof that exactness is GUARANTEED (matching operator trees, no wrap on either side at numerator ~2^149, evm_sdiv == SDIV). No tolerance was added and no bound was softened."
  - "09-01: Mutant A's failure value was ~2^256 (115792...485613 != 787251601984), which is direct evidence that asserting the FULL uint256 rather than the 88-bit production width is load-bearing, not merely 'free' -- the divergence lives in the high bits a uint88 comparison would discard."
  - "09-01: Mutant B was re-run after clearing cache/fuzz so the kill came from a FRESH corpus with an independent counterexample, not from replaying Mutant A's cached entry. A kill via a replayed cached counterexample would be a weaker claim than it looks."
  - "09-01: re-confirmed empirically that NO make compile-plank is needed between mutants -- Mutant B produced a numeric divergence from a .plk edit alone. 08-02's contrary SUMMARY claim stays FALSE."

patterns-established:
  - "Repair-don't-reject: bound() then nudge, ordered so the k-repair (touches tick1) cannot undo the b-repair (touches avgTick0)"
  - "Doc-vs-reality conflicts are resolved by executing the check (cast sig), not by trusting the planning doc"

requirements-completed: [VDIFF-02]

# Metrics
duration: 6min
completed: 2026-07-16
---

# Phase 9 Plan 01: Variance-Kernel Unit Diff Summary

**The 5-D variance-kernel differential fuzz (VDIFF-02): `(dt, tick0, tick1, avgTick0, avgTick1)` driven through Algebra's `_volatilityOnRange` and Plank's `calculate_realized_volatility`, asserting FULL-uint256 equality at tolerance 0 over a constructed non-degenerate domain — green at 1024 runs, with both mutants OBSERVED red.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-16T17:18:37Z
- **Completed:** 2026-07-16T17:24:55Z
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- **VDIFF-02 discharged.** One tuple, both kernels, full uint256, tolerance 0, **1024 runs, zero counterexamples**. Phase 8's probe proved the pair was *wired*; this proves they *agree across the domain*.
- **Tolerance 0 held with no hedging.** No tolerance added, no domain shrunk, no trap bounded away. The green is consistent with the review's proof that exactness is *guaranteed* within int24 × uint32 — not an empirical hope.
- **Both mutants APPLIED and OBSERVED red**, with verbatim failure output captured, then restored byte-identical and re-run green. No kill was asserted from reasoning.
- **A doc error found and corrected by execution** (see Findings): the selector signature recorded in 09-CONTEXT.md is wrong.
- **The FFI/compile-plank correction re-confirmed decisively** — Mutant B produced a numeric divergence from a `.plk` edit with no `make compile-plank` anywhere in the battery.

## The Mutant Table — the deliverable

**No `make compile-plank` was run at any point in this battery.** `deployPlank` → `plankDeployFFI` → `plankBuildFFI` shells out to `plank build` over FFI **at test time**; `build/plank/*.hex` is written by `make compile-plank` and read by **nothing** in the test path. The REDs below are therefore genuine: the `.plk` edit reached the deployed bytecode on the very next `forge test`. (08-02's SUMMARY claims a recompile is mandatory "or its kills are fiction" — that claim is **FALSE**; STATE.md carries the correction, and Mutant B re-confirms it: a coefficient edit alone moved the returned number.)

| # | Edit | Observed exit | Verbatim `[FAIL: ...]` line | Restored exit |
|---|------|---------------|------------------------------|---------------|
| **A** | `RealizedVolatilityKernelHarness.plk:49` — the single re-order call site, from Plank's order `calculate_realized_volatility(avg_tick0, avg_tick1, tick0, tick1, dt)` to **Algebra's** order `calculate_realized_volatility(dt, tick0, tick1, avg_tick0, avg_tick1)` | **2** (RED) | `[FAIL: kernel 5-D: plank vs algebra, tolerance 0, full uint256: 115792089237316195423570985008687907853269984665640564039457584003616512485613 != 787251601984; counterexample: calldata=0x05cc4b42...; args=[0, 398, 0, 4210, -887272 [-8.872e5]]] test__fuzz__kernelAlgebraEqualsPlankFiveDim(uint32,int32,int32,int32,int32) (runs: 0, μ: 0, ~: 0)` | **0** (`runs: 1025`, PASS) |
| **B** | `RealizedVolatilityLib.plk:32` — the kernel middle-term coefficient, `+% 6 *% b *% k *% sumOfSequence` → `+% 7 *% b *% k *% sumOfSequence` | **2** (RED) | *(fresh corpus, cache cleared)* `[FAIL: kernel 5-D: plank vs algebra, tolerance 0, full uint256: 857507691265 != 857256149370; counterexample: calldata=0x05cc4b42...; args=[887272 [8.872e5], -887272 [-8.872e5], 2820, -887272 [-8.872e5], 4522]] test__fuzz__kernelAlgebraEqualsPlankFiveDim(uint32,int32,int32,int32,int32) (runs: 0, μ: 0, ~: 0)` | **0** (`runs: 1024`, PASS) |

Restoration was verified by `git diff --stat` printing **nothing** for both `.plk` files (byte-identical to HEAD, not "looks right"). `git diff --stat -- node_modules` also printed nothing — the reference was never touched.

### Two observations worth carrying forward

1. **Mutant A's left-hand value is ~2^256** (`115792089237316195423570985008687907853269984665640564039457584003616512485613` ≈ `2^256 - 1.6e19`). The swap feeds `dt` where a tick is expected, so the wrapping operators produce a near-full-width word. This is **direct evidence that asserting the FULL uint256 rather than the 88-bit production width is load-bearing, not merely "stronger on a free axis"** — the divergence lives precisely in the high bits a `uint88` comparison would have discarded. The CONTEXT's "free axis" framing undersells it.

2. **Mutant B's first RED came from the cached failure corpus** (`runs: 0`, replaying Mutant A's counterexample). That is a weaker claim than it appears, so the fuzz failure cache (`cache/fuzz`) was **cleared and Mutant B re-run**: it died again on a **new, independent counterexample** with different args. The table above records the fresh-corpus kill. Both restore-runs were likewise done against a cleared cache where relevant.

## Task Commits

1. **Task 1: The 5-D variance-kernel differential fuzz** — `2dca268` (test)
2. **Task 2: Falsifiability — both mutants observed RED, restored, green** — `baa91c7` (test)

## Files Created/Modified

- `test/market_state_measurements/RealizedVolatilityKernel.diff.t.sol` — **created.** `RealizedVolatilityKernelDiffTest`: the VDIFF-02 fuzz plus the in-file docblock recording why tolerance 0 is guaranteed (matching operator trees; numerator peaks ~2^149 ≪ 2^256 so neither side wraps; `evm_sdiv` **is** SDIV), why it is regime-conditional (not claimed in Algebra's int56-overflow regime), why `dt ≥ 1` (dt=0 is a known excluded divergence: Solidity `/` reverts Panic 0x12 under `unchecked`, EVM SDIV returns 0 silently), why the full uint256, **what it kills** (both mutants, with observed counterexamples), and what it does **not** replace (the probe's independent anchor 819430).
- `Makefile` — **modified.** Added `test-vol-kernel-fuzz`; appended it to the END of `test-vol-prereqs` and to `.PHONY`. Existing prerequisites were not reordered — `check-algebra-ref-pin` stays FIRST.

## Verification (observed, not asserted)

| Check | Result |
|---|---|
| `make test-vol-kernel-fuzz` | exit **0**; `[PASS] test__fuzz__kernelAlgebraEqualsPlankFiveDim(uint32,int32,int32,int32,int32) (runs: 1024, μ: 14788, ~: 14747)` |
| `make test-vol-prereqs` | exit **0** end-to-end; `OK: Algebra reference pin intact (4 files, v2.2.0)` printed **before** any forge invocation. Downstream: MarketStatistics 7/7, Smoke 11/11, Diff 2/2, Probe 1/1, Fuzz 1/1 |
| `make check-algebra-ref-pin` | exit **0** — `OK: Algebra reference pin intact (4 files, v2.2.0)`. **The baseline did not move; nothing was re-pinned.** |
| `grep -c "vm.assume"` | **0** — corpus is CONSTRUCTED, not filtered |
| `grep -c "uint88"` | **0** — assertion is on the full uint256 |
| `grep -c "887272"` | **3** (≥2 required) |
| `grep -c "4294967295"` + dt-bound grep | **1** each — `dt ∈ [1, 2^32)`, 0 excluded by construction |
| `assertTrue(k != 0` / `assertTrue(b != 0` | present — both asserted every run |
| `git diff --stat` on probe | **empty** — probe and its anchor 819430 untouched |
| `git diff --stat` on both `.plk` + `node_modules` | **empty** — no mutant residue |

No acceptance criterion in this plan was "it compiles". `forge build` appeared only as an implicit precondition of running the tests.

## Decisions Made

- **Selector signature corrected against the doc.** `cast sig` was run rather than trusting 09-CONTEXT.md; see Findings.
- **Mutant B re-run from a cleared cache.** A kill via a replayed cached counterexample is a weaker claim than a fresh-corpus kill; the stronger evidence was obtained rather than reported as-is.
- **Task 1 was marked `tdd="true"`, but the RED phase is Task 2, not a synthetic pre-failure.** The artifact here IS the test; there is no production code to drive red→green (the kernels already exist and already agree). Writing a deliberately-broken assertion first would have proved nothing about the kernels. The genuine falsifiability evidence is Task 2's two observed REDs, which is exactly what a TDD RED is *for*. This is recorded rather than papered over with a fake red.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] NatSpec rejected the Plank at-sigil in the docblock**
- **Found during:** Task 1
- **Issue:** The docblock wrote `` `@evm_sdiv` `` verbatim. solc's NatSpec parser reads a leading `@` inside a docblock as a documentation tag and hard-errored: `Error (6546): Documentation tag @evm_sdiv` not valid for contracts.` — compilation failed, so the fuzz could not run at all. Escaping it as a bare `` `@` `` produced the same class of error (`Documentation tag @` not valid`).
- **Fix:** Reworded to `Plank's evm_sdiv builtin` / "at-sigil", with an in-file note explaining *why* the sigil is spelled out, so a future reader does not "fix" it back and re-break the build.
- **Files modified:** `test/market_state_measurements/RealizedVolatilityKernel.diff.t.sol`
- **Verification:** `make test-vol-kernel-fuzz` compiles and passes at 1024 runs.
- **Committed in:** `2dca268` (Task 1 commit)

**2. [Rule 1 - Bug] The plan's own acceptance criterion was self-defeating on `vm.assume`**
- **Found during:** Task 1
- **Issue:** The plan requires `grep -c "vm.assume"` to print `0`, but also requires a docblock explaining *why* the corpus is not assume-filtered. The first draft's explanatory prose used the literal token twice, so the grep printed `2` — the file was correct in substance but failed its own gate.
- **Fix:** Reworded the prose to "assumption-filtered" / "the assume cheatcode", keeping the explanation while making the policy grep-enforceable. The docblock now says so explicitly.
- **Files modified:** `test/market_state_measurements/RealizedVolatilityKernel.diff.t.sol`
- **Verification:** `grep -c "vm.assume"` → `0`; fuzz still green at 1024 runs.
- **Committed in:** `2dca268` (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug). No Rule 4 (architectural) situations arose.
**Impact on plan:** Both were mechanical and necessary to make the plan's own criteria satisfiable. No scope creep; no criterion weakened.

## Findings — report, do not smooth over

**FINDING 1 (doc error, corrected): 09-CONTEXT.md records the harness selector signature incorrectly.**
09-CONTEXT.md (canonical_refs) and the execution brief both state:
> Selector `0xc6342af0` = `volatilityOnRange(uint32,int24,int24,int24,int24)`

That is **false**, verified by execution rather than argument:
```
cast sig "volatilityOnRange(int256,int256,int256,int256,int256)"  -> 0xc6342af0
cast sig "volatilityOnRange(uint32,int24,int24,int24,int24)"      -> 0x5fb3d926
```
The harness's own header comment (`signature:: volatilityOnRange(int256,...)`, "Verified with: cast sig") is the correct one, the plan's `<interfaces>` block agrees, and the green Phase-8 probe — which calls through an `int256×5` interface — confirms it. `int256` is also the semantically right choice: the harness reads whole 32-byte calldata words and uses them as sign-extended two's-complement, which is exactly Solidity's `int256` ABI encoding; an `int24`-typed interface would encode identically but misdescribe the contract. **Impact:** none on this plan (the correct signature was used, and it is now documented in-file). **Action for 09-02 and later:** treat the harness header as authoritative over 09-CONTEXT.md on this point; the CONTEXT line should be corrected if it is reused.

**FINDING 2 (no divergence): the fuzz found no counterexample.** 1024 runs at tolerance 0 on the full uint256, zero failures. Per the plan's standing instruction, a real divergence would have been the most valuable output — there wasn't one, and nothing was adjusted to manufacture the green. The pass is corroborated, not merely trusted, by the two observed REDs: the same 1024-run configuration kills both mutants on the first run it reaches.

**FINDING 3 (scope, not acted on):** `cache/fuzz/failures` also holds cached counterexamples for `OrderTest`, `SpreadTickAssimetryTest` and `VolRangeWidthTest` — i.e. those suites have recorded failures at some point. This is **out of scope** for 09-01 (pre-existing, unrelated to this task's changes) and was **not** investigated or fixed; `rm -rf cache/fuzz` here only cleared the local, regenerable cache and changed no tracked file. Flagging it because a stale failure cache can make an unrelated suite appear to fail on `runs: 0` for a reason that no longer exists.

## Issues Encountered

- **The NatSpec at-sigil error** (see Deviations #1) — the only real blocker; two iterations to resolve.
- **Mutant B's first kill was a cache replay** — noticed rather than reported at face value; resolved by clearing `cache/fuzz` and re-running for an independent counterexample.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **VDIFF-02 is discharged.** ROADMAP SC-1 (the fuzz exists and is green) and SC-2 (the arg-order mutant is KILLED) both hold **by observation**. SC-4's first named mutant (kernel coefficient `6→7`) makes a Phase 9 assertion FAIL, with baseline and restored source green.
- **09-02 (VDIFF-04, the full-timepoint diff) is unblocked.** It needs its own Algebra+Plank-only driver — do NOT reuse `RealizedVolatility.diff.t.sol`'s `_writeAll` (it drives UniV3 too, at ~11.5M gas/run for data never compared). Its field list is exactly `volatilityCumulative`, `averageTick`, `windowStartIndex`; `oldestIndex` is excluded as vacuous below 65,536 writes.
- **Carry the FFI fact forward:** the battery needs no `make compile-plank` between mutants. Now confirmed a third time (08-02 empirical, plus Mutants A and B here). The kept caveat still stands: a mutant must reach the *deployed* bytecode — FFI guarantees it here; if a future test ever deploys from a prebuilt artifact, re-check the deploy path before trusting a kill.
- **Do not pull Phase 10 forward:** the `span > 2×WINDOW` corpus and the sub-WINDOW `u32_sub` corpus remain Phase 10.
- **No blockers.** The Algebra pin exits 0; the baseline did not move.

## Self-Check: PASSED

Every claim above was re-verified against disk and git, not trusted:

- Files exist: `test/market_state_measurements/RealizedVolatilityKernel.diff.t.sol` (165 lines, ≥80 required), `Makefile`, this SUMMARY.
- Commits exist: `2dca268`, `baa91c7`.
- `contract RealizedVolatilityKernelDiffTest` present (1 match).
- key_links present: `mock.volatilityOnRange` (1), `deployPlank("test/market_state_measurements/RealizedVolatilityKernelHarness.plk")` (1).
- `test-vol-kernel-fuzz:` present in Makefile (1).
- Final gate re-run on the restored tree: `make test-vol-kernel-fuzz` exit 0 (1024 runs), `make check-algebra-ref-pin` exit 0, no mutant residue.

---
*Phase: 09-variance-kernel-unit-diff-full-timepoint-diff*
*Completed: 2026-07-16*
