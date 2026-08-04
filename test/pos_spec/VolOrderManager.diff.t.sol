// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BatchResult, VolOrderManagerBatchBase} from "./VolOrderManagerBatch.t.sol";
import {VolOrderRefMock} from "../mocks/VolOrderRefMock.sol";
import {VolOrderDecoder} from "./VolOrderDecoder.sol";

// ===========================================================================================
// THE AFTER-EVERY-WRITE SEQUENCE DIFFERENTIAL (MVER-01). Phase 19.
//
// THIS FILE BUILDS NOTHING. Not one line of src/ is created, modified or "adjusted" by it.
// It runs the SAME interleaved (create_order | create_orders) sequence into two places -- the
// FFI-deployed bytecode of src/modules/pos_spec/VolOrderManagerMod.plk, and an INDEPENDENT
// Solidity reference registry (test/mocks/VolOrderRefMock.sol) -- and asserts they agree at
// tolerance 0 after EVERY write.
//
// A RED HERE IS A FINDING ABOUT THE MODULE, NEVER A LICENCE TO EDIT IT. If the module and the
// mock disagree, the disagreement IS the deliverable: record the triggering inputs and stop.
// Weakening the mock to restore green would destroy exactly the evidence this file exists to
// produce. src/types/pos_spec/ is the vol-type track's and must never be touched at all.
//
// WHY THIS FILE EXISTS AT ALL, given 18a and 18b already passed. Both tested one call at a
// time, in isolation. Neither could test whether the STRICT path and the BATCH path agree
// about the SAME id counter across a mixed sequence -- an id-allocation disagreement between
// the two entrypoints is precisely the class of bug that survives every existing test. Step 3
// of the anchor sequence is that test and it exists nowhere else in the suite.
//
// INDEPENDENCE OF THE ORACLE. The mock reimplements the SPECIFICATION (the accept set, the
// id rule, the stored layout, the input read semantics) from the .plk sources; it contains no
// assembly block and calls no encoder. The expected RETURN BYTES are produced by solc's
// standard abi.encode applied to the MOCK's results -- never to the module's own results, and
// never assembled by mirroring the module's mstores. A mock that echoed the module's manual
// writes would compare the module against a restatement of itself.
//
// DISCIPLINE: no assumption-based input filtering anywhere (corpora are CONSTRUCTED with
// bound); every fuzz names a non-fuzz anchor; non-vacuity is ASSERTED via a live counter
// rather than assumed; the shared VolOrderDecoder is deliberately unguarded so no assertion
// downstream of it can go vacuous.
// ===========================================================================================

