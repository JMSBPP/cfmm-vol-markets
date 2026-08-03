# POST-IMPORT DELTA (Phase 20, plan 20-02 task 3)

Measured: 2026-07-31T18:34:33Z
Import ref: 9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d
HEAD at measurement: d70e167
Command: `forge test --via-ir --fuzz-seed 4880` (identical to the baseline, seed included)
Baseline source: `FORGE-BASELINE.md` (cold, taken pre-import at 20-01 task 3)

| metric | pre-import | post-import | delta |
|---|---|---|---|
| forge total | 144 | 112 | -32 |
| forge passed | 139 | 85 | -54 |
| forge failed | 5 | 27 | +22 |
| forge suites | 47 | 47 | 0 |
| compile-plank ok | 14 | 13 | -1 |
| compile-plank failed | 0 | 3 | +3 |
| compile-plank entrypoints | 14 | 16 | +2 |
| `forge build` | exit 0 | **exit 0** | unchanged |

**Why `forge total` FELL by 32 rather than staying fixed.** Six suites now fail in `setUp()`,
and forge reports a setUp failure as ONE failing test while the suite's remaining tests never
run and are never counted. The 32 "missing" tests were not deleted — they are unreachable behind
a reverting `setUp()`. Comparing raw pass counts alone would overstate the damage; comparing
failure IDENTITIES (below) is the honest measure.

**`forge build` still exits 0.** This CONFIRMS research 7.5's mechanism: `.plk` files are never
seen by solc, so importing the V2 Plank closure cannot break Solidity compilation. Every one of
the 27 reds is a RUNTIME or FFI failure, never a build failure. `forge script` (what the deploy
rig actually runs in 20-03) is therefore unaffected.

## Attributed causes

| id | cause |
|---|---|
| **C1** | **V2 `create_order` arity change.** V2 is `create_order(uint88,uint24,uint16,uint96)` (strike, width, skew, **targetVega**), selector `0x98d950ec`. The v1 3-arg `create_order(uint88,uint24,uint16)` / `0x6501fe94` is RETIRED-NEVER-LIVE. `test/pos_spec/*` and `test/modules/*` still call and pin the v1 ABI, so calls revert or return different bytes AT RUNTIME. This is research 7.5, exactly as predicted. |
| **C2** | **Harness `.plk` imports the superseded `lib::TickUtils`.** `src/lib/TickUtils.plk` was removed by this plan (it lives at `src/types/pricing/TickUtils.plk` on the ref). Two test harnesses still `import lib::TickUtils::*` — `test/types/pos_spec/VolOrderHelper.plk:6` and `test/types/pos_spec/SpreadTickAssimetryHelper.plk:3`. Error: `could not open imported file … 'src/lib/TickUtils.plk': No such file or directory`. |
| **C3** | **Per-test `--dep` set lacks `types=src/types`.** The imported `src/types/pos_spec/{VolRangeWidth,SpreadTickAssimetry}.plk` now `import types::pricing::TickUtils::…`. Some suites build their harness with a NARROWER dependency set (`v3,std,pos_spec,lib` only) than `PlankTestBase`, giving `unresolved import … unknown module 'types'`. **PROVEN one-flag fix:** re-running the identical build with `--dep types=src/types` added emits bytecode and exits 0 (measured, no file edited). |
| **C4** | **Harness calls V2 lib functions with v1 arity.** `test/types/pos_spec/VolOrderValidationHarness.plk` fails with `wrong number of arguments` against the imported V2 `VolOrderValidationLib.plk`. |
| **P** | **PRE-EXISTING** — red in `FORGE-BASELINE.md` before the import. |

## New failures, one per line, each ATTRIBUTED

