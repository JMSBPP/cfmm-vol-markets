---
phase: 13-issuance-library-vegaissuancelib
plan: 01
subsystem: testing
tags: [plank, solidity, foundry, ffi, full_math, solady, fixed-point, differential-testing, q64.96]

# Dependency graph
requires:
  - phase: 12-spec-correction-type-completion
    provides: "risk.md H1 spec (p_risk=oracle/(1-h), integer realization, inexact anchor); RiskPriceX96/Haircut newtypes in src/types/exposure/VegaExposure.plk"
provides:
  - "src/lib/exposure/VegaIssuanceLib.plk — pure haircut_risk_price + issue_shares composing v3::math::full_math::{mulDiv, mulDivRoundingUp}"
  - "test/exposure/VegaIssuanceKernelHarness.plk — FFI ABI harness over the pure lib (cast-verified selectors 0x00213e88 / 0x636ae14a)"
  - "test/mocks/IssuanceRefMock.sol — solady fullMulDiv(Up) reference exposing haircutRiskPrice/issueShares/composed/direct"
  - "test/exposure/VegaIssuance.diff.t.sol — the single differential suite (probe + reverts + monotonicity); 13-02 EXTENDS it"
affects: [Phase 14 VegaAccountMod module, Phase 15 end-to-end differential, 13-02 fuzz battery + mutation gate]

# Tech tracking
tech-stack:
  added: [solady FixedPointMathLib fullMulDiv/fullMulDivUp as the Solidity reference primitive]
  patterns: [FFI kernel harness over a pure lib, whole-word calldata + shr-224 selector dispatch, inexact-division anchor probe with external hand-derived pin, constructed reverting corpora via vm.expectRevert]

key-files:
  created:
    - src/lib/exposure/VegaIssuanceLib.plk
    - test/exposure/VegaIssuanceKernelHarness.plk
    - test/mocks/IssuanceRefMock.sol
    - test/exposure/VegaIssuance.diff.t.sol
  modified: []

key-decisions:
  - "solady fullMulDivUp confirmed IDENTICAL round-up primitive to full_math.plk mulDivRoundingUp (floor then +1 iff mulmod!=0, revert on d==0, revert on 2^256 overflow) — mock needs no adaptation"
  - "Both harness selectors RECOMPUTED with cast sig and matched the plan (0x00213e88, 0x636ae14a) — no hand-derivation"
  - "Untracked parallel-track file src/modules/protocol_integrations/PriceSetterHook.sol has an empty import that breaks the whole forge build tree; routed around with --skip (no file modified), logged to deferred-items"

patterns-established:
  - "Inexact-both-hops anchor (deposit=10, oracle=10*2^92, h=3*2^92 -> pRisk=60944740395587951995033807951, composed shares=12) pins both rounding sites at once; external pin defeats an echoing mock"
  - "p_risk>=oracle monotonicity fuzz bounded so mulDivRoundingUp never overflow-reverts (oracle in [1,2^96], h in [0,2^96) -> pRisk<2^192)"

requirements-completed: [VLIB-01, VLIB-02]

# Metrics
duration: 5min
completed: 2026-07-17
---

# Phase 13 Plan 01: Issuance Library (VegaIssuanceLib) Summary

**Pure `haircut_risk_price` (ceil) + `issue_shares` (floor) composing `v3::math::full_math`, proven CALLED-green through FFI-deployed bytecode: exact at the inexact-both-hops anchor (pRisk=60944740395587951995033807951, shares=12), tolerance-0 vs a solady `fullMulDiv` mock, five constructed reverts, and a 512-run `p_risk >= oracle` fuzz.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-07-17T22:23:19Z
- **Completed:** 2026-07-17T22:27:54Z
- **Tasks:** 3
- **Files modified:** 4 created (+ deferred-items.md)

## Accomplishments
- `VegaIssuanceLib.plk`: two pure functions typed by `RiskPriceX96`/`Haircut`, composing `mulDivRoundingUp`/`mulDiv` — never reimplementing 512-bit math, checked ASCII `-` subtraction, explicit `oracle==0` and `hX96>=2^96` guards.
- FFI harness making the otherwise-unreachable lib callable over the ABI; both selectors recomputed with `cast sig` and matched the plan.
- `IssuanceRefMock.sol` over solady `fullMulDivUp`/`fullMulDiv` — confirmed the identical ceil-then-floor primitive to `full_math` before asserting "identical algorithm".
- `VegaIssuance.diff.t.sol`: 7/7 CALLED-green — anchor probe (3 assertions + non-degeneracy), 5 reverts under `vm.expectRevert`, monotonicity fuzz at `runs: 512` with zero `vm.assume`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Pure VegaIssuanceLib.plk** - `db4edc4` (feat)
2. **Task 2: FFI harness + solady mock** - `12bb9d7` (test)
3. **Task 3: CALLED differential (probe + reverts + fuzz)** - `cdb1a67` (test)

