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

/// @dev The Solidity mirror of the module's hand-rolled return element. As a struct with fields
///      (bool, uint256), `abi.encode(BatchResult[])` emits EXACTLY the layout the module
///      hand-rolls: outer offset 0x20, length in ELEMENTS, then static tuples inlined at stride
///      0x40 with no per-element offsets. That is what makes solc usable as an INDEPENDENT oracle.
struct BatchResult {
    bool success;
    uint256 orderId;
}

abstract contract VolOrderManagerBatchBase is VolOrderManagerBase {
    bytes4 internal constant SEL_CREATE_ORDERS = bytes4(0x81357911);

    /// @dev Restated from the module. Pinned BEHAVIOURALLY by the 128-succeeds / 129-reverts
    ///      pair below, which is stronger than restating a constant.
    uint256 internal constant MAX_BATCH = 128;

    /// @dev The V2 INPUT word layout: skew at bits 0..15, strike at 16..103, width at
    ///      104..127, targetVega at 128..223; bits 224..255 MUST be zero. DISTINCT from expectedPacked(), which is the STORED
    ///      layout (width at 128, tickSpacing at 104, strike at 16, skew at 0). Only `width`
    ///      moves between the two, because build_vol_order inserts TICK_SPACING = 20 at bits
    ///      104..127 on the way to pack_vol_order.
    function packInput(uint256 strike, uint256 width, uint256 skew) internal pure returns (uint256) {
        // V2 input word: skew at 0, strike at 16, width at 104, targetVega at 128..223.
        // The anchor TARGET_VEGA is embedded so every constructed word carries a valid vega;
        // dirty-bit tests OR bits >= 224 (the region ABOVE the top field).
        return skew | (strike << 16) | (width << 104) | (uint256(TARGET_VEGA) << 128);
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
    ///
    ///      PHASE 18b: the signature is deliberately UNCHANGED. `ret` still means "how many
    ///      tuples succeeded", so every 18a assertion is preserved verbatim while now being
    ///      routed through the typed encoder. The 18a assertions therefore got STRICTLY
    ///      STRONGER for free -- they previously read one raw word, and now they only hold if
    ///      abi.decode accepts the hand-rolled bytes. Tests that need the RAW bytes use
    ///      callBatchRaw below.
    function callBatch(bytes memory cd) internal returns (bool ok, uint256 ret) {
        bytes memory r;
        (ok, r) = address(mgr).call(cd);
        if (ok) {
            BatchResult[] memory rs = abi.decode(r, (BatchResult[]));
            for (uint256 j = 0; j < rs.length; j++) {
                if (rs[j].success) ret++;
            }
        }
    }

    /// @dev Raw returndata, undecoded. The byte-level differential and every returndatasize
    ///      assertion go through THIS -- decoding first would discard exactly the evidence those
    ///      tests exist to produce.
    function callBatchRaw(bytes memory cd) internal returns (bool ok, bytes memory ret) {
        (ok, ret) = address(mgr).call(cd);
    }

    /// @dev THE ORACLE SIDE. Deliberately the STANDARD encoder and nothing else: no manual word
    ///      writes, no mirroring of the module's arithmetic. If this function ever grows an
    ///      mstore or a hand-computed offset, the differential becomes VACUOUS -- it would then be
    ///      comparing the module against a restatement of the module. solc is the independent
    ///      oracle precisely because it was written by someone else.
    function expectedReturn(BatchResult[] memory rs) internal pure returns (bytes memory) {
        return abi.encode(rs);
    }

    /// @dev Builds a BatchResult[] from parallel arrays, so a test states its expectation as data.
    function results(bool[] memory oks, uint256[] memory ids)
        internal
        pure
        returns (BatchResult[] memory rs)
    {
        require(oks.length == ids.length, "test bug: ragged expectation");
        rs = new BatchResult[](oks.length);
        for (uint256 j = 0; j < oks.length; j++) {
            rs[j] = BatchResult({success: oks[j], orderId: ids[j]});
        }
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
        assertEq(
            uint256(vm.load(address(mgr), orderSlot(6))),
            expectedPacked(STRIKE, WIDTH, SKEW),
            "valid_A at C+1"
        );
        // <- THE LOAD-BEARING ASSERTION (M5 kill site). ORDERED DELIBERATELY BEFORE THE
        //    orderCount CHECK BELOW: forge reports only the FIRST failing assertion in a test,
        //    and under the M5 counter-hoist mutant BOTH redden. If the count assertion came
        //    first it would mask this one, and the mutation record would read as a count-only
        //    kill -- which is exactly the non-discriminating evidence this corpus exists to
        //    avoid, since a count red alone does not pin WHERE the misplaced order landed.
        assertEq(
            uint256(vm.load(address(mgr), orderSlot(7))),
            expectedPacked(999, 7, 3),
            "id contiguity: third valid order at C+2"
        );
        assertEq(uint256(vm.load(address(mgr), orderSlot(8))), 0, "no order beyond orderCount");
        assertEq(mgr.orderCount(), 7, "orderCount advances by the success count, not by N");
    }

    /// @notice Dirty high bits are a SKIP, not a revert. `width` is read UNMASKED, so any bit
    ///         >= 128 inflates it past 0xffffff and vol_range_width_is_complete rejects it.
    ///         This is the module's whole-word-read stance (dirty bits rejected by VALIDATION,
    ///         never truncated) applied to the batch, and it costs zero new arithmetic.
    function test__unit__dirtyHighBitsAreSkippedNotStored() public {
        uint256[] memory words = new uint256[](1);
        words[0] = packInput(STRIKE, WIDTH, SKEW) | (uint256(1) << 240);

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
        other.create_order(STRIKE, WIDTH, SKEW, TARGET_VEGA);

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

/// @title VolOrderManagerBatchGasTest
/// @notice MCAL-01 (SC-3). The N = MAX_BATCH cost is MEASURED, PRINTED and asserted against a
///         hard 10,000,000 gas ceiling.
///
///         WHY 10M AND NOT THE BLOCK LIMIT. MCAL-01 says "measured N = MAX_BATCH cost
///         <= 10,000,000 gas", explicitly NOT "under the block limit". A transaction that
///         consumes an entire block is not reliably includable -- builders deprioritise it and
///         it competes with nothing else in the block -- so a 30M ceiling would certify a
///         batch nobody can actually land. 10M leaves the tx comfortably includable.
///
///         The research's ~2.94M estimate is UNVERIFIED and sat beside fabricated citations.
///         It is NOT carried forward as fact; it is used only as an order-of-magnitude sanity
///         reference against the number measured below.
contract VolOrderManagerBatchGasTest is VolOrderManagerBatchBase {
    function test__unit__maxBatchGasUnderBudget() public {
        uint256[] memory words = new uint256[](MAX_BATCH);
        for (uint256 j = 0; j < MAX_BATCH; j++) {
            // Distinct tuples so every SSTORE is a cold zero->nonzero write -- the honest worst
            // case. Identical tuples would still hit distinct slots (ids differ), but distinct
            // values also rule out any accidental value-dependent short-circuit.
            words[j] = packInput(1000 + j, 100 + j, 50 + j);
        }
        bytes memory cd = encodeBatch(words);

        uint256 g0 = gasleft();
        (bool ok, bytes memory r) = address(mgr).call(cd);
        uint256 execGas = g0 - gasleft();

        // A GAS NUMBER FOR A REVERTED CALL IS MEANINGLESS. Prove the work actually happened
        // FIRST -- this is what stops a passing gas assertion from silently certifying an early
        // revert. All four assertions below precede the threshold check deliberately.
        assertTrue(ok, "the N=128 batch must SUCCEED for its gas number to mean anything");
        // PHASE 18b: the return is no longer one word. `abi.decode(r, (uint256))` would now
        // silently decode the OUTER OFFSET WORD and yield 32, certifying nothing.
        BatchResult[] memory rs = abi.decode(r, (BatchResult[]));
        assertEq(rs.length, MAX_BATCH, "all 128 results returned");
        assertEq(r.length, 64 + 64 * MAX_BATCH, "N=128 returns exactly 8256 bytes");
        assertEq(mgr.orderCount(), MAX_BATCH, "orderCount advanced by 128");
        assertEq(
            uint256(vm.load(address(mgr), orderSlot(MAX_BATCH))),
            expectedPacked(1000 + 127, 100 + 127, 50 + 127),
            "the 128th order really landed"
        );

        // MCAL-01's threshold is about what a REAL TRANSACTION costs, so the intrinsic cost that
        // a `.call` does not incur is added back explicitly rather than quietly omitted:
        //   21,000 base + EIP-2028 calldata (16 gas per nonzero byte, 4 per zero byte).
        uint256 calldataGas = 0;
        for (uint256 j = 0; j < cd.length; j++) {
            calldataGas += (cd[j] == 0 ? 4 : 16);
        }
        uint256 totalGas = execGas + 21_000 + calldataGas;

        emit log_named_uint("MCAL-01 execGas   (N=128)", execGas);
        emit log_named_uint("MCAL-01 calldataGas", calldataGas);
        emit log_named_uint("MCAL-01 TOTAL     (N=128)", totalGas);

        assertLe(totalGas, 10_000_000, "MCAL-01: N=MAX_BATCH must cost <= 10,000,000 gas");
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
                words[j] = packInput(strike, width, skew) | (uint256(1) << 240); // dirty high bits (>= 224, above targetVega)
            }
        }

        (bool ok, uint256 ret) = callBatch(encodeBatch(words));

        assertTrue(ok, "MCAL-04: no batch-revert observed");
        assertEq(ret, expectedOk, "the success count equals the constructed valid count");
        assertEq(mgr.orderCount(), expectedOk, "orderCount advances by the constructed valid count");
    }
}

/// @title VolOrderManagerReturnEncodingTest
/// @notice MCAL-05 (SC-1..SC-4) + MCAL-06's carried return-bytes clause. The hand-rolled
///         (bool,uint256)[] encoder, compared BYTE FOR BYTE against solc's standard abi.encode.
///
///         WHY BYTES AND NOT DECODED VALUES. A decoded comparison compares SEMANTICS and leaves
///         the encoder unconstrained: a consistent head or stride error can round-trip through
///         abi.decode and never surface. Byte equality makes solc an independent oracle for the
///         one surface in this milestone with zero in-repo precedent. The expected side is built
///         ONLY with abi.encode -- never by mirroring the module's manual writes, which would make
///         the whole differential vacuous.
///
///         ASSERTION ORDER IS MUTATION-EVIDENCE DESIGN (18a-01 FINDING): forge reports only the
///         FIRST failing assertion per test, so the keccak byte-equality assertion comes FIRST
///         among the discriminating assertions in every test below. Length and word-level reads
///         follow as LOCALISATION AIDS, not as the kill site.
contract VolOrderManagerReturnEncodingTest is VolOrderManagerBatchBase {
    /// @notice PIN THE ORACLE BEFORE PINNING THE MODULE, mirroring VolOrderManagerBatchEncodingTest's
    ///         discipline for the input half. This proves the <pinned_byte_layout> IS what solc
    ///         emits, independently of anything the module does -- so an oracle bug can never be
    ///         mistaken for a module bug and burn the mutation evidence.
    function test__unit__returnBuildersMatchTheStandardEncoder() public pure {
        assertEq(abi.encode(new BatchResult[](0)).length, 64, "N=0 encodes to exactly 64 bytes");

        bool[] memory oks1 = new bool[](1);
        uint256[] memory ids1 = new uint256[](1);
        oks1[0] = true;
        ids1[0] = 6;
        assertEq(abi.encode(results(oks1, ids1)).length, 128, "N=1 encodes to exactly 128 bytes");

        bool[] memory oks = new bool[](2);
        uint256[] memory ids = new uint256[](2);
        oks[0] = true;
        ids[0] = 6;
        oks[1] = false;
        ids[1] = 0;
        bytes memory enc = abi.encode(results(oks, ids));

        assertEq(enc.length, 192, "N=2 encodes to exactly 192 bytes");
        assertEq(wordAt(enc, 0), 0x20, "the outer offset word is 0x20");
        assertEq(wordAt(enc, 32), 2, "the length word counts ELEMENTS, not bytes");
        assertEq(wordAt(enc, 64), 1, "success[0] is a canonical 1");
        assertEq(wordAt(enc, 96), 6, "orderId[0] -- head 0x40, so element 0 starts at byte 64");
        assertEq(wordAt(enc, 128), 0, "success[1] -- stride 0x40, no per-element offsets");
        assertEq(wordAt(enc, 160), 0, "orderId[1]");
    }

    /// @notice THE N=0 EDGE. It gets its own named test because its failure mode is INVISIBLE
    ///         on-chain: a 0- or 32-byte return does not revert here, it reverts in the Haskell
    ///         client's abi.decode. Governing principle: structurally impossible -> revert;
    ///         semantically empty -> well-formed empty result. A zero-arrival Poisson tick is an
    ///         in-distribution sample, not a client error.
    ///
    ///         This test is what discharges MCAL-06's carried "exactly 64 bytes: offset 0x20,
    ///         length 0" clause, which 18a's one-word return structurally could not satisfy.
    function test__unit__emptyReturnIsExactlySixtyFourBytes() public {
        (bool ok, bytes memory ret) = callBatchRaw(encodeBatch(new uint256[](0)));

        assertTrue(ok, "N=0 is semantically empty, not structurally impossible -- it must not revert");
        assertEq(
            keccak256(ret),
            keccak256(expectedReturn(new BatchResult[](0))),
            "N=0 bytes must equal abi.encode of an empty BatchResult[]"
        );
        assertEq(ret.length, 64, "N=0 returns EXACTLY 64 bytes -- not 0, not 32");
        assertEq(wordAt(ret, 0), 0x20, "N=0: outer offset word");
        assertEq(wordAt(ret, 32), 0, "N=0: length word is zero ELEMENTS");

        // THE CONSUMER-SIDE CHECK. This is the failure that lands in the Haskell client rather
        // than here: a 0- or 32-byte return decodes to a revert, not to an empty list.
        BatchResult[] memory decoded = abi.decode(ret, (BatchResult[]));
        assertEq(decoded.length, 0, "abi.decode succeeds and yields an empty array");

        // And from a SEEDED counter, so "N=0 works" cannot hide behind a fresh registry.
        vm.store(address(mgr), SLOT_ORDER_COUNT, bytes32(uint256(5)));
        (bool ok2, bytes memory ret2) = callBatchRaw(encodeBatch(new uint256[](0)));
        assertTrue(ok2, "N=0 from a seeded counter also succeeds");
        assertEq(keccak256(ret2), keccak256(ret), "the seeded counter does not change the N=0 bytes");
    }

    /// @notice The two SMALLEST non-empty totals, asserted against the MODULE rather than only
    ///         against the oracle. Without this, N=1 and N=2 were pinned only inside
    ///         test__unit__returnBuildersMatchTheStandardEncoder -- which pins solc, not the
    ///         encoder. N=1 is also the only N at which the stride is unobservable (i=0 makes
    ///         `64 + stride*i` independent of the stride), so it is recorded here as the boundary
    ///         BELOW which the M3 stride mutant is blind.
    function test__unit__oneAndTwoElementReturnsAreByteExact() public {
        vm.store(address(mgr), SLOT_ORDER_COUNT, bytes32(uint256(5)));

        uint256[] memory one = new uint256[](1);
        one[0] = packInput(STRIKE, WIDTH, SKEW);

        bool[] memory oks1 = new bool[](1);
        uint256[] memory ids1 = new uint256[](1);
        oks1[0] = true;
        ids1[0] = 6;

        (bool ok1, bytes memory ret1) = callBatchRaw(encodeBatch(one));
        assertTrue(ok1, "N=1 succeeds");
        assertEq(
            keccak256(ret1), keccak256(expectedReturn(results(oks1, ids1))), "N=1: byte-exact"
        );
        assertEq(ret1.length, 128, "N=1 returns exactly 128 bytes");

        uint256[] memory two = new uint256[](2);
        two[0] = packInput(999, 7, 3);
        two[1] = packInput(1234, 56, 78);

        bool[] memory oks2 = new bool[](2);
        uint256[] memory ids2 = new uint256[](2);
        oks2[0] = true;
        ids2[0] = 7;
        oks2[1] = true;
        ids2[1] = 8;

        (bool ok2, bytes memory ret2) = callBatchRaw(encodeBatch(two));
        assertTrue(ok2, "N=2 succeeds");
        assertEq(
            keccak256(ret2), keccak256(expectedReturn(results(oks2, ids2))), "N=2: byte-exact"
        );
        assertEq(ret2.length, 192, "N=2 returns exactly 192 bytes");
    }

    /// @notice THE FLAGSHIP, and the named NON-FUZZ ANCHOR for
    ///         test__fuzz__returnBytesMatchStandardEncoder.
    ///
    ///         ONE keccak assertion covers THREE properties simultaneously: positional alignment
    ///         (the failure sits strictly in the MIDDLE, so a shifted successor is visible), the
    ///         (false, 0) failure shape, and the 0x40 stride. Reuses 18a's mixed corpus: skew
    ///         65535 is one of only TWO rejected skews, so EXACTLY ONE conjunct fails and the
    ///         failure is named rather than incidental. The counter is SEEDED to C=5 so a
    ///         "results always start at id 1" bug cannot hide behind a fresh registry.
    function test__unit__mixedBatchReturnIsByteExact() public {
        vm.store(address(mgr), SLOT_ORDER_COUNT, bytes32(uint256(5)));

        uint256[] memory words = new uint256[](3);
        words[0] = packInput(STRIKE, WIDTH, SKEW);
        words[1] = packInput(STRIKE, WIDTH, 65535);
        words[2] = packInput(999, 7, 3);

        bool[] memory oks = new bool[](3);
        uint256[] memory ids = new uint256[](3);
        oks[0] = true;
        ids[0] = 6;
        oks[1] = false;
        ids[1] = 0;
        oks[2] = true;
        ids[2] = 7;

        (bool ok, bytes memory ret) = callBatchRaw(encodeBatch(words));

        assertTrue(ok, "a mixed batch never reverts");
        // THE KILL SITE. First among the discriminating assertions, deliberately.
        assertEq(
            keccak256(ret),
            keccak256(expectedReturn(results(oks, ids))),
            "N=3 mixed: returndata must be byte-exact"
        );
        assertEq(ret.length, 256, "N=3 returns exactly 256 bytes");

        // Localisation aids only -- everything below is already implied by the keccak above.
        assertEq(wordAt(ret, 0), 0x20, "outer offset");
        assertEq(wordAt(ret, 32), 3, "length in elements");
        assertEq(wordAt(ret, 64), 1, "success[0]");
        assertEq(wordAt(ret, 96), 6, "orderId[0] == C+1");
        assertEq(wordAt(ret, 128), 0, "success[1] -- the skipped tuple");
        assertEq(wordAt(ret, 160), 0, "orderId[1] is 0, NOT the running counter");
        assertEq(wordAt(ret, 192), 1, "success[2]");
        assertEq(wordAt(ret, 224), 7, "orderId[2] == C+2 -- the failure did not shift it");
    }

    /// @notice Guards against an encoder that only writes the SUCCESS path and leaves failures as
    ///         unwritten -- and therefore accidentally-correct -- zeros from malloc_zeroed. This
    ///         is the kill site for the M5 (false, id) mutant's all-invalid half.
    function test__unit__allInvalidBatchReturnsAllFalseZero() public {
        uint256[] memory words = new uint256[](3);
        words[0] = packInput(STRIKE, WIDTH, 0); // rejected skew endpoint
        words[1] = packInput(STRIKE, WIDTH, 65535); // the other rejected skew endpoint
        words[2] = packInput(0, WIDTH, SKEW); // strike_fits_packed lower bound

        (bool ok, bytes memory ret) = callBatchRaw(encodeBatch(words));

        assertTrue(ok, "an all-invalid batch never reverts");
        assertEq(
            keccak256(ret),
            keccak256(expectedReturn(new BatchResult[](3))),
            "three failures encode as three (false, 0) tuples"
        );
        assertEq(ret.length, 256, "N=3 returns exactly 256 bytes regardless of outcome");
        assertEq(mgr.orderCount(), 0, "no tuple was stored");
    }

    /// @notice CANONICAL BOOLS, read as RAW WORDS. This must NOT go through `bool`: decoding to
    ///         bool is exactly what would hide a non-canonical word, and solc's decoder REVERTING
    ///         on it is a DIFFERENT failure than the one being pinned here. A lenient Haskell
    ///         decoder would accept a truthy 2 while abi.decode rejects it -- the two consumers
    ///         would then disagree about the same bytes. That divergence IS the requirement.
    function test__unit__successWordsAreCanonicallyZeroOrOne() public {
        uint256[] memory words = new uint256[](3);
        words[0] = packInput(STRIKE, WIDTH, SKEW);
        words[1] = packInput(STRIKE, WIDTH, 65535);
        words[2] = packInput(999, 7, 3);

        (bool ok, bytes memory ret) = callBatchRaw(encodeBatch(words));
        assertTrue(ok, "the mixed batch succeeds");

        for (uint256 j = 0; j < 3; j++) {
            uint256 w = wordAt(ret, 64 + 64 * j);
            assertTrue(w < 2, "success word must be canonically 0 or 1, never a truthy nonzero");
        }
    }

    /// @notice THE ALLOCATION-ORDERING PROBE, at N = MAX_BATCH = 128 where array_slot performs 128
    ///         interleaved malloc_uninit(32) calls against an 8256-byte results buffer. If the
    ///         results buffer were sized or ordered wrongly, those per-iteration scratch
    ///         allocations would alias the region this branch writes.
    ///
    ///         The storage assertion at the end is what DISTINGUISHES "the results were corrupted"
    ///         from "the slot derivation was corrupted" -- both are informative and they are
    ///         different bugs.
    function test__unit__maxBatchReturnIsByteExactAndUncorrupted() public {
        uint256[] memory words = new uint256[](MAX_BATCH);
        bool[] memory oks = new bool[](MAX_BATCH);
        uint256[] memory ids = new uint256[](MAX_BATCH);
        for (uint256 j = 0; j < MAX_BATCH; j++) {
            words[j] = packInput(1000 + j, 100 + j, 50 + j);
            oks[j] = true;
            ids[j] = j + 1;
        }

        (bool ok, bytes memory ret) = callBatchRaw(encodeBatch(words));

        assertTrue(ok, "the N=128 batch succeeds");
        assertEq(
            keccak256(ret),
            keccak256(expectedReturn(results(oks, ids))),
            "N=128: returndata must be byte-exact"
        );
        assertEq(ret.length, 64 + 64 * MAX_BATCH, "N=128 returns exactly 8256 bytes");

        // The two words a mid-loop allocation is most likely to step on.
        assertEq(wordAt(ret, 64 + 64 * 127 + 32), 128, "the LAST orderId is uncorrupted");
        assertEq(wordAt(ret, 32), MAX_BATCH, "the length word is uncorrupted");

        // Storage corruption vs return corruption, distinguished.
        assertEq(
            uint256(vm.load(address(mgr), orderSlot(128))),
            expectedPacked(1127, 227, 177),
            "the 128th order really landed, so the slot derivation is uncorrupted too"
        );
    }

    /// @notice Corpus CONSTRUCTED with `bound`; assumption-based filtering appears nowhere in
    ///         this file, so no draw is ever discarded and no run is ever silently empty. N=0 is
    ///         INCLUDED in the draw range so the empty encoding is covered by the fuzz too. The
    ///         expectation is computed TEST-SIDE from the constructed shapes and is NEVER read
    ///         back from the module, which is what keeps the differential non-vacuous.
    ///         Non-fuzz anchor: test__unit__mixedBatchReturnIsByteExact.
    /// forge-config: default.fuzz.runs = 256
    function test__fuzz__returnBytesMatchStandardEncoder(
        uint256 nSeed,
        uint256 seedSeed,
        uint256 shapeSeed,
        uint256 valSeed
    ) public {
        uint256 n = bound(nSeed, 0, 16); // 0 INCLUDED -- N=0 must be in the corpus
        uint256 c = bound(seedSeed, 0, 1000);
        vm.store(address(mgr), SLOT_ORDER_COUNT, bytes32(c));

        uint256[] memory words = new uint256[](n);
        BatchResult[] memory expected = new BatchResult[](n);
        uint256 nextId = c;

        for (uint256 j = 0; j < n; j++) {
            uint256 shape = bound(uint256(keccak256(abi.encode(shapeSeed, j))), 0, 3);
            uint256 r = uint256(keccak256(abi.encode(valSeed, j)));

            uint256 strike = bound(r, 1, uint256(type(uint88).max));
            uint256 width = bound(uint256(keccak256(abi.encode(r, "w"))), 1, uint256(type(uint24).max));
            uint256 skew = bound(uint256(keccak256(abi.encode(r, "k"))), 1, 65534);

            if (shape == 0) {
                words[j] = packInput(strike, width, skew); // VALID
                nextId++;
                expected[j] = BatchResult({success: true, orderId: nextId});
            } else if (shape == 1) {
                words[j] = packInput(strike, width, 0); // rejected skew endpoint
                expected[j] = BatchResult({success: false, orderId: 0});
            } else if (shape == 2) {
                words[j] = packInput(strike, width, 65535); // the other rejected skew endpoint
                expected[j] = BatchResult({success: false, orderId: 0});
            } else {
                words[j] = packInput(strike, width, skew) | (uint256(1) << 240); // dirty high bits (>= 224, above targetVega)
                expected[j] = BatchResult({success: false, orderId: 0});
            }
        }

        (bool ok, bytes memory ret) = callBatchRaw(encodeBatch(words));

        assertTrue(ok, "the batch never reverts");
        assertEq(keccak256(ret), keccak256(expectedReturn(expected)), "returndata must be byte-exact");
        assertEq(ret.length, 64 + 64 * n, "total is exactly 64 + 64N");
    }
}
