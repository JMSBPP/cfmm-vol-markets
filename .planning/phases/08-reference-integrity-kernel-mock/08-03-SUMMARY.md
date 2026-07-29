---
phase: 08-reference-integrity-kernel-mock
plan: 03
subsystem: testing
tags: [forge, solidity, plank, algebra, volatility-oracle, differential-testing]

# Dependency graph
requires:
  - phase: 00-01 (merged, v1.0 track)
    provides: "RealizedVolatilitySmoke.t.sol and its stored-field (getTimepointPacked/OFF_VOL) read pattern"
provides:
  - "IRealizedVolatility with the raw-vs-window-normalized diff surface REMOVED"
  - "In-file documentation of why Plank's raw volatilityCumulative and Algebra's window-normalized getAverageVolatility must never be diffed"
  - "An in-file, verified record of the deferral of the getAverageVolatility port"
affects: [09-variance-diff, 11-mutation-battery, VDIFF-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Delete the surface, do not just document the trap: an unused interface declaration is a one-assertEq-away mistake"
    - "Cite-and-verify: every line/selector reference written into a doc comment was re-verified against the tree before being committed"

key-files:
  created:
    - .planning/phases/08-reference-integrity-kernel-mock/deferred-items.md
  modified:
    - test/market_state_measurements/RealizedVolatilitySmoke.t.sol

key-decisions:
  - "VDIFF-03's 'incorrect assertion' does not exist and never did — the deliverable is removal of the unused declaration that invites it, plus in-file documentation. Re-verified by grep before editing."
  - "Algebra's window-normalized getAverageVolatility was NOT ported to Plank — deferral held, verified by grep (no Bessel in any .plk)."
  - "Plank's shipped get_average_volatility ABI surface was left untouched: production change, out of scope."
  - "Pre-existing unused-variable warning at RealizedVolatilitySmoke.t.sol:183 logged to deferred-items.md, NOT fixed (scope boundary)."

patterns-established:
  - "Behaviour-preserving removals are proven by an UNCHANGED pass count, not by 'it compiles'"

requirements-completed: [VDIFF-03]

# Metrics
duration: 11min
completed: 2026-07-16
---

# Phase 8 Plan 03: VDIFF-03 Scalar-Vol Diff Surface Removal Summary

**The unused `getAverageVolatility` declaration — a one-`assertEq`-away invitation to diff Plank's raw accumulator against Algebra's window-normalized getter — is deleted from `IRealizedVolatility` and replaced by a verified explanation of why those quantities are not comparable; smoke suite unchanged at 11/11.**

## Performance

- **Duration:** ~11 min
- **Started:** 2026-07-16T12:38Z
- **Completed:** 2026-07-16T12:49:22Z
- **Tasks:** 1
- **Files modified:** 1 (plus 1 planning doc created)

## Step-1 Survey (verbatim, run BEFORE any edit)

```
$ grep -rn "getAverageVolatility\|get_average_volatility" --include=*.sol --include=*.plk test/ src/
test/market_state_measurements/RealizedVolatilitySmoke.t.sol:15:    function getAverageVolatility(int24 tick, uint32 blockTimestamp) external view returns (uint88);
src/interfaces/market_state_measurements/RealizedVolatilityInterface.plk:29:// signature:: getAverageVolatility(int24,uint32) -> uint88
src/interfaces/market_state_measurements/RealizedVolatilityInterface.plk:30:// NOTE: this is NOT Algebra's getAverageVolatility (which is window-normalised). It returns the
src/interfaces/market_state_measurements/RealizedVolatilityInterface.plk:32:// MarketStatisticsAlgebraRef.getAverageVolatilityLast -- they are different quantities.
test/MarketStatisticsTest.t.sol:175:    function getAverageVolatilityLast(int24 tick, uint32 blockTimestamp) public view returns(uint88){
test/MarketStatisticsTest.t.sol:179:	 return VolatilityOracle.getAverageVolatility(layout.timepoints, blockTimestamp, tick ,lastIndex, oldestIndex);
test/MarketStatisticsTest.t.sol:440:		uint88 _realizedTickVol = marketStatisticsAlgebraRef.getAverageVolatilityLast(path.ticks[index],uint32(vm.getBlockTimestamp()));
src/modules/market_state_measurements/RealizedVolatilityMod.plk:216:// getAverageVolatility(tick, blockTimestamp) -> uint88.
src/modules/market_state_measurements/RealizedVolatilityMod.plk:219:// timepoint, NOT Algebra's window-normalised getAverageVolatility. Diffing the volatility
src/modules/market_state_measurements/RealizedVolatilityMod.plk:221:const get_average_volatility = fn(tick: u256, block_timestamp: u256) u256 {
src/modules/market_state_measurements/RealizedVolatilityMod.plk:270:	   // getAverageVolatility(int24 tick, uint32 blockTimestamp) -> uint88
src/modules/market_state_measurements/RealizedVolatilityMod.plk:273:	   return_u256(get_average_volatility(tick, block_timestamp));
```

**The survey HELD — reality matched the planner's table exactly.** Two corroborating greps:

```
$ grep -rn "assertEq.*getAverageVolatility\|getAverageVolatility.*assertEq" --include=*.sol test/
(exit 1 — no matches)

$ grep -n "\.getAverageVolatility(" test/market_state_measurements/RealizedVolatilitySmoke.t.sol
(exit 1 — no matches)
```

**Confirmed finding: the "incorrect assertion" named in the ROADMAP/CONTEXT DID NOT EXIST as an assertion.** There is no `assertEq`/`assertApproxEqAbs` anywhere with Plank's raw `getAverageVolatility` on one side and Algebra's window-normalized `getAverageVolatilityLast` on the other. Line 15 was a **declaration that was never called** — a loaded gun, not a live bug. Had this plan been executed as originally worded ("delete the wrong assertion"), it would have completed vacuously against a non-existent target. The planner caught this; the executor re-verified it before editing, per the CONTEXT.md VDIFF-03 CORRECTION block.

## Pass Counts — Before and After (`make test-realized-vol-smoke`)

| | Result |
|---|---|
| **BEFORE edit** | `11 passed; 0 failed; 0 skipped` |
| **AFTER edit** | `11 passed; 0 failed; 0 skipped` |

**UNCHANGED, as required.** Same 11 test names in both runs. The removal is behaviour-preserving because the declaration was never called — exactly what the survey predicted. Had any test failed, that would have meant the surface WAS reachable and the survey was wrong; it did not.

## Accomplishments

- Deleted the unused `getAverageVolatility(int24,uint32)` declaration from `IRealizedVolatility`, removing the surface that makes the wrong diff a one-line reflex.
- Documented the trap in its place: raw accumulator vs Bessel-corrected + WINDOW-normalized, the differing selectors, the correct stored-field check, and the deferral.
- **Verified every citation before writing it into the file** rather than trusting the plan's text — see Decisions.
- Held the deferral: no window-normalization/Bessel port exists in any `.plk`.

## Task Commits

1. **Task 1: Re-verify survey, remove diff-enabling surface, document the trap** — `cd02c1e` (test)

## Files Created/Modified

- `test/market_state_measurements/RealizedVolatilitySmoke.t.sol` — line 15 declaration removed; 20-line doc comment in its place explaining why the two quantities are not comparable, matching the file's existing "a test that cannot fail is worse than no test" voice.
- `.planning/phases/08-reference-integrity-kernel-mock/deferred-items.md` — created; logs one out-of-scope pre-existing warning.

## Decisions Made

- **Verified the doc block's own claims before committing them.** The plan supplied a doc comment asserting `RealizedVolatilityMod.plk:221-224`, `VolatilityOracle.sol:195-242`, selectors `0x8171455c`/`0xc3c8050a`, and "Bessel-corrected AND WINDOW-normalised". Writing unverified claims into a doc is precisely the failure this phase exists to correct (it is how the bogus "incorrect assertion" entered CONTEXT.md). All were independently checked and all held:
  - `cast sig "getAverageVolatility(int24,uint32)"` → `0x8171455c` ✓
  - `cast sig "getAverageVolatilityLast(int24,uint32)"` → `0xc3c8050a` ✓
  - Algebra's `getAverageVolatility` spans lines 195-242 ✓ (function opens at 195, closes at 242)
  - Window-normalization at `VolatilityOracle.sol:233` (`/ WINDOW`) and Bessel's correction at `:238` (`if (unbiasedDenominator > 1) unbiasedDenominator--; // Bessel's correction`) ✓
  - Plank's `get_average_volatility` at `RealizedVolatilityMod.plk:221-224` returns `s.last_timepoint.realizedVolatility.vol & MASK_U88` — the raw accumulator ✓
- Left `src/interfaces/.../RealizedVolatilityInterface.plk:29-32` untouched: its "do not diff" note is already correct, and the plan scopes this to exactly one file.

## Deviations from Plan

None — plan executed exactly as written. No deviation rules fired; no auto-fixes were needed.

One out-of-scope discovery was **logged, not fixed** (scope boundary):

- **[Out of scope — logged] Pre-existing solc warning `Unused local variable` at `RealizedVolatilitySmoke.t.sol:183`.** In `test__unit__timestampBelowWindowDoesNotInvertComparator`, which this plan never touched. It surfaced only because the edit forced a recompile the baseline run had skipped (`No files changed, compilation skipped`) — not a regression. Recorded in `deferred-items.md` and flagged for Phase 11, where a dropped assertion is the exact failure mode under audit.

**Total deviations:** 0 auto-fixed. 1 out-of-scope item logged.
**Impact on plan:** None. Exactly one file changed, exactly as scoped.

## Verification Results

| Criterion | Result |
|---|---|
| `grep -c "function getAverageVolatility"` in the test file | `0` ✓ |
| `grep -q "DELIBERATELY NOT DECLARED HERE (VDIFF-03)"` | PASS ✓ |
| `grep -q "DIFFERENT QUANTITIES"` | PASS ✓ |
| `grep -q "Bessel"` | PASS ✓ |
| artifact `contains: "window-normalised"` | PASS ✓ |
| `make test-realized-vol-smoke` exit 0, pass count unchanged | PASS ✓ (11 → 11) |
| no raw-vs-normalized `assertEq` anywhere in `test/` | PASS ✓ (none) |
| `RealizedVolatilityMod.plk`, `RealizedVolatilityInterface.plk`, `MarketStatisticsTest.t.sol` UNCHANGED | PASS ✓ (`git diff --name-only -- src/ test/` lists only the one target file) |
| no Bessel/window-normalization port in any `.plk` | PASS ✓ (none) |

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- VDIFF-03 is closed. The wrong scalar-vol diff can no longer be written by reflex against the test's Plank interface.
- **Phase 9 / VDIFF-04 inherits the correct pattern:** scalar volatility is checked via the stored `volatilityCumulative` field (`getTimepointPacked`, `OFF_VOL = 32`), as demonstrated by `test__unit__negativeAvgTickVolatilityIsExact` (exact value 9505555). The in-file doc now points there explicitly.
- The `getAverageVolatility` port remains deferred out of this milestone and is redundant with VDIFF-04's field-by-field diff.
- **Note for the phase gate:** 08-01 and 08-02 (the Algebra reference pin and the `_volatilityOnRange` mock) were still in flight in this worktree during 08-03 — the `Makefile` shows an uncommitted `check-algebra-ref-pin` target from that parallel work. 08-03 touched neither and staged only its own file.

## Self-Check: PASSED

- `test/market_state_measurements/RealizedVolatilitySmoke.t.sol` — FOUND
- `.planning/phases/08-reference-integrity-kernel-mock/deferred-items.md` — FOUND
- Commit `cd02c1e` — FOUND in `git log`

---
*Phase: 08-reference-integrity-kernel-mock*
*Completed: 2026-07-16*