| test identifier | attributed cause |
|---|---|
| `VolOrderManagerFuzzTest::test__fuzz__logCreateOrder` | **P** — pre-import red, named in FORGE-BASELINE.md. 20-01 recorded it precisely so it would not be mistaken for import damage. Now also over-determined by C1. |
| `VolOrderManagerSequenceDiffTest::test__fuzz__randomSequenceDiffers` | C1 |
| `VolOrderManagerSequenceDiffTest::test__unit__fixedAnchorSequenceDiffers` | C1 |
| `VolOrderManagerGuardTest::test__unit__invalidSkewAfterAValidOrderDoesNotDisturbIt` | C1 |
| `VolOrderManagerReaderTest::test__unit__getOrderPackedNonexistentReturnsZeroWithoutReverting` | C1 |
| `VolOrderManagerReaderTest::test__unit__readersReturnStoredValues` | C1 |
| `VolOrderManagerStoreTest::test__fuzz__validTupleStoresExactPackedWord` | C1 |
| `VolOrderManagerStoreTest::test__unit__idAt65536IsNotMaskedIntoSlotZero` | C1 |
| `VolOrderManagerStoreTest::test__unit__sequentialIdsOneThenTwo` | C1 |
| `VolOrderManagerBatchEquivalenceTest::test__unit__batchOfOneEqualsSingleCall` | C1 |
| `VolOrderManagerBatchGasTest::test__unit__maxBatchGasUnderBudget` | C1 (`orderCount advanced by 128: 0 != 128`) |
| `VolOrderManagerBatchGuardTest::test__unit__maxBatchExactlyOneTwoEightSucceeds` | C1 (`all 128 tuples stored: 0 != 128`) |
| `VolOrderManagerBatchStateTest::test__unit__dirtyHighBitsAreSkippedNotStored` | C1 |
| `VolOrderManagerBatchStateTest::test__unit__mixedBatchFootprintAndContiguity` | C1 (`returns the success count: 0 != 2`) |
| `VolOrderManagerBatchTotalityTest::test__fuzz__batchNeverReverts` | C1 |
| `VolOrderManagerReturnEncodingTest::test__fuzz__returnBytesMatchStandardEncoder` | C1 (returndata differs — the element now carries targetVega) |
| `VolOrderManagerReturnEncodingTest::test__unit__maxBatchReturnIsByteExactAndUncorrupted` | C1 |
| `VolOrderManagerReturnEncodingTest::test__unit__mixedBatchReturnIsByteExact` | C1 |
| `VolOrderManagerReturnEncodingTest::test__unit__oneAndTwoElementReturnsAreByteExact` | C1 |
| `VolOrderManagerFixtureTest::test__unit__moduleReturnMatchesExternalEncoderFixture` | C1 — the v4.0 golden fixture was generated against the v1 3-arg encoding |
| `VolOrderManagerSelectorCompletenessTest::test__unit__everyInterfaceSignatureStringIsPinned` | C1 — asserts the interface carries `create_order(uint88,uint24,uint16)`; it now carries the 4-arg V2 string. **This test did its job**: it is the pin that DETECTED the source-of-truth change. |
| `SpreadTickAssimetryTest::setUp` (suite) | C3 + C2 — was 2 fuzz reds pre-import, now 1 setUp red |
| `VolRangeWidthTest::setUp` (suite) | C3 — was 2 fuzz reds pre-import, now 1 setUp red |
| `VolOrderTest::setUp` (suite) | C2 |
| `VolOrderValidationBoundaryTest::setUp` (suite) | C4 |
| `VolOrderValidationPackingTest::setUp` (suite) | C4 |
| `VolOrderValidationStrikeBoundTest::setUp` (suite) | C4 |

Counted by transition: **1 carried pre-existing (P), 2 transformed** (SpreadTickAssimetry,
VolRangeWidth — already red, now red at `setUp` instead of per-test), **24 genuinely new**.

## compile-plank delta, reconciled exactly

| entrypoint | before | after | cause |
|---|---|---|---|
| `test/types/pos_spec/SpreadTickAssimetryHelper.plk` | OK | **FAIL** | C2 |
| `test/types/pos_spec/VolOrderHelper.plk` | OK | **FAIL** | C2 |
| `test/types/pos_spec/VolOrderValidationHarness.plk` | OK | **FAIL** | C4 |
| `src/modules/premium/DynamicFeeMod.plk` | (absent) | **OK** | newly IMPORTED by this plan |
| `src/modules/protocol_integrations/DynamicFeeHook.plk` | (absent) | **OK** | newly IMPORTED by this plan |

Arithmetic: 14 ok − 3 now-failing + 2 newly imported = **13 ok / 3 failed / 16 entrypoints**.
Matches the measured `compile-plank: 13 ok, 3 failed, 0 skipped` exactly.

Note `VolRangeWidthHelper.plk` compiles **OK** under `make compile-plank` (whose recipe passes the
full dependency set) while the SAME file fails under `forge test`'s FFI (narrower per-test set).
That divergence is itself the proof that C3 is a dependency-root problem, not a content problem.

## Attribution

Expected and NOT repaired (research 7.5): `test/pos_spec/*.t.sol` on this branch exercises
the v1 3-arg `create_order`; the imported V2 modules make those tests fail AT RUNTIME
(`.plk` files are never seen by solc, so `forge build` is unaffected — re-confirmed above,
exit 0). `test/` belongs to the Solidity-testing session per `CLAUDE.md`. Every new red above is
reported to that track, not fixed here.

`git status --porcelain test/ Makefile foundry.toml remappings.txt` is EMPTY — nothing under
`test/` was touched, and no plank-owned config was edited.

## Hand-off to the Solidity-testing session (PID 284909)

The four causes are independent and C2/C3 are mechanical:

1. **C2** — repoint two harness imports: `lib::TickUtils` → `types::pricing::TickUtils`
   (`test/types/pos_spec/VolOrderHelper.plk:6`, `test/types/pos_spec/SpreadTickAssimetryHelper.plk:3`).
2. **C3** — add `Dependency("types", "src/types")` to the narrow per-test build option sets.
   Verified sufficient by direct measurement.
3. **C4** — update `VolOrderValidationHarness.plk` call sites to the V2 arity.
4. **C1** — the real work: migrate the `test/pos_spec/` corpus to the 4-arg V2 `create_order`
   and regenerate the golden fixture. Note `test__unit__everyInterfaceSignatureStringIsPinned`
   is a WORKING pin, not a bug — it fired exactly as designed.
