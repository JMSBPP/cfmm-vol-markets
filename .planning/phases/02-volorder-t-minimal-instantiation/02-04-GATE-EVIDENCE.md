# Phase 2 / plan 02-04 gate evidence — VolOrder(T) minimal instantiation

- **Refactor commit:** `c9844d1a7a18739812fab09eebcfb712aac40ee0` (4 files, +94/−38)  **Branch:** `feat/volorder-t-minimal`  **PR:** https://github.com/JMSBPP/cfmm-vol-markets/pull/62
- **Runs:** develop-gate `33171200236` (https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33171200236), push-build `33171197208` (https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33171197208) — both success, FIRST push, no fix commits
- **Baseline:** develop-gate `33168567137` (02-01 GATE_POST2) — same toolchain (plank `00c0a1aa3cb40b63de81c6ca4f92bec392b423c3`, forge `b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`)
- **Harvested:** 2026-08-28T12:34:28Z

## Toolchain
    forge Version: 1.5.1-v1.5.1
    Commit SHA: b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2

## Criterion 2 — gate green; plank compiles VolOrder(T); forge runs the full suite
| | 02-01 baseline `33168567137` | 02-04 `33171200236` |
|---|---|---|
| `Ran N test suites …` | `Ran 75 test suites in 6.41s (31.21s CPU time): 273 tests passed, 0 failed, 3 skipped (276 total tests)` | `Ran 75 test suites in 6.33s (31.48s CPU time): 273 tests passed, 0 failed, 3 skipped (276 total tests)` |
| `compile-plank:` | `compile-plank: 38 ok, 0 failed, 0 skipped` | `compile-plank: 38 ok, 0 failed, 0 skipped` |
| compile-plank OK/FAIL entry set | 38 | **IDENTICAL** (`diff` empty) |
| `warning` lines (forge job) | 236 | 236 |

Job conclusions: approve=success forge=success plank=success gate=success.

Verbatim, one run per line:

    02-01 33168567137  compile-plank: 38 ok, 0 failed, 0 skipped
    02-04 33171200236  compile-plank: 38 ok, 0 failed, 0 skipped

`compile-plank` OK lines for the VolOrder(T) entrypoints:
   OK   src/modules/pos_spec/VolOrderManagerMod.plk -> build/plank/src_modules_pos_spec_VolOrderManagerMod.hex
   OK   test/protocol_integrations/VolOrderMintSizingHarness.plk -> build/plank/test_protocol_integrations_VolOrderMintSizingHarness.hex
   OK   test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk -> build/plank/test_protocol_integrations_VolOrderToPanopticTokenIdHarness.hex
   OK   test/types/pos_spec/VolOrderHelper.plk -> build/plank/test_types_pos_spec_VolOrderHelper.hex
   OK   test/types/pos_spec/VolOrderValidationHarness.plk -> build/plank/test_types_pos_spec_VolOrderValidationHarness.hex

## Criterion 3 — regression floor untouched and green (VORD-02 bit-identity)
`git diff origin/develop -- test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` → **0 bytes**.
    Ran 10 tests for test/protocol_integrations/VolOrderToPanopticTokenId.t.sol:VolOrderToPanopticTokenIdTest
    [PASS] testFuzz_legFromBucket_reconstructs(int256,uint256,int256) (runs: 256, μ: 12984, ~: 12902)
    [PASS] testFuzz_map_validAndTiles(uint256,uint256) (runs: 256, μ: 41850, ~: 41911)
    [PASS] test_legFromBucket_negativeOdd() (gas: 7667)
    [PASS] test_legFromBucket_positiveEven() (gas: 7897)
    [PASS] test_legFromBucket_positiveOdd() (gas: 7941)
    [PASS] test_map_goldenStructure() (gas: 23979)
    [PASS] test_map_guard_passesAtExactly2ts() (gas: 17796)
    [PASS] test_map_guard_revertsOnNarrowSide() (gas: 13986)
    [PASS] test_map_guard_revertsOnWidthOverflow() (gas: 14572)
    [PASS] test_map_validatesAsPanoptic() (gas: 22171)
    Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 221.52ms (119.33ms CPU time)

## Criterion 5 — VORD-03 callers + harness compile; differential still compiles and skips
`vol_order_to_mint`, `position_size_for_target_vega`, `vol_order_leg_split`, `induced_leg_liquidities`, `average_density_chunks` — all reached through `VolOrderMintSizingHarness.plk`, whose diff is 0 bytes:
    Ran 8 tests for test/protocol_integrations/VolOrderMintSizing.t.sol:VolOrderMintSizingTest
    [PASS] test__coupling__fineGridProfilesCoincide() (gas: 96805)
    [PASS] test__coupling__totalsAgreeOnAnyGrid() (gas: 136335)
    [PASS] test__fuzz__oneSidedIdentityAcrossOrders(uint256,uint256,uint96) (runs: 256, μ: 52444, ~: 52462)
    [PASS] test__unit__assetBitPinnedToOne() (gas: 38534)
    [PASS] test__unit__dustTargetReverts() (gas: 36669)
    [PASS] test__unit__inducedProfileMatchesPlan() (gas: 87191)
    [PASS] test__unit__positionSizeIsMaximalOneSided() (gas: 56480)
    [PASS] test__unit__positionSizeMatchesOracle() (gas: 48221)
    Suite result: ok. 8 passed; 0 failed; 0 skipped; finished in 231.90ms (115.14ms CPU time)
    Ran 3 tests for test/pos_spec/VolOrderManagerFixture.t.sol:VolOrderManagerFixtureTest
    [PASS] test__unit__externalEncoderConfirmsTheEmptyEncodingIsSixtyFourBytes() (gas: 11982)

