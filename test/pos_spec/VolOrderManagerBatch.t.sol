// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVolOrderManager, VolOrderManagerBase} from "./VolOrderManager.t.sol";

// ===========================================================================================
// THE create_orders BATCH surface (MCAL-01/02/03/04/06). Phase 18a.
//
// WHY A SEPARATE FILE FROM VolOrderManager.t.sol. That file owns the SINGLE-CALL surface and
// states the project's one-file-per-surface convention in its own header. The batch is a
// categorically distinct surface and -- decisively -- it requires HAND-ROLLED MALFORMED
// CALLDATA delivered by low-level `.call`, which a typed Solidity `interface` cannot express
// at all: abi.encodeWithSelector is incapable of emitting a non-canonical offset or a length
// that disagrees with count. Keeping those builders out of the single-call file also keeps
// --match-path targets disjoint, so a batch red can never be misread as a single-call red.
//
// Reuse, not duplication: VolOrderManagerBase supplies the slot preimages, orderSlot(),
// expectedPacked() and the STRIKE/WIDTH/SKEW anchor tuple.
//
// GLOBAL RULE, carried from Phase 17: "it compiles" is never acceptance. deployPlank shells
// out to `plank build` over FFI at TEST TIME, so every assertion below runs the DEPLOYED
// bytecode of src/modules/pos_spec/VolOrderManagerMod.plk.
//
// DISCIPLINE: assumption-based input filtering is banned outright -- corpora are CONSTRUCTED
// with `bound`, so no draw is ever discarded and no run is ever silently empty. Every fuzz names a
// non-fuzz anchor; guards are asserted ON STATE -- with ONE deliberate exception, guard 3,
// whose mutant is invisible to state and must be killed by a REVERT assertion. See
// test__unit__truncatedCalldataReverts.
//
// GUARD NAMING, used consistently here and in the plan's mutant table: "guard 1 / 2 / 3"
// ALWAYS means offset / length / calldatasize. The MAX_BATCH bound is NOT one of MCAL-02's
// three calldata guards and is named separately.
// ===========================================================================================

abstract contract VolOrderManagerBatchBase is VolOrderManagerBase {
    bytes4 internal constant SEL_CREATE_ORDERS = bytes4(0x81357911);

    /// @dev Restated from the module. Pinned BEHAVIOURALLY by the 128-succeeds / 129-reverts
    ///      pair below, which is stronger than restating a constant.
    uint256 internal constant MAX_BATCH = 128;

    /// @dev The INPUT word layout: skew at bits 0..15, strike at 16..103, width at 104..127;
    ///      bits 128..255 MUST be zero. DISTINCT from expectedPacked(), which is the STORED
    ///      layout (width at 128, tickSpacing at 104, strike at 16, skew at 0). Only `width`
    ///      moves between the two, because build_vol_order inserts TICK_SPACING = 20 at bits
    ///      104..127 on the way to pack_vol_order.
    function packInput(uint256 strike, uint256 width, uint256 skew) internal pure returns (uint256) {
        return skew | (strike << 16) | (width << 104);
    }

    /// @dev The CANONICAL encoding. Solidity emits the offset 0x40 at byte 36 and the length at
    ///      byte 68, which is exactly the layout the module guards. Verified against
    ///      `cast calldata "create_orders(uint256,uint256[])"` and re-verified in
    ///      test__unit__canonicalEncodingMatchesTheVerifiedLayout below.
    function encodeBatch(uint256[] memory words) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(SEL_CREATE_ORDERS, words.length, words);
    }

    /// @dev Hand-rolled head so `offset` and `length` can be set INDEPENDENTLY of the real
    ///      array. abi.encodeWithSelector cannot produce a malformed encoding -- that is the
    ///      whole reason these builders exist, and the whole reason the guards need a
    ///      low-level .call to test at all.
    function encodeBatchRaw(uint256 count, uint256 offset, uint256 length, uint256[] memory words)
        internal
        pure
        returns (bytes memory out)
    {
        out = abi.encodePacked(SEL_CREATE_ORDERS, count, offset, length);
        for (uint256 j = 0; j < words.length; j++) {
            out = abi.encodePacked(out, words[j]);
        }
    }

    function truncate(bytes memory b, uint256 dropBytes) internal pure returns (bytes memory out) {
        out = new bytes(b.length - dropBytes);
        for (uint256 j = 0; j < out.length; j++) {
            out[j] = b[j];
        }
    }

    /// @dev Reads the 32-byte word at byte `off` of `b`. Used to prove the BUILDERS themselves
    ///      match the verified layout, so a builder bug can never be mistaken for a module bug.
    function wordAt(bytes memory b, uint256 off) internal pure returns (uint256 w) {
        assembly {
            w := mload(add(add(b, 0x20), off))
        }
    }

    /// @dev THE ONLY PATH INTO THE MODULE IN THIS FILE, and deliberately so: every batch
    ///      assertion below reaches the module through this raw `address(mgr).call`, never
    ///      through the typed IVolOrderManager interface, because a typed interface cannot
    ///      express a malformed encoding. Eleven call sites funnel through this one helper.
    ///      (The plan's acceptance grep counted `address(mgr).call(` occurrences expecting >= 5,
    ///      which assumed the call were inlined per test; that contradicts the same plan's own
    ///      mandate to define this helper. Resolved in favour of the helper -- the property the
    ///      criterion exists to establish, "the guards are exercised through low-level calls
    ///      rather than the typed interface", is what is actually true here, and is stronger
    ///      for being unavoidable: there is no typed batch entrypoint to accidentally use.)
    function callBatch(bytes memory cd) internal returns (bool ok, uint256 ret) {
        bytes memory r;
        (ok, r) = address(mgr).call(cd);
        if (ok && r.length == 32) ret = abi.decode(r, (uint256));
    }
}

