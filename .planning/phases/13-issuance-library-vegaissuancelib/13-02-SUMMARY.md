---
phase: 13-issuance-library-vegaissuancelib
plan: 02
subsystem: testing
tags: [plank, solidity, foundry, ffi, full_math, solady, fixed-point, differential-testing, fuzz, mutation-testing, q64.96, 512-bit]

# Dependency graph
requires:
  - phase: 13-issuance-library-vegaissuancelib
    plan: 01
    provides: "VegaIssuanceLib.plk (haircut_risk_price ceil + issue_shares floor), VegaIssuanceKernelHarness.plk (FFI), IssuanceRefMock.sol (solady composed/direct), VegaIssuance.diff.t.sol (probe + reverts + monotonicity) — the file this plan EXTENDS"
provides:
  - "test/exposure/VegaIssuance.diff.t.sol — extended with the Lean-lemma fuzz battery: 512-bit backing invariant, weight-one identity, composed==mock tolerance-0, one-sided composed<=direct (11 tests, 7 contracts, all CALLED-green)"
  - "make test-vega-issuance — focused target running the differential + fuzz suite"
  - "Observed-RED mutation gate discharging VLIB-03/04: 3 killable rounding/ordering mutants died at the cache-independent inexact anchor, restored byte-identical; the h-bound relaxation documented equivalence-checked"
affects: [Phase 14 VegaAccountMod module, Phase 15 end-to-end differential + make-test fold-in]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "512-bit product via mulmod identity (_mul512) + lexicographic (hi,lo) compare (_le512) — proves shares*pRisk <= deposit*2^96 with NO raw `*` on either side, over a corpus where both products exceed 2^256"
    - "Cache-independent unit anchor as the PRIMARY mutant kill site (non-fuzz, cannot be a cached replay even in principle); fuzzes as corroborating evidence"
    - "Byte-identical restore of the mutated .plk verified by sha256 after every mutant (git checkout restore + hash assert)"

key-files:
  created:
    - .planning/phases/13-issuance-library-vegaissuancelib/13-02-SUMMARY.md
  modified:
    - test/exposure/VegaIssuance.diff.t.sol
    - Makefile

key-decisions:
  - "Backing-invariant non-vacuity is asserted on the RIGHT side (assertGt(hiR,0), deposit*2^96) NOT the left (shares*pRisk): shares*pRisk can legitimately fall below 2^256 under floor division when pRisk is large, so the plan's assertGt(hiL,0) would fail on valid inputs — hiR>0 is provably guaranteed by deposit>=2^160 and correctly proves the corpus reaches the >2^256 regime"
  - "Oracle upper bound narrowed 2^160 -> 2^160-1 in all three new fuzzes: the joint corner oracleX96==2^160 & denom==1 (hX96==2^96-1) makes haircut_risk_price compute 2^160*2^96 = 2^256 and mulDivRoundingUp OVERFLOW-reverts (empirically confirmed) — the inclusive bound was a latent fuzz-seed flake"
  - "make test-vega-issuance carries --skip 'src/modules/protocol_integrations/PriceSetterHook.sol' (untracked parallel-track file with empty imports breaks forge build); skipping an unrelated file is a no-op once the owning track fixes it — the make-test fold-in is Phase 15's"

requirements-completed: [VLIB-03, VLIB-04]

# Metrics
duration: 8min
completed: 2026-07-17
---

# Phase 13 Plan 02: Issuance Library Fuzz Battery + Mutation Gate Summary

**The Lean-lemma fuzz battery extends the single differential file to 11 CALLED-green tests — the VLIB-03 backing invariant `shares*pRisk <= deposit*2^96` proven in genuine 512-bit arithmetic (mulmod identity, never a raw `*`) over a corpus where `deposit*2^96` truly crosses 2^256, the weight-one identity, the VLIB-04 tolerance-0 composed-vs-mock differential, and the one-sided `composed <= direct` — and every killable rounding/ordering mutant was OBSERVED red at the cache-independent inexact anchor (12→13, 13→12, 7→12) then restored byte-identical, with the h-bound relaxation documented equivalence-checked, not counted as a kill.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-07-17T22:33:52Z
- **Completed:** 2026-07-17T22:42:40Z
- **Tasks:** 2
- **Files modified:** 2 (test file extended, Makefile)

## Accomplishments