abstract contract VolOrderManagerDiffBase is VolOrderManagerBatchBase {
    VolOrderRefMock internal ref;

    /// @dev The test's OWN third opinion of the counter. Module == mock is satisfiable by two
    ///      equally-wrong values (two zeros, most obviously); pinning both against a value the
    ///      test computed itself is what rules that out.
    uint256 internal expectedCount;

    /// @dev The counter value both sides were SEEDED to. Ids at or below it were never written
    ///      by anybody -- see _assertSynced for why that distinction is load-bearing.
    uint256 internal seedBase;

    /// @dev THE NON-VACUITY COUNTER. Incremented once per _assertSynced call and once per
    ///      stored-word comparison, then asserted nonzero at the end of every test. Phase 18b
    ///      nearly shipped seven assertions that passed only because a guarded helper silently
    ///      yielded 0; a counter that must be strictly positive makes "the assertions never ran"
    ///      a FAILING outcome instead of a green one.
    uint256 internal syncChecks;

    function setUp() public virtual override {
        super.setUp();
        ref = new VolOrderRefMock();
    }

    /// @notice Seeds BOTH counters (and the test's own) to c, so "ids always start at 1" cannot
    ///         hide an id-allocation bug behind a fresh registry.
    function _seedBoth(uint256 c) internal {
        vm.store(address(mgr), SLOT_ORDER_COUNT, bytes32(c));
        ref.seedCount(c);
        expectedCount = c;
        seedBase = c;
    }

    /// @notice THE AFTER-EVERY-WRITE ASSERTION. Called after every single, every batch, and
    ///         every expected revert.
    ///
    ///         ON THE SEEDED REGION. Seeding sets the COUNTER, not the orders: ids in
    ///         [1, seedBase] hold nothing on either side. Their words must still AGREE -- and
    ///         must both be zero, which is itself worth asserting, since a seeding bug that
    ///         fabricated phantom orders would show up here and nowhere else. What does NOT
    ///         apply to them is the live-order shape (a nonzero word, tickSpacing pinned at 20),
    ///         because no order was ever written there. Applying it anyway would have made every
    ///         seeded test fail for a reason that says nothing about the module.
    function _assertSynced(string memory step) internal {
        uint256 pc = mgr.orderCount();
        uint256 rc = ref.orderCount();
        assertEq(pc, rc, string.concat(step, ": orderCount module vs mock, tol 0"));
        // Two zeros would satisfy equality alone -- pin the VALUE against the test's own third opinion.
        assertEq(pc, expectedCount, string.concat(step, ": orderCount vs test-side expectation"));
        syncChecks++;

        for (uint256 id = 1; id <= pc; id++) {
            uint256 pw = uint256(vm.load(address(mgr), orderSlot(id)));
            uint256 rw = ref.orders(id);
            assertEq(pw, rw, string.concat(step, ": stored word at id ", vm.toString(id)));

            VolOrderDecoder.Fields memory pf = VolOrderDecoder.decode(pw);
            VolOrderDecoder.Fields memory rf = VolOrderDecoder.decode(rw);
            // Field-by-field so a failure NAMES the wrong field rather than just "words differ".
            assertEq(pf.width, rf.width, string.concat(step, ": width@128"));
            assertEq(pf.tickSpacing, rf.tickSpacing, string.concat(step, ": tickSpacing@104"));
            assertEq(pf.strike, rf.strike, string.concat(step, ": strike@16"));
            assertEq(pf.skew, rf.skew, string.concat(step, ": skew@0"));
            assertEq(pf.targetVega, rf.targetVega, string.concat(step, ": targetVega at 152 (V2)"));

            if (id > seedBase) {
                // A LIVE order, written during this sequence.
                assertEq(pf.tickSpacing, TICK_SPACING, string.concat(step, ": tickSpacing is pinned at 20"));
                assertTrue(pw != 0, string.concat(step, ": a live order's word is never zero"));
            } else {
                // The SEEDED region: the counter was moved, no order was written.
                assertEq(pw, 0, string.concat(step, ": seeding fabricated no order at id ", vm.toString(id)));
            }
            syncChecks++;
        }

        // The slot one past the counter must be empty on BOTH sides.
        assertEq(
            uint256(vm.load(address(mgr), orderSlot(pc + 1))),
            0,
            string.concat(step, ": no order beyond orderCount")
        );
        assertEq(ref.orders(pc + 1), 0, string.concat(step, ": mock agrees nothing lies beyond orderCount"));
    }

    /// @notice One STRICT-path write into both sides, then the full sync assertion.
    function _singleBoth(uint88 s, uint24 w, uint16 k, string memory step) internal {
        mgr.create_order(s, w, k, TARGET_VEGA);
        ref.createOrder(s, w, k, TARGET_VEGA);
        expectedCount++;
        _assertSynced(step);
    }

    /// @notice A mid-sequence STRICT REVERT on both sides. expectedCount is UNCHANGED -- this is
    ///         what proves a revert mid-sequence leaves both registries synced rather than
    ///         half-written.
    function _singleExpectRevertBoth(uint88 s, uint24 w, uint16 k, string memory step) internal {
        vm.expectRevert();
        mgr.create_order(s, w, k, TARGET_VEGA);
        vm.expectRevert();
        ref.createOrder(s, w, k, TARGET_VEGA);
        _assertSynced(step);
    }

    /// @notice One BATCH into both sides: raw returndata from the module, a typed BatchResult[]
    ///         from the mock, and byte equality between them via solc's standard encoder.
    function _batchBoth(uint256[] memory words, string memory step) internal {
        (bool ok, bytes memory plankRet) = callBatchRaw(encodeBatch(words));
        assertTrue(ok, string.concat(step, ": the batch never reverts"));

        BatchResult[] memory refRs = ref.createOrders(words);

        // THE KILL SITE, FIRST among the discriminating assertions (18a-01 FINDING: forge reports
        // only the FIRST failing assertion per test, so assertion ORDER is mutation-evidence
        // design). The expected side is solc's STANDARD abi.encode applied to the MOCK's results --
        // never to the module's own results, and never assembled by mirroring the module's mstores.
        assertEq(
            keccak256(plankRet),
            keccak256(abi.encode(refRs)),
            string.concat(step, ": return bytes module vs abi.encode(mock results), tol 0")
        );
        assertEq(plankRet.length, 64 + 64 * words.length, string.concat(step, ": total is exactly 64 + 64N"));

        for (uint256 j = 0; j < refRs.length; j++) {
            if (refRs[j].success) expectedCount++;
        }
        _assertSynced(step);
    }
}