Differential (`SKIP_REASON` at `VolOrderToPanopticTokenId.diff.t.sol:109`):
    Ran 4 tests for test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol:VolOrderToPanopticTokenIdDiffTest
    [SKIP: spec oracle not wired: SpecOracle.health() reports TransportFailure (RED-05). Wired in Phase 7, enforced in Phase 11 (CI-04).] test__fuzz_differential__volOrder(uint256,uint256,uint256,uint256,uint256,uint256,uint256) (runs: 0, μ: 0, ~: 0)
    [SKIP: spec oracle not wired: SpecOracle.health() reports TransportFailure (RED-05). Wired in Phase 7, enforced in Phase 11 (CI-04).] test_differential__volOrder__anchor() (gas: 0)
    [PASS] test_implSide_answersOnAnchor() (gas: 18152)
    [PASS] test_specHelper_stubRevertsAndProbeReportsNotWired() (gas: 16680)
    Suite result: ok. 2 passed; 0 failed; 2 skipped; finished in 99.98ms (1.33ms CPU time)

`git diff origin/develop -- test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol test/protocol_integrations/SpecHelper.sol` → **0 bytes**.

## ABI edge — frozen surface (CONTEXT.md)
PRE (02-02, run `33169215017`):
    abi-edge sha256: e801b0e1dea74b1316ce8991663c914da64b31ab359127c67f56a788689077d9
    abi-edge selector: 0x08c379a0
    abi-edge selector: 0x4e487b71
    abi-edge selector: 0x728ebb96
    abi-edge selector: 0xa00af595
    abi-edge selector: 0xed7143d4
    abi-edge selector: 0xfe7ebf55
    abi-edge selector: 0xffffffff
    abi-edge selector-count: 7
---
POST (02-04, run `33171197208`):
    abi-edge sha256: eb0636086f73cbc5e7fd5170a8918dff8d96d242b7709d5970de47df022d2d33
    abi-edge selector: 0x08c379a0
    abi-edge selector: 0x4e487b71
    abi-edge selector: 0x728ebb96
    abi-edge selector: 0xa00af595
    abi-edge selector: 0xed7143d4
    abi-edge selector: 0xfe7ebf55
    abi-edge selector: 0xffffffff
    abi-edge selector-count: 7

**Selector set: IDENTICAL** (all 7, including the four dispatch selectors `0xfe7ebf55 0xa00af595 0xed7143d4 0x728ebb96`).
**sha256: DIFFERENT** — the compiled bytes moved while the dispatch surface did not. Expected: the tokenId path now routes through `vol_order_base(T, vo)` and the import set changed; the surface claim rests on the selector set plus the untouched golden vectors passing 10/10, which is exactly what the 02-02 baseline said would be judged either way.

## Files changed vs origin/develop (committed; src/ test/ foundry-scripts/)
- `src/lib/market_state_measurements/RealizedVolatilityStateLib.plk`
- `src/lib/pos_spec/TickVolatilityLib.plk`
- `src/lib/pos_spec/VolOrderValidationLib.plk`
- `src/lib/protocol_integrations/PanopticTokenIdSetterLib.plk`
- `src/modules/VolOrderManagerMod.plk`
- `src/types/market_state_measurements/Timepoint.plk`
- `src/types/pos_spec/VolOrder.plk`
- `src/types/pos_spec/VolRangeWidth.plk`
- `test/lib/pos_spec/TickVolatilityLibHelper.plk`
- `test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk`
- `test/types/pos_spec/VolOrderValidationHarness.plk`
- `test/types/pos_spec/VolRangeWidthHelper.plk`

12 paths: the 8 std-move files from 02-01 + the 4 refactor files. (`git diff origin/develop` without `HEAD` shows 13 because `src/modules/premium/DynamicFeeMod.plk` is a pre-existing UNCOMMITTED dirty file in the working tree — never staged, not on the branch.)

## Anomalies
1. **sha256 moved, selector set did not** — recorded above. Not a surface change; internals only.
2. **Two mechanical sites the plan's sed missed:** `VolOrder.plk` `set_vol_order_skew` and `set_vol_order_range_width` had `self: VolOrder ,skew` (space before the comma), which `VolOrder([,)])` does not match. Reconciled by hand per the plan; the sed was not loosened.
3. **The plan's own comments inflate its own counts:** `grep -c 'VolOrder(none)'` reads 20 (not 18) in `VolOrder.plk` and 6 (not 5) in `PanopticTokenIdSetterLib.plk` because the comment blocks the plan itself inserts contain the string. Comment-stripped counts are exactly 18 and 5. Same class as Phase 1's seven grep-forbids-its-own-documentation cases; also the `@compile_error("VolOrder: …")` STRING LITERAL matches the "bare VolOrder" regex.
4. `set -e` in the executor's shell did not abort on the first failed count, so Task 2's edits ran before Task 1's reconciliation. No wrong state was committed — the reconciliation happened before the single commit.
5. First-push green: no `fix(02-04)` commit was needed; Plank's comptime-if pruning and `T == none` comparison behaved exactly as `Shock(R)` and `std/regions.plk` implied.
