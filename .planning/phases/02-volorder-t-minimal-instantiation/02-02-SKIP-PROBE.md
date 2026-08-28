# --skip probe — one-time measurement of the two masked suites (plan 02-02)

- **Probe commit:** `f815e25260ad1ddc1a0e47a9527c4bf1ace86807` (REVERTED by `7e32678a4daa61da3080cec0181f1170cfae2931`;
  never reaches develop unless re-applied by maintainer decision at the 02-03 checkpoint)
- **Runs:** develop-gate `33169585831` (https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33169585831, forge job FAILED as expected),
  push-build `33169580954` (failure — corroborates); revert confirmed by develop-gate `33169960869`: success, `Ran 75 test suites in 6.31s (26.78s CPU time): 273 tests passed, 0 failed, 3 skipped (276 total tests)` — back to the 02-01 counts exactly
- **Toolchain:** plank `00c0a1aa3cb40b63de81c6ca4f92bec392b423c3`, forge `1.5.1` / `b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`, `--fuzz-seed 4880` (quoted from the log)
- **Globs removed and what each masks (filename match, `git ls-files`):**
  - `*VolRangeWidth*` → `src/types/pos_spec/VolRangeWidth.plk`, `test/types/pos_spec/VolRangeWidth.t.sol`, `test/types/pos_spec/VolRangeWidthHelper.plk`
    (the `.plk` files are compiled by plank, not forge, so the mask is inert for them — but the glob DOES name the source of a `VolOrder` field type)
  - `*SpreadTickAssimetryHelper*` → `test/types/pos_spec/SpreadTickAssimetryHelper.plk`, `test/types/pos_spec/SpreadTickAssimetryHelper.t.sol`

## Measured (quoted)
### test/types/pos_spec/VolRangeWidth.t.sol
```
Ran 18 tests for test/types/pos_spec/VolRangeWidth.t.sol:VolRangeWidthTest
[PASS] ×16  (all bounds / add / eq / geq / leq / neq / packUnpack / sub_spacingMismatch / buildVolRangeWidth_invalid* fuzz cases)
[FAIL: EvmError: Revert; counterexample: … args=[23, 0, 0]] test__fuzz__volWidthRangeBuildVolRangeWidth_valid(uint24,int24,int24) (runs: 0, μ: 0, ~: 0)
[FAIL: EvmError: Revert; counterexample: … args=[3445, 1, 0]] test__fuzz__volWidthRangeSub_valid(uint24,uint24,uint24) (runs: 39, μ: 8307, ~: 8361)
Suite result: FAILED. 16 passed; 2 failed; 0 skipped; finished in 772.74ms (2.15s CPU time)
```
### test/types/pos_spec/SpreadTickAssimetryHelper.t.sol
```
Ran 3 tests for test/types/pos_spec/SpreadTickAssimetryHelper.t.sol:SpreadTickAssimetryTest
[PASS] test__fuzz__spreadTickAssimetrySplitTick__InvalidTickSpacing(uint16,uint24,uint24,int24) (runs: 256, μ: 10268, ~: 10267)
[FAIL: EvmError: Revert; counterexample: … args=[7, 0, 1236664 [1.236e6], -31292 [-3.129e4]]] test__fuzz__spreadTickAssimetrySplitTick__Valid(uint16,uint24,uint24,int24) (runs: 0, μ: 0, ~: 0)
[FAIL: EvmError: Revert; counterexample: … args=[40, 10037 [1.003e4], 5646, 10186 [1.018e4], 4846, 1055073 [1.055e6]]] test__fuzz__tickFromSplittedTickBucket__Valid(uint16,uint24,uint24,int24,uint24,int24) (runs: 0, μ: 0, ~: 0)
Suite result: FAILED. 1 passed; 2 failed; 0 skipped; finished in 73.11ms (60.80ms CPU time)
```
### Whole-suite line
`Ran 77 test suites in 6.90s (46.40s CPU time): 290 tests passed, 4 failed, 3 skipped (297 total tests)` (probe)
vs `Ran 75 test suites … 273 tests passed, 0 failed, 3 skipped (276 total tests)` (02-01 GATE_POST2)
— delta = +2 suites, +17 passed (16+1), +4 failed (2+2), skipped unchanged. **Attributable ONLY to the two suites: yes.**

## Classification input for the regression assessment (02-03)
- VolRangeWidth.t.sol: RED (2 failing: `test__fuzz__volWidthRangeBuildVolRangeWidth_valid`, `test__fuzz__volWidthRangeSub_valid`) on this toolchain+seed
- SpreadTickAssimetryHelper.t.sol: RED (2 failing: `test__fuzz__spreadTickAssimetrySplitTick__Valid`, `test__fuzz__tickFromSplittedTickBucket__Valid`)
- Any red → both stay masked; classified UNVERIFIED-with-reason in the assessment; the new issue owns them.
  Note for 02-03: 16 of 18 and 1 of 3 tests in these files DID pass on the bumped toolchain — the
  assessment may cite those named passes as partial evidence, but the FILES remain UNVERIFIED because
  they cannot run in the gate.

## Anomalies
- Three of the four failures report `runs: 0` and a counterexample whose fuzz inputs include a literal
  `0` in a tick-spacing / width position (`args=[23, 0, 0]`, `args=[7, 0, …]`). That is a failure on
  the very first fuzz input, consistent with the `_valid` tests not bounding their inputs away from a
  zero tick spacing the library legitimately rejects — i.e. a TEST-DESIGN hole rather than a library
  bug. The fourth (`volWidthRangeSub_valid`, `runs: 39`, `args=[3445, 1, 0]`) also carries a `0`.
  Recorded as an observation for the owning issue, NOT a conclusion — nobody has read the tests' bounds.
- The ledger comment's "failure count is fuzz-SEED-dependent (2/3/6 measured)" is CONSISTENT with this
  run: 4 failures at seed 4880 on the current pins (2 + 2), a count not previously listed.
- `git revert -q` is not a valid flag; the first revert attempt did nothing and pushed nothing
  ("Everything up-to-date"). Caught by the 0-byte diff check reading 570 instead of 0; re-run without `-q`.

## Tracked by
- #63 — https://github.com/JMSBPP/cfmm-vol-markets/issues/63 (scoped to exactly these two ledger entries; #16 untouched, still CLOSED)
