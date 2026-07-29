---
phase: 17-interface-single-call-module
verified: 2026-07-20T17:23:40Z
status: passed
score: 7/7 must-haves verified
---

# Phase 17: Interface & Single-Call Module Verification Report

**Phase Goal:** `create_order` is a live, CALLED-green registry entrypoint — the base case the
batch will compose N times — with both selectors pinned so the peer contract cannot drift
silently.
**Verified:** 2026-07-20T17:23:40Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A caller can submit a valid tuple through `create_order`, exact tuple stored at id 1 with `tickSpacing == 20`, observed by raw `vm.load` | ✓ VERIFIED | `test__unit__sequentialIdsOneThenTwo` PASS (gas 88380), field-by-field decomposition of raw slot word, no getter trusted |
| 2 | A second valid order gets id 2 in the same test that proved the first got id 1 — no ring mask | ✓ VERIFIED | Same test, `orderSlot(2)` decodes second tuple, `orderSlot(1)` unchanged |
| 3 | An invalid tuple REVERTS, leaves `orderCount` and every order slot untouched — asserted on STATE | ✓ VERIFIED | `test__unit__invalidSkewRevertsAndLeavesStateUntouched`, `test__unit__invalidSkewAfterAValidOrderDoesNotDisturbIt` both PASS, assertions on raw `vm.load`, not return data |
| 4 | `orderCount()` and `getOrderPacked(uint256)` each CALLED through FFI-deployed bytecode; nonexistent id returns 0 without reverting | ✓ VERIFIED | `test__unit__readersReturnStoredValues`, `test__unit__getOrderPackedNonexistentReturnsZeroWithoutReverting` PASS; boundary pinned by `test__unit__getOrderPackedOverflowBoundaryIsExactlyWhereCheckedAddSaturates` |
| 5 | Both entrypoint selectors equal `keccak(signature)[:4]`, recomputed with `cast sig`, not hand-copied | ✓ VERIFIED | Independently re-ran all 4 `cast sig` + 2 `cast keccak` — exact match to SUMMARY and to module/interface constants (see table below) |
| 6 | Scalar `orderCount` slot is >2^64 from the orders region base | ✓ VERIFIED | `test__unit__scalarSlotFarFromOrdersRegion` PASS, distance asserted as a value |
| 7 | Slot `keccak(base)+0` is never written and stays permanently zero (0-sentinel soundness) | ✓ VERIFIED | Reasoning present in-code (lines 62-66 of module); `orderSlot(0)` asserted zero in `sequentialIdsOneThenTwo`, `idAt65536IsNotMaskedIntoSlotZero`, and the guard tests |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `src/interfaces/pos_spec/VolOrderManagerInterface.plk` | 4 selector constants, signature-string comments | ✓ VERIFIED | 26 lines (≥25 required); contains `SELECTOR_CREATE_ORDERS`; all 4 constants match independently-recomputed `cast sig` |
| `src/modules/pos_spec/VolOrderManagerMod.plk` | Dispatch, 2 readers, keccak slots | ✓ VERIFIED | 85 lines (≥60 required); contains `array_slot(SLOT_ORDERS_BASE`; sha256 `171c8404…c2eb` matches SUMMARY-recorded baseline exactly |
| `test/pos_spec/VolOrderManager.t.sol` | CALLED-green module suite | ✓ VERIFIED | 369 lines (≥200 required); 12 tests, all PASS, `runs: 256` real fuzz |
| `Makefile` | `test-vol-order-manager` target + `.PHONY` | ✓ VERIFIED | `grep -c 'test-vol-order-manager'` = 3 (comment/target/.PHONY) |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `VolOrderManagerMod.plk` | `VolOrderValidationLib::validate_order_strict` | direct call before id derivation | WIRED | line 56, precedes `let id = ...` at line 67 |
| `VolOrderManagerMod.plk` | `VolOrderValidationLib::build_vol_order` | struct construction from calldata | WIRED | line 52 |
| `VolOrderManagerMod.plk` | `pos_spec::VolOrder::pack_vol_order` | value arg of order sstore | WIRED | line 68 |
| `VolOrderManagerMod.plk` | `v3::storage::array_slot` | unmasked derived-slot address | WIRED | `import v3::storage::{array_slot}` line 27; `StorageIndex` NOT imported (grep = 0) |
| `test/pos_spec/VolOrderManager.t.sol` | `VolOrderManagerMod.plk` | `deployPlank` FFI in `setUp` | WIRED | line 62 |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| VORD-01 | 17-01 | `create_order` selector pinned, validates via pure lib, REVERTS on invalid tuple | ✓ SATISFIED | Selector `0x6501fe94` cast-sig-matched; `validate_order_strict` called before store; guard tests green |
| VORD-03 | 17-01 | Sequential ids from 1, `orderCount` advances only on success, sound 0-sentinel | ✓ SATISFIED | `sequentialIdsOneThenTwo`, guard tests, M2/M4 mutation kills all confirm |
| VORD-04 | 17-01 | Orders at `array_slot(base, id)`, monotonic, no ring mask, slot-distance compile-time value | ✓ SATISFIED | M1 independently re-killed; `scalarSlotFarFromOrdersRegion` PASS; StorageIndex not imported |
| VORD-05 | 17-01 | Both readers expose state, zero DOMAIN arithmetic, `getOrderPacked` nonreverting on nonexistent id | ✓ SATISFIED | Readers CALLED and match raw slots; zero-arithmetic grep = 1 line (the id `+1`); MAX_SAFE_ID boundary pinned |