/// @title VolOrderManagerBatchEncodingTest
/// @notice Sanity-pins the TEST BUILDERS against the verified calldata layout. Without this,
///         a builder bug would surface as a module failure and burn the mutation evidence.
contract VolOrderManagerBatchEncodingTest is VolOrderManagerBatchBase {
    function test__unit__canonicalEncodingMatchesTheVerifiedLayout() public pure {
        assertEq(encodeBatch(new uint256[](0)).length, 100, "N=0 encodes to exactly 100 bytes");

        uint256[] memory one = new uint256[](1);
        assertEq(encodeBatch(one).length, 132, "N=1 encodes to exactly 132 bytes");

        uint256[] memory two = new uint256[](2);
        two[0] = 111;
        two[1] = 222;
        bytes memory cd = encodeBatch(two);
        assertEq(cd.length, 164, "N=2 encodes to exactly 164 bytes");
        assertEq(wordAt(cd, 4), 2, "count sits at byte 4");
        assertEq(wordAt(cd, 36), 0x40, "the canonical array offset sits at byte 36, not 68");
        assertEq(wordAt(cd, 68), 2, "the array length sits at byte 68");
        assertEq(wordAt(cd, 100), 111, "element 0 at byte 100");
        assertEq(wordAt(cd, 132), 222, "element 1 at byte 100 + 32");
    }

    /// @notice The hand-rolled builder must produce a byte-identical result to Solidity's own
    ///         encoder when handed canonical arguments -- otherwise the guard tests would be
    ///         comparing the module against a broken reference.
    function test__unit__rawBuilderMatchesCanonicalWhenWellFormed() public pure {
        uint256[] memory two = new uint256[](2);
        two[0] = 111;
        two[1] = 222;
        assertEq(
            keccak256(encodeBatchRaw(2, 0x40, 2, two)),
            keccak256(encodeBatch(two)),
            "encodeBatchRaw(count, 0x40, count, words) == abi.encodeWithSelector"
        );
    }
}