**Plan metadata:** (this commit) (docs: complete plan)

## Files Created/Modified
- `src/lib/exposure/VegaIssuanceLib.plk` - Pure `haircut_risk_price` + `issue_shares` composing `v3::math::full_math`.
- `test/exposure/VegaIssuanceKernelHarness.plk` - FFI ABI harness, whole-word calldata dispatch into the typed lib.
- `test/mocks/IssuanceRefMock.sol` - solady reference: `haircutRiskPrice`/`issueShares`/`composed`/`direct`.
- `test/exposure/VegaIssuance.diff.t.sol` - The differential suite (3 contracts, 7 tests); 13-02 extends it.
- `.planning/phases/13-issuance-library-vegaissuancelib/deferred-items.md` - Out-of-scope untracked-file breakage log.

## Decisions Made
- **solady `fullMulDivUp` == `full_math` `mulDivRoundingUp`.** Read both before claiming "identical algorithm": both compute floor then add 1 iff `mulmod(x,y,d) != 0`, revert on `d==0` (via the floor call), and revert if `+1` would overflow to 2^256. No mock adaptation needed; recorded in the mock's `@dev`.
- **Selectors recomputed, not transcribed.** `cast sig "haircutRiskPrice(uint256,uint256)"` -> `0x00213e88` and `cast sig "issueShares(uint256,uint256)"` -> `0x636ae14a`, both matching the plan. (The v2.0 selector-doc error was the cautionary tale.)
- **Anchor values are authoritative, implementation is not.** The machine-verified anchor (pRisk=60944740395587951995033807951, composed=12) was used as the expected value; the implementation matched it on the first run, so no debugging was needed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking, OUT OF SCOPE — routed around, not fixed] Untracked parallel-track file breaks the forge build tree**
- **Found during:** Task 3 (running `VegaIssuance.diff.t.sol`).
- **Issue:** `src/modules/protocol_integrations/PriceSetterHook.sol` (UNTRACKED, created 2026-07-17T12:14 by another track) contains `import {PoolKey} from "";` — an empty import path that fails `forge build` for the entire `src/` tree, blocking all suites.
- **Fix:** NOT fixed — it is another track's untracked work-in-progress, outside this task's scope (SCOPE BOUNDARY). Ran the suite with `--skip 'src/modules/protocol_integrations/PriceSetterHook.sol'` (compilation-only route-around; no file modified). Since the file is untracked it does not affect the committed 13-01 deliverables or CI.
- **Files modified:** none (logged to `deferred-items.md`).
- **Verification:** `forge test --match-path 'test/exposure/VegaIssuance.diff.t.sol' --skip '...' --via-ir --optimize` -> 7 passed, 0 failed.
- **Committed in:** `cdb1a67` (deferred-items.md; the .plk/.sol files are unaffected).

---

**Total deviations:** 1 (out-of-scope blocker routed around, not fixed).
**Impact on plan:** None on the deliverables — all four artifacts are exactly as planned and the suite is CALLED-green. The blocker is environmental debris owned by another track.

## Issues Encountered
- The forge build breakage above. Resolved by `--skip` (no source touched). Once the owning track fixes/removes `PriceSetterHook.sol`, plain `forge test` / `make test` pick up `VegaIssuance.diff.t.sol` normally.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- The pure lib + harness + mock + single diff file are the substrate 13-02 EXTENDS (backing invariant `shares*pRisk<=deposit*2^96` in 512-bit both sides, weight-one identity, `composed<=direct` one-sided, and the observed-RED mutation gate for VLIB-03/VLIB-04). Do NOT fork a second test file.
- VLIB-01 and VLIB-02 are discharged CALLED-green. The `RiskPriceX96`/`Haircut` newtypes from Phase 12 are now proven by being imported and exercised.
- Watch item for 13-02: the untracked `PriceSetterHook.sol` breakage will require the same `--skip` (or the owning track's fix) to run any forge target.

---
*Phase: 13-issuance-library-vegaissuancelib*
*Completed: 2026-07-17*

## Self-Check: PASSED

All 4 deliverable artifacts + deferred-items + SUMMARY exist on disk; all 3 task commits (db4edc4, 12bb9d7, cdb1a67) exist in git. Suite is CALLED-green (7 passed, 0 failed; fuzz runs: 512; no vm.assume).