REQUIREMENTS.md traceability table: VORD-01/03/04/05 all listed `Phase 17 | Complete`, consistent
with the plan's declared `requirements: [VORD-01, VORD-03, VORD-04, VORD-05]`. No orphaned
requirements (VORD-02 belongs to Phase 16, correctly excluded).

### Anti-Patterns Found

None. `grep -n -E "TODO|FIXME|XXX|HACK|PLACEHOLDER"` and case-insensitive `placeholder|coming soon`
across all three created files returned no matches. No empty-return stubs, no console-log-only
handlers.

### Independent Re-derivation Results

1. **Cold-cache runs.** `rm -rf cache/fuzz && make test-vol-order-manager`: 12 passed, 0 failed,
   0 skipped, fuzz `runs: 256`. `make compile-plank`: `13 ok, 0 failed, 0 skipped`, `PLANK_SKIP`
   confirmed empty (grep for the file in Makefile's skip list — absent).

2. **`make test` flake claim — INDEPENDENTLY CONFIRMED, PRE-EXISTING.** The three Phase-17 files
   (`src/interfaces/pos_spec/VolOrderManagerInterface.plk`,
   `src/modules/pos_spec/VolOrderManagerMod.plk`, `test/pos_spec/VolOrderManager.t.sol`) were
   physically moved out of the tree (they are fully committed at `eb95356`/`7f6cfe1`/`95df2ab`, so
   this is git-reversible). With those files absent, three consecutive cold-cache `make test` runs
   all reported `87 passed, 4 failed, 0 skipped` — the same 4 pre-existing reds in
   `test/types/pos_spec/`, matching the SUMMARY's "modal" baseline exactly. To force the flake
   directly (rather than wait on random seeding), the single test was re-run in isolation at
   `--fuzz-runs 20000` — **still with the Phase-17 files absent** — and it FAILED at
   `volLevel=18446744073709551614` (`2^64-2`), reproducing
   `TickVolatilityLibTest::test__fuzz__tickVolatilitySqrtPriceX64x96AndTickSuccess`'s counterexample
   region. A mechanistic check confirms *why*: `expectedSqrtPrice = volLevel << 96` exceeds
   Uniswap's `MAX_SQRT_RATIO` for any `volLevel` above `18446050711097703530`, a ~0.0038%-wide band
   just under `type(uint64).max` — the exact accept bound this unrelated test uses via
   `vm.assume(volLevel <= type(uint64).max)`. **CONFIRMED: this is NOT a Phase 17 regression.**
   The three files were restored afterward (`git status --porcelain` on their paths is clean, and a
   subsequent `make test-vol-order-manager` run was green).

3. **Six pinned constants — all independently recomputed, exact match, no discrepancies:**
   ```
   cast sig "create_order(uint88,uint24,uint16)"  -> 0x6501fe94
   cast sig "create_orders(uint256,uint256[])"    -> 0x81357911
   cast sig "orderCount()"                        -> 0x2453ffa8
   cast sig "getOrderPacked(uint256)"              -> 0xa9bcabc1
   cast keccak "VolOrderManagerMod.orderCount"    -> 0x92967cb44e7866428adae18aad4bf59a10fb8d4c189b2b0e8bfe6f2a2469b5c7
   cast keccak "VolOrderManagerMod.orders"        -> 0x68fef5d6c1ef01f93bf897a4ffcaa37fbdc39061144008f6edd91f64b7b199cb
   ```

4. **Module code review:** zero domain arithmetic (only `+ 1` for id, one arithmetic line); calls
   `build_vol_order` and `validate_order_strict` from the Phase-16 lib (no hand-building, no
   re-validation); calls `pack_vol_order` from the type; `StorageIndex.plk` NOT imported (only
   named in a comment); 0-sentinel soundness reasoning present in-code (lines 62-66).

5. **`git diff eb95356~1 HEAD --stat -- src/types/pos_spec/`** — empty, confirmed. That tree is
   untouched by this phase.

6. **M1 independently re-killed.** Reintroduced `& 0xFFFF` into the order sstore's slot derivation,
   `rm -rf cache/fuzz`, ran the suite: `test__unit__idAt65536IsNotMaskedIntoSlotZero` FAILED with
   the **exact verbatim line** recorded in the SUMMARY (`gas: 33779`, same value
   `204169420558211270151058172938006761635917`); `sequentialIdsOneThenTwo` and all other 10 tests
   stayed GREEN (11 passed, 1 failed) — confirming the small-id-tests-insufficient claim. Restored
   via `git checkout`, sha256 re-verified `171c8404…c2eb`, suite green again.

7. **M5 equivalence independently re-confirmed.** Hoisted the counter store above
   `validate_order_strict`: suite stayed GREEN (12 passed, 0 failed) via revert-rollback, exactly as
   the SUMMARY records. Restored, sha256-identical, green.

8. **The plan's `getOrderPacked(type(uint256).max) == 0` bug claim — CONFIRMED FALSE, and NOT
   worked around.** `array_slot`'s `@evm_keccak256(buf, 32) + index` (storage.plk:230-234) is a
   plain Plank `+`, and the deployed-bytecode boundary test
   (`test__unit__getOrderPackedOverflowBoundaryIsExactlyWhereCheckedAddSaturates`) proves it
   CHECKED: `getOrderPacked(MAX_SAFE_ID)` returns 0 (PASS), `getOrderPacked(MAX_SAFE_ID + 1)` call
   fails (`ok == false`, panic 0x11). The module and `array_slot` were confirmed byte-unmodified;
   only the test's assertion target changed from `type(uint256).max` to the derived `MAX_SAFE_ID`.

9. **Dispatch coverage:** no `vm.assume` in the test file (only 2 matches, both in comments stating
   the rule); every fuzz test (`test__fuzz__validTupleStoresExactPackedWord`) has a named non-fuzz
   anchor (`sequentialIdsOneThenTwo`, stated in its doc comment); all four dispatch branches are
   CALLED — `create_order` (10 call sites), `orderCount` (10), `getOrderPacked` (12), and the
   unknown-selector fallthrough (`test__unit__batchSelectorNotYetDispatched` calls the undispatched
   `0x81357911` selector and asserts `ok == false`).

### Human Verification Required

None. All must-haves, artifacts, key links, mutation-gate claims, and the flake investigation were
independently re-derived programmatically.

### Gaps Summary

No gaps found. All 7 observable truths verified, all 4 required artifacts exist/are
substantive/are wired, all 5 key links confirmed wired, both mutation-gate re-kills (M1, M5)
reproduced the SUMMARY's exact recorded results, and the pre-existing-flake claim was independently
confirmed by both a 3x cold-cache differential run (files removed) and a mechanistic root-cause
derivation (an unrelated `TickVolatilityLibTest` accept-set boundary bug, ~0.0038% of its input
range, unconnected to any Phase 17 file).

---

_Verified: 2026-07-20T17:23:40Z_
_Verifier: Claude (gsd-verifier)_