/// @title VolOrderManagerBatchStateTest
/// @notice MCAL-03 + MCAL-01 (SC-1). THE FLAGSHIP: skip-without-footprint and id CONTIGUITY,
///         asserted on raw slots.
contract VolOrderManagerBatchStateTest is VolOrderManagerBatchBase {
    /// @notice THE FLAGSHIP. The invalid tuple sits strictly in the MIDDLE, which is what makes
    ///         the contiguity assertion discriminating: under the M5 counter-hoist mutant the
    ///         skipped tuple CONSUMES id C+2, valid_B lands at C+3, and slot C+2 stays zero. A
    ///         count-only corpus does NOT distinguish that mutant from correct code.
    ///
    ///         The counter is SEEDED to a nonzero C so a "batch always starts at id 1" bug
    ///         cannot hide behind a fresh registry.
    ///
    ///         Also the named NON-FUZZ ANCHOR for test__fuzz__batchNeverReverts.
    function test__unit__mixedBatchFootprintAndContiguity() public {
        vm.store(address(mgr), SLOT_ORDER_COUNT, bytes32(uint256(5)));
        assertEq(mgr.orderCount(), 5, "precondition: counter seeded to C = 5");

        uint256[] memory words = new uint256[](3);
        words[0] = packInput(STRIKE, WIDTH, SKEW);
        // skew 65535 is one of only TWO rejected skews (accept set [1, 65534]); strike and width
        // are comfortably valid, so EXACTLY ONE conjunct fails and the failure is named.
        words[1] = packInput(STRIKE, WIDTH, 65535);
        words[2] = packInput(999, 7, 3);

        (bool ok, uint256 ret) = callBatch(encodeBatch(words));

        assertTrue(ok, "a mixed batch never reverts");
        assertEq(ret, 2, "returns the success count");
        assertEq(mgr.orderCount(), 7, "orderCount advances by the success count, not by N");
        assertEq(
            uint256(vm.load(address(mgr), orderSlot(6))),
            expectedPacked(STRIKE, WIDTH, SKEW),
            "valid_A at C+1"
        );
        // <- THE LOAD-BEARING ASSERTION (M5 kill site).
        assertEq(
            uint256(vm.load(address(mgr), orderSlot(7))),
            expectedPacked(999, 7, 3),
            "id contiguity: third valid order at C+2"
        );
        assertEq(uint256(vm.load(address(mgr), orderSlot(8))), 0, "no order beyond orderCount");
    }

    /// @notice Dirty high bits are a SKIP, not a revert. `width` is read UNMASKED, so any bit
    ///         >= 128 inflates it past 0xffffff and vol_range_width_is_complete rejects it.
    ///         This is the module's whole-word-read stance (dirty bits rejected by VALIDATION,
    ///         never truncated) applied to the batch, and it costs zero new arithmetic.
    function test__unit__dirtyHighBitsAreSkippedNotStored() public {
        uint256[] memory words = new uint256[](1);
        words[0] = packInput(STRIKE, WIDTH, SKEW) | (uint256(1) << 200);

        (bool ok, uint256 ret) = callBatch(encodeBatch(words));

        assertTrue(ok, "a dirty word is skipped, not reverted");
        assertEq(ret, 0, "no tuple succeeded");
        assertEq(mgr.orderCount(), 0, "orderCount unchanged by a skipped tuple");
        assertEq(uint256(vm.load(address(mgr), orderSlot(1))), 0, "nothing was stored");
    }
}

