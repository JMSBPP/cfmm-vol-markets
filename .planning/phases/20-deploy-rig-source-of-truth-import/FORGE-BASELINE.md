# PRE-IMPORT BASELINE (Phase 20, plan 20-01 task 3)

Measured cold: 2026-07-31T18:22:10Z
Tree state: HEAD = 826d19ee0b87eeb27bd8efc247bb99040c9e67b3
Import ref (origin/develop) = 9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d
Command: `forge test --via-ir --fuzz-seed 4880`

## forge test

- total: 144
- passed: 139
- failed: 5
- suites: 47

Summary line, verbatim from the log:

    Ran 47 test suites in 11.16s (51.35s CPU time): 139 tests passed, 5 failed, 0 skipped (144 total tests)

### Failing tests (verbatim identifiers, one per line)

    test/modules/VolOrderManager.fuzz.t.sol:VolOrderManagerFuzzTest test__fuzz__logCreateOrder(uint88,uint24,uint16)
    test/types/pos_spec/SpreadTickAssimetryHelper.t.sol:SpreadTickAssimetryTest test__fuzz__spreadTickAssimetrySplitTick__Valid(uint16,uint24,uint24,int24)
    test/types/pos_spec/SpreadTickAssimetryHelper.t.sol:SpreadTickAssimetryTest test__fuzz__tickFromSplittedTickBucket__Valid(uint16,uint24,uint24,int24,uint24,int24)
    test/types/pos_spec/VolRangeWidth.t.sol:VolRangeWidthTest test__fuzz__volWidthRangeBuildVolRangeWidth_valid(uint24,int24,int24)
    test/types/pos_spec/VolRangeWidth.t.sol:VolRangeWidthTest test__fuzz__volWidthRangeSub_valid(uint24,uint24,uint24)

All five fail with `EvmError: Revert` at a fuzz counterexample. Counts were taken from forge's own
summary line and the identifiers from its `Failing tests:` block, never by grepping paths out of
failure text.

## make compile-plank

- ok: 14
- failed: 0
- skipped: 0

Summary line, verbatim from the log:

    compile-plank: 14 ok, 0 failed, 0 skipped

### Failing entrypoints (verbatim)

    (none - zero FAIL lines and zero SKIP lines in the log)

## Attribution note

These are the PRE-import numbers. Plan 20-02 task 3 re-measures with the identical commands
and records the delta. Per research section 7.5 and CLAUDE.md, `test/` belongs to the
Solidity-testing session: new reds caused by the V2 import are REPORTED and ATTRIBUTED,
never repaired.

### Attribution of the five pre-existing reds

Every red here exists BEFORE any Phase 20 import. Nothing has been imported at the time of this
measurement, so none of them is attributable to Phase 20.

- 4 x vol-type track, under `test/types/pos_spec/` - `SpreadTickAssimetryTest` (2) and
  `VolRangeWidthTest` (2). These are exactly the four reds named in `.planning/STATE.md`
  [19-05 MEASURED] and are owned elsewhere (the vol-type TYPE track, not the pos_spec MODULE
  surface).
- 1 x `test/modules/VolOrderManager.fuzz.t.sol` `test__fuzz__logCreateOrder`. This one is NOT in
  the 19-05 record; it is a pre-import red specific to this branch state. Recorded here so that a
  post-import re-measurement cannot mistake it for import damage.
- 0 x under `test/pos_spec/` - the module surface is zero-red in this run.

### Why this differs from the 19-05 sanity reference, and why that is expected

`.planning/STATE.md` [19-05 MEASURED] recorded 102 passed / 18 failed / 120 total (44 suites) and
`make compile-plank` 11 ok / 2 failed. Those numbers are from a DIFFERENT branch state and were
treated as a sanity reference only; they were NOT carried forward. Re-measured cold here:

| Measurement | 19-05 reference | This run (cold, feat/rpc-api) |
|---|---|---|
| forge test total | 120 | 144 |
| forge test passed | 102 | 139 |
| forge test failed | 18 | 5 |
| suites | 44 | 47 |
| compile-plank ok | 11 | 14 |
| compile-plank failed | 2 | 0 |

The dominant cause of the gap is the exposure draft. At 19-05 `src/lib/exposure/VegaIssuanceLib.plk`
was an uncommitted draft that failed to compile (`unresolved identifier 'VolOrder'`), which
propagated through `deployPlank`/FFI and killed 14 suites in `setUp()` and 2 compile-plank
entrypoints. On this branch that file is TRACKED and compiles: `compile-plank` reports 0 failures
and the `VegaAccount*` / `VegaIssuance*` suites pass. That accounts for the 2 recovered entrypoints
and the bulk of the 18-to-5 drop in reds.

The nondeterministic `TickVolatilityLibTest test__fuzz__tickVolatilitySqrtPriceX64x96AndTickSuccess`
red (STATE.md blocker, roughly 1 cold-cache run in 4 at counterexample `2^64-1`) did NOT surface
here: that suite ran 2 passed / 0 failed. The run is pinned with `--fuzz-seed 4880`, so a re-run of
the identical command is expected to reproduce it; a bare `forge test` without the seed is not.

## Preflight state this baseline was taken under

- `npm ci --ignore-scripts` exit 0 (172 packages); `node_modules/@cryptoalgebra` present.
- `git submodule update --init --recursive` exit 0 with the
  `submodule.lib/panoptic-helper.update none` recursion guard set;
  `lib/panoptic-v2-core/lib/v4-core/src/PoolManager.sol` present.
- `forge build` exit 0 (lint notes only, no errors).
- `foundry.toml` and `remappings.txt` byte-untouched; `git status --porcelain` on both is empty.