/// @title VolOrderManagerSequenceDiffTest
/// @notice MVER-01. The interleaved sequence differential and its constructed fuzz.
contract VolOrderManagerSequenceDiffTest is VolOrderManagerDiffBase {
    /// @notice PINS THE ORACLE BEFORE PINNING THE MODULE. Without this, a bug in the reference
    ///         mock would surface as a module failure and burn the mutation evidence -- the same
    ///         discipline test__unit__returnBuildersMatchTheStandardEncoder applies to the input
    ///         half. Every boundary here is a MEASURED accept-set endpoint (16-01), not a guess.
    function test__unit__refMockSelfPin() public view {
        assertTrue(ref.isValid(12345, 600, 77, TARGET_VEGA), "the non-degenerate anchor tuple is accepted");
        assertFalse(ref.isValid(12345, 600, 65535, TARGET_VEGA), "skew 65535 is rejected");
        assertFalse(ref.isValid(12345, 600, 0, TARGET_VEGA), "skew 0 is rejected");
        assertFalse(ref.isValid(0, 600, 77, TARGET_VEGA), "strike 0 is rejected");
        assertFalse(ref.isValid(12345, 0, 77, TARGET_VEGA), "width 0 is rejected");
        assertFalse(ref.isValid(2 ** 88, 600, 77, TARGET_VEGA), "strike 2**88 is above the packed bound");
        assertFalse(ref.isValid(12345, 0x1000000, 77, TARGET_VEGA), "width 0x1000000 is above the range bound");

        // The ACCEPTED endpoints -- 16-01 MEASURED that 1 and 65534 do NOT revert.
        assertTrue(ref.isValid(1, 1, 1, 1), "the lower corner is accepted");
        assertTrue(
            ref.isValid(0xFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFF, 65534, (1 << 96) - 1), "the upper corner is accepted"
        );

        // The mock's layout must equal the base's, independently derived.
        assertEq(
            ref.packed(12345, 600, 77, TARGET_VEGA), expectedPacked(12345, 600, 77), "stored layout agrees"
        );
    }

    /// @notice THE ANCHOR (MVER-01), and the named NON-FUZZ anchor for
    ///         test__fuzz__randomSequenceDiffers.
    ///
    ///         Sequence, counter SEEDED to 5 throughout:
    ///           0. _seedBoth(5)                 -- so "ids always start at 1" cannot hide
    ///           1. single (12345, 600, 77)      -- strict path; id 6
    ///           2. batch [valid, INVALID skew 65535, valid]
    ///                                           -- THE MIXED CORPUS. The failure sits strictly in
    ///                                              the MIDDLE so a shifted successor is visible.
    ///                                              ids 7 and 8; result[1] is exactly (false, 0).
    ///           3. single (4242, 31, 9)         -- THE INTERLEAVE, and THE POINT OF THIS PLAN.
    ///                                              The strict path must resume at id 9, i.e. it
    ///                                              must see the counter the BATCH advanced. 18a
    ///                                              and 18b could not test this; an id-allocation
    ///                                              disagreement between the two entrypoints
    ///                                              surfaces here and nowhere else.
    ///           4. single REVERT (12345, 600, 0)
    ///                                           -- mid-sequence strict revert (skew 0 is one of
    ///                                              only two rejected skews, so exactly one
    ///                                              conjunct fails). State stays synced at 9.
    ///           5. batch []                     -- N=0 mid-sequence: exactly 64 bytes, no state
    ///                                              touched, counter PRESERVED at 9.
    ///           6. batch [3 x INVALID]          -- all-invalid mid-sequence: three (false, 0)
    ///                                              tuples, counter still 9.
    ///           7. single (777, 4096, 65534)    -- boundary skew 65534 is ACCEPTED (16-01
    ///                                              MEASURED); id 10.
    ///           8. batch [lower corner, upper corner]
    ///                                           -- both accept-set CORNERS in one batch; ids 11
    ///                                              and 12.
    function test__unit__fixedAnchorSequenceDiffers() public {
        _seedBoth(5);
        _assertSynced("step 0 seeded");

        // 1. strict path; id 6
        _singleBoth(12345, 600, 77, "step 1 single");

        // 2. THE MIXED CORPUS -- ids 7 and 8, with (false, 0) strictly in the middle
        uint256[] memory mixed = new uint256[](3);
        mixed[0] = packInput(999, 7, 3);
        mixed[1] = packInput(12345, 600, 65535); // INVALID: skew endpoint
        mixed[2] = packInput(1234, 56, 78);
        _batchBoth(mixed, "step 2 mixed batch");

        // 3. THE INTERLEAVE -- the strict path must resume at id 9
        _singleBoth(4242, 31, 9, "step 3 interleave single");
        assertEq(mgr.orderCount(), 9, "step 3: the strict path saw the counter the BATCH advanced");

        // 4. mid-sequence strict revert; state stays synced at 9
        _singleExpectRevertBoth(12345, 600, 0, "step 4 strict revert");

        // 5. N=0 mid-sequence -- 64 bytes, counter preserved
        uint256[] memory empty = new uint256[](0);
        _batchBoth(empty, "step 5 empty batch");
        assertEq(mgr.orderCount(), 9, "step 5: an empty batch preserves the counter");

        // 6. all-invalid mid-sequence -- three (false, 0), counter still 9
        uint256[] memory allBad = new uint256[](3);
        allBad[0] = packInput(12345, 600, 0); // skew 0
        allBad[1] = packInput(12345, 600, 65535); // skew 65535
        allBad[2] = packInput(0, 600, 77); // strike 0
        _batchBoth(allBad, "step 6 all-invalid batch");
        assertEq(mgr.orderCount(), 9, "step 6: an all-invalid batch preserves the counter");

        // 7. the ACCEPTED skew boundary; id 10
        _singleBoth(777, 4096, 65534, "step 7 boundary skew single");

        // 8. both accept-set corners in one batch; ids 11 and 12
        uint256[] memory corners = new uint256[](2);
        corners[0] = packInput(1, 1, 1);
        corners[1] = packInput(0xFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFF, 65534);
        _batchBoth(corners, "step 8 corners batch");

        assertGt(syncChecks, 8, "corpus non-vacuous: the sync assertions were REACHED");
        assertEq(mgr.orderCount(), 12, "the anchor sequence ends at id 12");
        assertEq(expectedCount, 12, "and the test's own third opinion agrees");
    }

    /// @notice Corpus CONSTRUCTED with `bound` only -- assumption-based filtering appears nowhere
    ///         in this file. A rejection-sampling cheatcode exhausts the rejection budget and
    ///         converts a coverage hole into a green run; every draw here is a LIVE assertion
    ///         instead.
    ///         Non-fuzz anchor: test__unit__fixedAnchorSequenceDiffers.
    ///
    ///         WHY THE SEQUENCE IS SHORT (2-6 steps): deployPlank shells out to `plank build` over
    ///         FFI ONCE PER TEST, not per step, so 256 runs stay tractable while every run still
    ///         interleaves both entrypoints at least once by construction (step 0 is forced
    ///         single, step 1 is forced batch).
    ///
    /// forge-config: default.fuzz.runs = 256
    function test__fuzz__randomSequenceDiffers(uint256 seed, uint8 nRaw, uint16 seedCountRaw) public {
        _seedBoth(bound(uint256(seedCountRaw), 0, 1000));

        uint256 n = bound(uint256(nRaw), 2, 6);
        for (uint256 i = 0; i < n; i++) {
            // Steps 0 and 1 are FORCED to single / batch respectively, so every run interleaves
            // both entrypoints. Beyond that the kind is drawn.
            uint256 kind =
                i == 0 ? 0 : (i == 1 ? 1 : bound(uint256(keccak256(abi.encode(seed, i, "kind"))), 0, 2));

            if (kind == 0) {
                // A VALID single. Bounds are the MEASURED accept sets (16-01), so every draw stores.
                uint88 s = uint88(bound(uint256(keccak256(abi.encode(seed, i, "s"))), 1, uint256(type(uint88).max)));
                uint24 w = uint24(bound(uint256(keccak256(abi.encode(seed, i, "w"))), 1, uint256(type(uint24).max)));
                uint16 k = uint16(bound(uint256(keccak256(abi.encode(seed, i, "k"))), 1, 65534));
                _singleBoth(s, w, k, string.concat("fuzz step ", vm.toString(i), " single"));
            } else if (kind == 1) {
                // A MIXED batch. Shapes 0..3 exactly mirror the constructed shapes 18b used, so the
                // corpus covers valid, both rejected skew endpoints, and dirty high bits.
                uint256 m = bound(uint256(keccak256(abi.encode(seed, i, "m"))), 0, 8); // 0 INCLUDED: N=0 in-corpus
                uint256[] memory words = new uint256[](m);
                for (uint256 j = 0; j < m; j++) {
                    uint256 r = uint256(keccak256(abi.encode(seed, i, j)));
                    uint256 shape = bound(uint256(keccak256(abi.encode(r, "shape"))), 0, 3);
                    uint256 st = bound(r, 1, uint256(type(uint88).max));
                    uint256 wd = bound(uint256(keccak256(abi.encode(r, "w"))), 1, uint256(type(uint24).max));
                    uint256 sk = bound(uint256(keccak256(abi.encode(r, "k"))), 1, 65534);
                    if (shape == 0) {
                        words[j] = packInput(st, wd, sk); // VALID
                    } else if (shape == 1) {
                        words[j] = packInput(st, wd, 0); // rejected skew endpoint
                    } else if (shape == 2) {
                        words[j] = packInput(st, wd, 65535); // the other one
                    } else {
                        words[j] = packInput(st, wd, sk) | (uint256(1) << 240); // dirty high bits (>= 224, above targetVega)
                    }
                }
                _batchBoth(words, string.concat("fuzz step ", vm.toString(i), " batch"));
            } else {
                // A STRICT REVERT mid-sequence: state must stay synced across it.
                uint88 s = uint88(bound(uint256(keccak256(abi.encode(seed, i, "rs"))), 1, uint256(type(uint88).max)));
                uint24 w = uint24(bound(uint256(keccak256(abi.encode(seed, i, "rw"))), 1, uint256(type(uint24).max)));
                _singleExpectRevertBoth(s, w, 65535, string.concat("fuzz step ", vm.toString(i), " revert"));
            }
        }

        // Non-vacuity: the sync assertions were REACHED on this run. syncChecks counts one per
        // _assertSynced PLUS one per stored-word comparison, and every run performs at least the
        // two forced steps.
        assertGt(syncChecks, 2, "fuzz corpus non-vacuous: sync assertions reached");
        assertEq(mgr.orderCount(), ref.orderCount(), "final: module and mock agree");
        assertEq(mgr.orderCount(), expectedCount, "final: and the test's third opinion agrees");
    }
}