/// @title VolOrderManagerBatchGuardTest
/// @notice MCAL-02 + MCAL-01 (SC-2, SC-3). Every test here drives the module through a raw
///         low-level .call, because a typed interface cannot express a malformed encoding.
contract VolOrderManagerBatchGuardTest is VolOrderManagerBatchBase {
    function _validWord() internal pure returns (uint256) {
        return packInput(STRIKE, WIDTH, SKEW);
    }

    /// @notice GUARD 1. A hostile offset pointing far past the array is the PHANTOM-ORDER
    ///         attack this guard exists to stop -- not merely "a wrong value". With the guard
    ///         deleted, the loop keeps reading the fixed byte-100 region and happily stores
    ///         tuples the caller's encoder never placed there.
    function test__unit__nonCanonicalOffsetReverts() public {
        uint256[] memory words = new uint256[](1);
        words[0] = _validWord();

        (bool ok,) = callBatch(encodeBatchRaw(1, 0x2000, 1, words));

        assertFalse(ok, "guard 1: non-canonical offset must revert the whole tx");
        assertEq(mgr.orderCount(), 0, "guard 1: orderCount unchanged");
        assertEq(uint256(vm.load(address(mgr), orderSlot(1))), 0, "guard 1: no slot written");
    }

    /// @notice GUARD 2, ISOLATED. count = 2 with length = 1 and a full 164-byte payload, so
    ///         guard 3 (calldatasize) is satisfied and cannot be what fires.
    function test__unit__lengthCountMismatchReverts() public {
        uint256[] memory words = new uint256[](2);
        words[0] = _validWord();
        words[1] = packInput(999, 7, 3);

        bytes memory cd = encodeBatchRaw(2, 0x40, 1, words);
        assertEq(cd.length, 164, "guard 3 is satisfied: the payload is fully present");

        (bool ok,) = callBatch(cd);

        assertFalse(ok, "guard 2: array length must agree with count");
        assertEq(mgr.orderCount(), 0, "guard 2: orderCount unchanged");
        assertEq(uint256(vm.load(address(mgr), orderSlot(1))), 0, "guard 2: no slot written");
    }

    /// @notice GUARD 3 -- READ THIS BEFORE CHANGING IT.
    ///
    ///         THIS MUTANT IS INVISIBLE TO EVERY STATE ASSERTION. Deleting the calldatasize
    ///         guard does NOT corrupt state on a truncated payload: a calldataload past the
    ///         end returns ZERO-PADDED words, build_vol_order(0, 0, 0) fails validation, the
    ///         tuple is SKIPPED, and state stays clean. A state assertion would therefore stay
    ///         GREEN under the mutant and record a FAKE kill.
    ///
    ///         The ONLY discriminating assertion is the REVERT assertion below. The orderCount
    ///         assertion that follows it is completeness, NOT the kill site.
    function test__unit__truncatedCalldataReverts() public {
        uint256[] memory words = new uint256[](1);
        words[0] = _validWord();

        bytes memory cd = encodeBatch(words);
        assertEq(cd.length, 132, "precondition: the canonical N=1 payload is 132 bytes");
        bytes memory shortCd = truncate(cd, 32);
        assertEq(shortCd.length, 100, "the element word is gone; the head is intact");

        (bool ok,) = callBatch(shortCd);

        // THE KILL SITE. Do not replace this with a state check.
        assertFalse(ok, "guard 3: calldatasize must cover 100 + 32*count");
        assertEq(mgr.orderCount(), 0, "guard 3: completeness only -- NOT the kill site");
    }

    /// @notice MAX_BATCH (not one of MCAL-02's three calldata guards). 129 valid tuples must
    ///         revert BEFORE any sstore -- the bound is the only thing standing between a
    ///         caller-supplied count and an unbounded loop.
    function test__unit__overMaxBatchRevertsNoStateChange() public {
        uint256[] memory words = new uint256[](MAX_BATCH + 1);
        for (uint256 j = 0; j < words.length; j++) {
            words[j] = packInput(1000 + j, 100 + j, 50 + j);
        }

        (bool ok,) = callBatch(encodeBatch(words));

        assertFalse(ok, "count > MAX_BATCH must revert before any sstore");
        assertEq(mgr.orderCount(), 0, "over-MAX_BATCH: orderCount unchanged");
        assertEq(uint256(vm.load(address(mgr), orderSlot(1))), 0, "over-MAX_BATCH: no slot written");
    }

    /// @notice The other half of the behavioural pin: exactly 128 succeeds. Together with the
    ///         test above this pins MAX_BATCH == 128 as an OBSERVED boundary rather than a
    ///         restated constant.
    function test__unit__maxBatchExactlyOneTwoEightSucceeds() public {
        uint256[] memory words = new uint256[](MAX_BATCH);
        for (uint256 j = 0; j < MAX_BATCH; j++) {
            words[j] = packInput(1000 + j, 100 + j, 50 + j);
        }

        (bool ok, uint256 ret) = callBatch(encodeBatch(words));

        assertTrue(ok, "exactly MAX_BATCH must succeed");
        assertEq(ret, MAX_BATCH, "all 128 tuples stored");
        assertEq(mgr.orderCount(), MAX_BATCH, "orderCount == 128");
        assertEq(
            uint256(vm.load(address(mgr), orderSlot(1))),
            expectedPacked(1000, 100, 50),
            "first order at id 1"
        );
        assertEq(
            uint256(vm.load(address(mgr), orderSlot(64))),
            expectedPacked(1000 + 63, 100 + 63, 50 + 63),
            "midpoint order at id 64"
        );
        assertEq(
            uint256(vm.load(address(mgr), orderSlot(128))),
            expectedPacked(1000 + 127, 100 + 127, 50 + 127),
            "last order at id 128"
        );
    }
}