- Extended `test/exposure/VegaIssuance.diff.t.sol` (13-01's file — NOT forked) with four new `PlankTestBase` contracts reusing the deployed FFI harness and solady mock:
  - `VegaIssuanceBackingTest` — VLIB-03 backing invariant in genuine 512-bit both sides (`_mul512` via mulmod, `_le512` lexicographic compare), `deposit ∈ [2^160, 2^256)` so `deposit*2^96` genuinely exceeds 2^256 (`assertGt(hiR, 0)`), runs: 512.
  - `VegaIssuanceWeightOneTest` — VLIB-03 weight-one identity `issue_shares(deposit, 2^96) == deposit`, exact, runs: 512.
  - `VegaIssuanceDiffTest` — VLIB-04 tolerance-0 `composed == mock.composed` (identical algorithm only), runs: 1024.
  - `VegaIssuanceOneSidedTest` — VLIB-04 one-sided `composed <= mock.direct` (the ONLY site the direct path appears; exact equality is FALSE in integers), runs: 1024.
- All 11 tests CALLED-green over two independent fuzz seeds (1, 999); zero `vm.assume`; corpora constructed via `bound()`.
- Ran the observed-RED mutation gate: 3 killable mutants each died at the cache-independent unit anchor and were restored byte-identical (sha256-verified); the h-bound `>=`→`>` relaxation confirmed equivalent (suite stays green).
- Added `make test-vega-issuance` (focused target; `make test` default untouched).

## Task Commits

1. **Task 1: Fuzz battery (512-bit backing, weight-one, composed==mock, composed<=direct)** — `f875fce` (test)
2. **Task 2: Focused make target (mutation gate is observation-only, lib restored byte-identical)** — `4160676` (chore)

**Plan metadata:** (this commit) (docs: complete plan)

## Mutation Gate — Verbatim Observed-RED Lines

Runner per mutant: `git checkout` clean → apply one-line edit to `src/lib/exposure/VegaIssuanceLib.plk` → `rm -rf cache/fuzz && forge test --match-path 'test/exposure/VegaIssuance.diff.t.sol' --skip 'src/modules/protocol_integrations/PriceSetterHook.sol' --via-ir --optimize` → record FAIL → `git checkout` restore → sha256 == `2ee071627e25f4fe07b6e78cb5e163435cdfb737b4dcf293939c5a8ae7bfc7e3` → suite green. The primary kill site is the NON-fuzz unit anchor `test__unit__anchorComposedEqualsMockAndHandDerived` (cache-independent by construction — cannot be a cached replay).

**Mutant 1 — p_risk ceil→floor** (`mulDivRoundingUp(oracleX96, TWO_96, denom)` → `mulDiv(...)`):
```
[FAIL: p_risk ceil at inexact anchor: 60944740395587951995033807950 != 60944740395587951995033807951] test__unit__anchorComposedEqualsMockAndHandDerived() (gas: 9214)
```
Anchor pRisk drops by one (…951 → …950). The `composedEqualsMock` and `composedLeDirect` fuzzes also reddened (floor p_risk lets composed exceed direct). Restored → 11 passed, exit 0.

**Mutant 2 — shares floor→ceil** (`mulDiv(deposit, TWO_96, pRiskX96.val)` → `mulDivRoundingUp(...)`):
```
[FAIL: shares floor at inexact anchor: 13 != 12] test__unit__anchorComposedEqualsMockAndHandDerived() (gas: 10656)
```
Anchor shares flip 12 → 13. Restored → 11 passed, exit 0.

**Mutant 3 — mulDiv numerator/denominator swap** (`mulDiv(deposit, TWO_96, pRiskX96.val)` → `mulDiv(deposit, pRiskX96.val, TWO_96)`):
```
[FAIL: shares floor at inexact anchor: 7 != 12] test__unit__anchorComposedEqualsMockAndHandDerived() (gas: 10478)
```
Anchor shares become `10·pRisk / 2^96 = 7`. (mulDiv's first two args are symmetric `a*b`, so ONLY a numerator↔denominator swap is observable — this is that swap.) Restored → 11 passed, exit 0.

**DOCUMENTED-EQUIVALENT (NOT a kill) — h-bound `>=`→`>` relaxation** (`if hX96.val >= TWO_96` → `if hX96.val > TWO_96`):
```
[PASS] test__unit__hEqualsOneReverts() (gas: 8976)
Ran 7 test suites: 11 tests passed, 0 failed, 0 skipped (11 total tests)  — EXIT 0
```
Suite stays GREEN both ways. At `hX96 == 2^96` the mutant skips the explicit guard but `mulDivRoundingUp(oracle, 2^96, 0)` hits full_math's zero-denominator revert (`full_math.plk:13–24`); at `hX96 > 2^96` the checked subtraction reverts. Equivalence-checked defense-in-depth — masked by full_math's zero-denominator revert; NOT counted as a kill (risk.md §3). Restored.

## Files Created/Modified

- `test/exposure/VegaIssuance.diff.t.sol` — extended from 3→7 contracts (7→11 tests) with the fuzz battery; header note distinguishes tolerance-0 (vs `mock.composed`) from the one-sided bound (vs `mock.direct`) to keep review BLOCKER B1 fixed.
- `Makefile` — added `test-vega-issuance` focused target + `.PHONY` entry; default `test:` target untouched.

## Decisions Made

- **Backing non-vacuity checked on the RHS, not the LHS.** The plan snippet asserted `assertGt(hiL, 0)` on `shares*pRisk`. Verified analytically that `shares*pRisk` can legitimately fall below 2^256 under floor division when `pRisk` is large (e.g. `deposit=2^160`, `pRisk≈2^200`: `shares*pRisk ≈ 2^256 − 2^200 < 2^256`, `hiL=0`) — so `assertGt(hiL, 0)` would FAIL on valid inputs, a false failure. `assertGt(hiR, 0)` on `deposit*2^96` is provably guaranteed by `deposit >= 2^160` and correctly proves the corpus reaches the >2^256 regime the 512-bit path exists for.
- **Oracle upper bound `2^160-1`, not `2^160`.** Empirically confirmed (temporary corner probe): `haircutRiskPrice(2^160, 2^96−1)` reverts (`2^160·2^96 = 2^256` overflows `mulDivRoundingUp`) while `haircutRiskPrice(2^160−1, 2^96−1)` passes. The inclusive bound was a latent fuzz-seed flake that only survived by luck; `deposit >= 2^160` still keeps `deposit*2^96 >= 2^256`.
- **FFI recompiles the .plk at test time — no `make compile-plank` between mutants.** Consistent with the thrice-proven repo fact: `deployPlank` shells out to `plank build` over FFI, so a `.plk` edit is live on the next run. Every mutant reddened from a bare source edit with the fuzz cache cleared; no `runs: 0` replay was accepted as proof (the unit anchor is cache-independent regardless).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Backing-invariant non-vacuity assertion targeted a side that can be legitimately < 2^256**
- **Found during:** Task 1.
- **Issue:** The plan's `assertGt(hiL, 0)` (on `shares*pRisk`) fails on valid floor-division outputs where `pRisk` is large and `shares*pRisk < 2^256` (`hiL = 0`) — a spurious failure, not a real invariant violation.
- **Fix:** Assert `assertGt(hiR, 0)` on `deposit*2^96`, which is provably `>= 2^256` for `deposit >= 2^160` and is the reference magnitude that makes the 512-bit comparison necessary. Same intent (corpus genuinely exceeds 2^256), correct and deterministic.
- **Files modified:** `test/exposure/VegaIssuance.diff.t.sol`.
- **Commit:** `f875fce`.

**2. [Rule 1 — Bug] Inclusive oracle upper bound `2^160` overflow-reverts at one joint corner**
- **Found during:** Task 1.
- **Issue:** `bound(oRaw, ·, 2^160)` admits `oracleX96 == 2^160`; combined with `denom == 1` (`hX96 == 2^96−1`), `haircut_risk_price` computes `2^160·2^96 = 2^256` and `mulDivRoundingUp` overflow-reverts, failing the fuzz. Confirmed empirically with a temporary corner probe. Passed initially only by fuzz-seed luck.
- **Fix:** Narrowed the upper bound to `2^160 − 1` in all three new fuzzes (backing, diff, one-sided). `deposit >= 2^160` unchanged, so the 512-bit path stays genuine. Re-ran under seeds 1 and 999 — green.
- **Files modified:** `test/exposure/VegaIssuance.diff.t.sol`.
- **Commit:** `f875fce`.

**3. [Rule 3 — Blocking, OUT OF SCOPE — routed around] Untracked PriceSetterHook.sol breaks forge build**
- **Found during:** Task 2 (Makefile target).
- **Issue:** `src/modules/protocol_integrations/PriceSetterHook.sol` (untracked, another track) has empty-path imports that fail `forge build` for the whole `src/` tree.
- **Fix:** `make test-vega-issuance` carries `--skip 'src/modules/protocol_integrations/PriceSetterHook.sol'` (unchanged file). Skipping an unrelated file is a no-op once the owning track fixes/removes it. Carries 13-01's established route-around; logged in the phase `deferred-items.md`.
- **Files modified:** `Makefile` (target only; no source touched).
- **Commit:** `4160676`.

---

**Total deviations:** 3 (2 corpus-correctness bug fixes in the plan's fuzz bounds/assertion; 1 out-of-scope blocker routed around). All within Task scope; none architectural.
**Impact on plan:** Deliverables exactly as intended — VLIB-03/04 discharged CALLED-green with an observed-RED mutation gate. The two bug fixes make the fuzzes deterministically green rather than seed-dependent.

## Issues Encountered

- The two latent corpus bugs above (fixed). The `PriceSetterHook.sol` build breakage persists (owned by another track); every forge invocation here used `--skip`.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- VLIB-01..04 are all discharged CALLED-green with a mutation gate. Phase 14 (VegaAccountMod module, storage, dispatch) builds on the proven pure lib; Phase 15 folds `test-vega-issuance` into `make test` and adds the end-to-end differential + PLANK_SKIP exit.
- Watch item unchanged: the untracked `PriceSetterHook.sol` still breaks plain `forge test`/`make test` — needs the owning track's fix or `--skip` until then.

---
*Phase: 13-issuance-library-vegaissuancelib*
*Completed: 2026-07-17*
</content>
</invoke>

## Self-Check: PASSED

Both modified files + SUMMARY exist on disk; both task commits (f875fce, 4160676) exist in git. Suite CALLED-green (11 passed; fuzzes runs 512/512/1024/1024; no vm.assume). All 3 killable mutants OBSERVED red at the cache-independent anchor and restored byte-identical (lib sha256 == 2ee0716…, `git diff` empty); h-bound relaxation confirmed equivalent. `make test-vega-issuance` present; default `make test` untouched.