/// @title VolOrderManagerBatchEquivalenceTest
/// @notice MCAL-06 (SC-5). A batch of one is indistinguishable from a standalone create_order,
///         and N=0 is semantically empty rather than structurally impossible.
contract VolOrderManagerBatchEquivalenceTest is VolOrderManagerBatchBase {
    function test__unit__batchOfOneEqualsSingleCall() public {
        // A SECOND, independent instance driven through the SINGLE-CALL path.
        IVolOrderManager other =
            IVolOrderManager(deployPlank("src/modules/pos_spec/VolOrderManagerMod.plk"));
        other.create_order(STRIKE, WIDTH, SKEW);

        uint256[] memory words = new uint256[](1);
        words[0] = packInput(STRIKE, WIDTH, SKEW);
        (bool ok, uint256 ret) = callBatch(encodeBatch(words));
        assertTrue(ok, "a batch of one valid tuple succeeds");
        assertEq(ret, 1, "one success");

        uint256 batchWord = uint256(vm.load(address(mgr), orderSlot(1)));
        uint256 singleWord = uint256(vm.load(address(other), orderSlot(1)));

        assertEq(batchWord, singleWord, "batch-of-1 and create_order store the same word");
        // Equality alone would be satisfied by two zeros -- pin the VALUE too.
        assertEq(batchWord, expectedPacked(STRIKE, WIDTH, SKEW), "and it is the real tuple");
        assertEq(mgr.orderCount(), 1, "batch path: id 1");
        assertEq(other.orderCount(), 1, "single-call path: id 1");
    }

    /// @notice N = 0 completes without reverting and leaves every observable slot
    ///         byte-identical. HONEST NUANCE, recorded rather than glossed: the module writes
    ///         orderCount back UNCONDITIONALLY after the loop, so at N=0 it re-writes the
    ///         identical prior value. Observable state is therefore byte-identical, which is
    ///         exactly what SC-5 asserts. The SEEDED half below is what proves the write-back
    ///         is value-PRESERVING rather than zeroing -- a bug that a fresh-registry-only test
    ///         could never see, because 0 written over 0 is invisible.
    function test__unit__emptyBatchIsNoOp() public {
        bytes memory cd = encodeBatch(new uint256[](0));
        assertEq(cd.length, 100, "N=0 is exactly the 100-byte head");

        (bool ok, uint256 ret) = callBatch(cd);
        assertTrue(ok, "N=0 is semantically empty, not structurally impossible -- it must not revert");
        assertEq(ret, 0, "N=0 returns a success count of zero");
        assertEq(mgr.orderCount(), 0, "N=0 touches no state");
        assertEq(uint256(vm.load(address(mgr), SLOT_ORDER_COUNT)), 0, "raw counter slot untouched");
        assertEq(uint256(vm.load(address(mgr), orderSlot(1))), 0, "no order slot written");

        // The SEEDED half: the unconditional write-back must PRESERVE the prior value.
        vm.store(address(mgr), SLOT_ORDER_COUNT, bytes32(uint256(5)));
        (bool ok2, uint256 ret2) = callBatch(cd);
        assertTrue(ok2, "N=0 from a seeded counter also succeeds");
        assertEq(ret2, 0, "still zero successes");
        assertEq(mgr.orderCount(), 5, "the trailing write-back preserves C rather than zeroing it");
    }
}

/// @title VolOrderManagerBatchTotalityTest
/// @notice MCAL-04 (SC-4). CORROBORATION ONLY. The PRIMARY containment argument is the
///         six-step structural enumeration written into VolOrderManagerMod.plk immediately
///         above the create_orders branch. What this fuzz records is "no batch-revert OBSERVED
///         over 256 runs" -- never "proven for all 2^256 values".
contract VolOrderManagerBatchTotalityTest is VolOrderManagerBatchBase {
    /// @notice Corpus is CONSTRUCTED with `bound` -- assumption-based filtering appears nowhere
    ///         in this file. Every shape is a NAMED rejection reason or a valid draw, so `expectedOk`
    ///         is computed test-side and never read back from the module.
    ///         Non-fuzz anchor: test__unit__mixedBatchFootprintAndContiguity.
    /// forge-config: default.fuzz.runs = 256
    function test__fuzz__batchNeverReverts(uint256 nSeed, uint256 shapeSeed, uint256 valSeed)
        public
    {
        uint256 n = bound(nSeed, 1, 16);
        uint256[] memory words = new uint256[](n);
        uint256 expectedOk = 0;

        for (uint256 j = 0; j < n; j++) {
            uint256 shape = bound(uint256(keccak256(abi.encode(shapeSeed, j))), 0, 5);
            uint256 r = uint256(keccak256(abi.encode(valSeed, j)));

            uint256 strike = bound(r, 1, uint256(type(uint88).max));
            uint256 width = bound(uint256(keccak256(abi.encode(r, "w"))), 1, uint256(type(uint24).max));
            uint256 skew = bound(uint256(keccak256(abi.encode(r, "k"))), 1, 65534);

            if (shape == 0) {
                words[j] = packInput(strike, width, skew); // VALID
                expectedOk++;
            } else if (shape == 1) {
                words[j] = packInput(strike, width, 0); // rejected skew endpoint
            } else if (shape == 2) {
                words[j] = packInput(strike, width, 65535); // the other rejected skew endpoint
            } else if (shape == 3) {
                words[j] = packInput(0, width, skew); // strike_fits_packed lower bound
            } else if (shape == 4) {
                words[j] = packInput(strike, 0, skew); // vol_range_width_is_complete lower bound
            } else {
                words[j] = packInput(strike, width, skew) | (uint256(1) << 200); // dirty high bits
            }
        }

        (bool ok, uint256 ret) = callBatch(encodeBatch(words));

        assertTrue(ok, "MCAL-04: no batch-revert observed");
        assertEq(ret, expectedOk, "the success count equals the constructed valid count");
        assertEq(mgr.orderCount(), expectedOk, "orderCount advances by the constructed valid count");
    }
}
