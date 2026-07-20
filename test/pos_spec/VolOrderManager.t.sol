// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";

// ===========================================================================================
// THE VolOrderManagerMod MODULE surface (VORD-01/03/04/05). Everything that exercises the
// dispatch / id assignment / derived-slot storage / guard / reader behaviour of
// src/modules/pos_spec/VolOrderManagerMod.plk lives in THIS FILE.
//
// WHY A NEW FILE AND A NEW DIRECTORY. test/types/pos_spec/ is the vol-type track's TYPE
// surface and carries 4 pre-existing red tests (VolRangeWidthTest, SpreadTickAssimetryTest)
// that we must neither fix nor absorb. test/types/pos_spec/VolOrderValidation.t.sol is
// Phase 16's PURE LIB surface. This module is a third, categorically distinct surface, so it
// gets its own file under test/pos_spec/ -- one file per surface, --match-path targets stay
// disjoint, and a red in another track can never be confused for a red here.
//
// GLOBAL RULE: "it compiles" is never acceptance. `plank build` does NOT type-check code
// unreachable from run{}. deployPlank -> plankDeployFFI -> plankBuildFFI shells out to
// `plank build` over FFI AT TEST TIME, so every assertion below runs the DEPLOYED bytecode.
// Only a CALLED selector outcome proves a dispatch branch exists.
//
// DISCIPLINE: no vm.assume anywhere (corpora are CONSTRUCTED with bound); every fuzz has a
// named non-fuzz anchor; every guard is asserted ON STATE (a silent zero-write and a revert
// are indistinguishable from the return value); every raw slot address is recomputed
// test-side from the preimage string, never a hardcoded hash.
// ===========================================================================================

/// @notice Declared from the SAME signature strings pinned in
///         src/interfaces/pos_spec/VolOrderManagerInterface.plk. A mismatch means the test
///         never dispatches.
interface IVolOrderManager {
    function create_order(uint88 strike, uint24 width, uint16 skew) external;
    function orderCount() external view returns (uint256);
    function getOrderPacked(uint256 id) external view returns (uint256);
}

abstract contract VolOrderManagerBase is PlankTestBase {
    IVolOrderManager internal mgr;

    // Slot preimages RESTATED from the module -- never hardcoded hashes. A preimage mismatch
    // surfaces LOUDLY as vm.load reading 0 where a value was written.
    bytes32 internal constant SLOT_ORDER_COUNT = keccak256(bytes("VolOrderManagerMod.orderCount"));
    bytes32 internal constant SLOT_ORDERS_BASE = keccak256(bytes("VolOrderManagerMod.orders"));

    // Non-degenerate anchor tuple: every field distinct, none at a boundary, all inside the
    // MEASURED accept sets (strike [1,2^88-1], width [1,0xffffff], skew [1,65534]).
    uint88 internal constant STRIKE = 12345;
    uint24 internal constant WIDTH = 600;
    uint16 internal constant SKEW = 77;
    uint256 internal constant TICK_SPACING = 20; // pinned inside build_vol_order

    /// @dev The largest id whose derived slot does NOT overflow array_slot's CHECKED add.
    ///      MEASURED at 17-01: array_slot is `keccak256(base) + index` and Plank's `+` panics
    ///      (0x11) rather than wrapping, so the addressable id space is bounded above by
    ///      2^256-1 - keccak(base). Derived here, never hardcoded.
    uint256 internal constant MAX_SAFE_ID =
        type(uint256).max - uint256(keccak256(abi.encode(keccak256(bytes("VolOrderManagerMod.orders")))));

    function setUp() public virtual {
        mgr = IVolOrderManager(deployPlank("src/modules/pos_spec/VolOrderManagerMod.plk"));
    }

    /// @dev array_slot(base, id) == keccak256(base) + id, verbatim from v3::storage. NO mask.
    function orderSlot(uint256 id) internal pure returns (bytes32) {
        return bytes32(uint256(keccak256(abi.encode(SLOT_ORDERS_BASE))) + id);
    }

    /// @dev The layout under test: width@128 | tickSpacing@104 | strike@16 | skew@0.
    function expectedPacked(uint256 strike, uint256 width, uint256 skew)
        internal
        pure
        returns (uint256)
    {
        return (width << 128) | (TICK_SPACING << 104) | (strike << 16) | skew;
    }
}

/// @title VolOrderManagerStoreTest
/// @notice VORD-01 + VORD-04: create_order is CALLED through FFI-deployed bytecode, ids are
///         monotonic from 1, and the stored word is the exact submitted tuple observed by raw
///         vm.load -- never through a getter.
contract VolOrderManagerStoreTest is VolOrderManagerBase {
    /// @notice THE FLAGSHIP (SC-1 + SC-2 in ONE test). Proving the second order gets id 2 in
    ///         the same test that proved the first got id 1 is what rules out a ring mask
    ///         having been imported into the slot derivation.
    ///         Also the named NON-FUZZ ANCHOR for test__fuzz__validTupleStoresExactPackedWord.
    function test__unit__sequentialIdsOneThenTwo() public {
        assertEq(mgr.orderCount(), 0, "fresh registry");

        mgr.create_order(STRIKE, WIDTH, SKEW);
        assertEq(mgr.orderCount(), 1, "orderCount advances 0->1");

        // RAW read: the store is proven without trusting getOrderPacked.
        uint256 w1 = uint256(vm.load(address(mgr), orderSlot(1)));
        assertEq(w1, expectedPacked(STRIKE, WIDTH, SKEW), "id 1 stores the exact submitted tuple");

        // Field-by-field so a failure NAMES the wrong field rather than just "words differ".
        assertEq(w1 >> 128, WIDTH, "width@128");
        assertEq((w1 >> 104) & 0xFFFFFF, TICK_SPACING, "tickSpacing@104 == 20");
        assertEq((w1 >> 16) & 0xFFFFFFFFFFFFFFFFFFFFFF, STRIKE, "strike@16");
        assertEq(w1 & 0xFFFF, SKEW, "skew@0");
        assertTrue(w1 != 0, "a validly packed word is never zero");

        // Second, DISTINCT tuple -> id 2. Monotonic, no wraparound, no overwrite.
        mgr.create_order(999, 7, 3);
        assertEq(mgr.orderCount(), 2, "second order advances 1->2");
        assertEq(uint256(vm.load(address(mgr), orderSlot(2))), expectedPacked(999, 7, 3), "id 2");
        assertEq(
            uint256(vm.load(address(mgr), orderSlot(1))),
            expectedPacked(STRIKE, WIDTH, SKEW),
            "id 1 is not overwritten"
        );

        // The sentinel slot is structurally unwritable: ids start at 1.
        assertEq(uint256(vm.load(address(mgr), orderSlot(0))), 0, "slot keccak(base)+0 is never written");
    }

    /// @notice THE RING-MASK DISCRIMINATOR. A `& 0xFFFF` mask on the id is a NO-OP at ids 1
    ///         and 2 (1 & 0xFFFF == 1, 2 & 0xFFFF == 2), so NO small-id test can observe it --
    ///         it only bites at 65536, where it folds the order onto slot 0. We force the
    ///         counter with vm.store rather than issuing 65536 transactions.
    ///
    ///         THIS IS THE SOLE KILL SITE FOR MUTANT M1 (ring-mask reintroduction). Every
    ///         other test in this file stays GREEN under M1, which is precisely why this test
    ///         had to be written: without it, M1 would be recorded as "killed" while nothing
    ///         actually caught it.
    function test__unit__idAt65536IsNotMaskedIntoSlotZero() public {
        vm.store(address(mgr), SLOT_ORDER_COUNT, bytes32(uint256(65535)));
        mgr.create_order(STRIKE, WIDTH, SKEW);
        assertEq(mgr.orderCount(), 65536, "id 65536 assigned");
        assertEq(
            uint256(vm.load(address(mgr), orderSlot(65536))),
            expectedPacked(STRIKE, WIDTH, SKEW),
            "order 65536 stored at the UNMASKED slot keccak(base)+65536"
        );
        assertEq(
            uint256(vm.load(address(mgr), orderSlot(0))),
            0,
            "slot 0 stays zero -- a 16-bit mask would have folded 65536 onto it"
        );
    }

    /// @notice Corpus CONSTRUCTED with `bound` only -- never vm.assume -- and bounded to the
    ///         MEASURED accept sets (16-01), so every draw is VALID and MUST store. A draw that
    ///         reverts is a real disagreement between this module and the Phase-16 lib.
    ///         Non-fuzz anchor: test__unit__sequentialIdsOneThenTwo above.
    /// forge-config: default.fuzz.runs = 256
    function test__fuzz__validTupleStoresExactPackedWord(uint256 rs, uint256 rw, uint256 rk) public {
        uint88 s = uint88(bound(rs, 1, uint256(type(uint88).max)));
        uint24 w = uint24(bound(rw, 1, uint256(type(uint24).max)));
        uint16 k = uint16(bound(rk, 1, 65534));

        mgr.create_order(s, w, k);
        assertEq(mgr.orderCount(), 1, "every in-range tuple is accepted");
        assertEq(
            uint256(vm.load(address(mgr), orderSlot(1))),
            expectedPacked(s, w, k),
            "fuzz: exact packed word"
        );
    }
}

/// @title VolOrderManagerGuardTest
/// @notice VORD-03: an invalid tuple REVERTS and leaves the registry byte-identical. Every
///         assertion is ON STATE -- orderCount and the raw slots -- never on return data.
contract VolOrderManagerGuardTest is VolOrderManagerBase {
    /// @notice The tuple fails EXACTLY ONE conjunct so the test NAMES which guard fired:
    ///         skew = 65535 is rejected by spread_tick_assimetry_is_complete (accept set
    ///         [1, 65534]) while STRIKE and WIDTH are both comfortably valid.
    ///         skew 0 and 65535 are the ONLY two rejected skews -- 1 and 65534 ACCEPT (16-01
    ///         MEASURED) -- so this is a genuine single-conjunct failure, not a compound one.
    function test__unit__invalidSkewRevertsAndLeavesStateUntouched() public {
        vm.expectRevert();
        mgr.create_order(STRIKE, WIDTH, 65535);

        // ON STATE, never on return data: a silent zero-write and a revert are
        // indistinguishable from the return value.
        assertEq(mgr.orderCount(), 0, "orderCount must not advance on an invalid tuple");
        assertEq(uint256(vm.load(address(mgr), orderSlot(1))), 0, "no order slot is written");
        assertEq(uint256(vm.load(address(mgr), orderSlot(0))), 0, "sentinel slot untouched");
        assertEq(uint256(vm.load(address(mgr), SLOT_ORDER_COUNT)), 0, "raw counter slot untouched");
    }

    /// @notice A failure leaves NO GAP in the id sequence (VORD-03): the surviving order keeps
    ///         id 1, the counter stays at 1, and the id the failed call would have taken stays
    ///         empty -- so the next successful order gets id 2, not id 3.
    function test__unit__invalidSkewAfterAValidOrderDoesNotDisturbIt() public {
        mgr.create_order(STRIKE, WIDTH, SKEW);
        assertEq(mgr.orderCount(), 1, "precondition: one live order");

        vm.expectRevert();
        mgr.create_order(STRIKE, WIDTH, 0); // skew 0: the other rejected endpoint

        assertEq(mgr.orderCount(), 1, "counter did not advance past the surviving order");
        assertEq(
            uint256(vm.load(address(mgr), orderSlot(1))),
            expectedPacked(STRIKE, WIDTH, SKEW),
            "the pre-existing order is untouched"
        );
        assertEq(uint256(vm.load(address(mgr), orderSlot(2))), 0, "no gap: id 2 is still free");
    }
}

/// @title VolOrderManagerReaderTest
/// @notice VORD-05: both reader branches are CALLED, and each is bound to the module's ACTUAL
///         storage by comparing against a raw vm.load at the same address.
contract VolOrderManagerReaderTest is VolOrderManagerBase {
    function test__unit__readersReturnStoredValues() public {
        mgr.create_order(STRIKE, WIDTH, SKEW);
        mgr.create_order(999, 7, 3);

        assertEq(
            mgr.getOrderPacked(1),
            uint256(vm.load(address(mgr), orderSlot(1))),
            "getOrderPacked(1) == raw slot"
        );
        assertEq(
            mgr.getOrderPacked(2),
            uint256(vm.load(address(mgr), orderSlot(2))),
            "getOrderPacked(2) == raw slot"
        );
        assertEq(
            mgr.orderCount(),
            uint256(vm.load(address(mgr), SLOT_ORDER_COUNT)),
            "orderCount() == raw counter slot"
        );

        // And the values are the real tuples, not merely self-consistent zeros.
        assertEq(mgr.getOrderPacked(1), expectedPacked(STRIKE, WIDTH, SKEW), "order 1 tuple");
        assertEq(mgr.getOrderPacked(2), expectedPacked(999, 7, 3), "order 2 tuple");
    }

    /// @notice The 0-sentinel: getOrderPacked on a nonexistent id RETURNS ZERO and does NOT
    ///         revert. Deliberately no vm.expectRevert anywhere in this test -- the calls must
    ///         SUCCEED. Soundness: a valid order has strike > 0 and skew > 0 at nonzero bit
    ///         positions, so a validly packed word is never 0; therefore packed == 0 is an
    ///         unambiguous "nonexistent".
    ///
    ///         MEASURED at 17-01, and the reason MAX_SAFE_ID below is not type(uint256).max:
    ///         v3::storage::array_slot is `keccak256(base) + index` under Plank's CHECKED add,
    ///         so the sum reverts (panic 0x11) rather than wrapping. See
    ///         test__unit__getOrderPackedOverflowBoundaryIsExactlyWhereCheckedAddSaturates.
    function test__unit__getOrderPackedNonexistentReturnsZeroWithoutReverting() public {
        assertEq(mgr.getOrderPacked(0), 0, "id 0 never exists");
        assertEq(mgr.getOrderPacked(1), 0, "fresh registry: id 1 does not exist yet");
        assertEq(mgr.getOrderPacked(MAX_SAFE_ID), 0, "the largest addressable id reads zero, not a revert");
        assertEq(mgr.getOrderPacked(1 << 128), 0, "an absurd but addressable id reads zero, not a revert");

        mgr.create_order(STRIKE, WIDTH, SKEW);
        assertTrue(mgr.getOrderPacked(1) != 0, "id 1 now exists and its word is nonzero");
        assertEq(mgr.getOrderPacked(2), 0, "id 2 still does not exist");
        assertEq(mgr.getOrderPacked(0), 0, "the sentinel slot stays zero after a write");
    }

    /// @notice MEASURED AT 17-01 -- a real property of the deployed module, discovered when the
    ///         plan's `getOrderPacked(type(uint256).max) == 0` assertion FAILED with
    ///         `panic: arithmetic underflow or overflow (0x11)`.
    ///
    ///         CAUSE: `v3::storage::array_slot(base, index)` is `keccak256(base) + index`, and
    ///         Plank's `+` is CHECKED -- it emits the Solidity 0x11 panic instead of wrapping.
    ///         So the addressable id space is [0, 2^256-1 - keccak(base)], and ids above that
    ///         REVERT rather than returning the 0 sentinel.
    ///
    ///         WHY THIS IS NOT A DEFECT AND WAS NOT "FIXED": array_slot belongs to the
    ///         plankified-univ3 track and must not be modified, and masking the id module-side
    ///         is exactly the ring-mask corruption M1 exists to forbid. The unreachable region
    ///         is the top ~0.56% of the id space, starting at ~6.5e74; ids are assigned by a
    ///         +1-per-transaction counter, so NO id in this universe reaches it -- the same
    ///         compile-time-value argument that licenses the >2^64 slot-distance claim.
    ///         VORD-05's "no revert path for a nonexistent id" therefore holds for every
    ///         REACHABLE id, which is the property it exists to establish.
    ///
    ///         This test PINS the boundary as a VALUE so that if array_slot ever switches to an
    ///         unchecked add (or the preimage changes), the change is caught rather than
    ///         silently altering the module's revert surface. Phase 18a/19 and the rpc_api
    ///         consumer inherit this bound.
    function test__unit__getOrderPackedOverflowBoundaryIsExactlyWhereCheckedAddSaturates() public {
        // Exactly at the boundary: keccak(base) + MAX_SAFE_ID == 2^256-1, the last sum that fits.
        assertEq(
            uint256(keccak256(abi.encode(SLOT_ORDERS_BASE))) + MAX_SAFE_ID,
            type(uint256).max,
            "MAX_SAFE_ID is the largest index whose derived slot does not overflow"
        );
        assertEq(mgr.getOrderPacked(MAX_SAFE_ID), 0, "the boundary id itself returns the 0 sentinel");

        // One past it: the checked add in array_slot saturates and the call reverts.
        (bool ok,) = address(mgr).call(
            abi.encodeWithSelector(IVolOrderManager.getOrderPacked.selector, MAX_SAFE_ID + 1)
        );
        assertFalse(ok, "one past the boundary, array_slot's CHECKED add reverts (panic 0x11)");

        // The unreachable region is astronomically far above any counter-assigned id.
        assertGt(MAX_SAFE_ID, 1 << 128, "the boundary is far beyond any id a +1 counter can reach");
    }
}

/// @title VolOrderManagerBoundaryTest
/// @notice Pins the 17 <-> 18a phase boundary: create_orders is DECLARED in the interface but
///         NOT dispatched here, so it must fall through to revert_empty().
contract VolOrderManagerBoundaryTest is VolOrderManagerBase {
    function test__unit__batchSelectorNotYetDispatched() public {
        (bool ok,) = address(mgr).call(
            abi.encodeWithSelector(bytes4(0x81357911), uint256(0), new uint256[](0))
        );
        assertFalse(ok, "create_orders is DECLARED in the interface but not dispatched until Phase 18a");
        assertEq(mgr.orderCount(), 0, "an undispatched selector touches no state");
    }
}

/// @title VolOrderManagerConformanceTest
/// @notice VORD-04. Two compile-time-value properties, both asserted on VALUES rather than
///         argued probabilistically. These are `pure` -- no deploy, so no wasted FFI compile.
contract VolOrderManagerConformanceTest is Test {
    /// @notice Every selector constant equals keccak(its documented signature string)[:4].
    ///         The strings here are byte-identical to the `// signature::` comments in
    ///         src/interfaces/pos_spec/VolOrderManagerInterface.plk. Both entrypoints are
    ///         pinned HERE -- the batch is declared in Phase 17 and implemented in Phase 18a,
    ///         which is what breaks the 17<->18a circular dependency.
    ///
    ///         If an assertion here fails, the CONSTANT is wrong -- never the string.
    function test__unit__selectorsMatchTheirSignatureStrings() public pure {
        assertEq(
            bytes4(keccak256(bytes("create_order(uint88,uint24,uint16)"))), bytes4(0x6501fe94), "create_order"
        );
        assertEq(
            bytes4(keccak256(bytes("create_orders(uint256,uint256[])"))),
            bytes4(0x81357911),
            "create_orders (Phase 18a)"
        );
        assertEq(bytes4(keccak256(bytes("orderCount()"))), bytes4(0x2453ffa8), "orderCount");
        assertEq(bytes4(keccak256(bytes("getOrderPacked(uint256)"))), bytes4(0xa9bcabc1), "getOrderPacked");
    }

    /// @notice |S - keccak(SLOT_ORDERS_BASE)| > 2^64 for every scalar slot S in the module.
    ///         Orders occupy keccak(base) + id, so an order could only reach the scalar slot
    ///         after more than 2^64 orders -- unreachable, and asserted as a NUMBER, not a
    ///         birthday-bound argument. The module has exactly ONE scalar slot; if a future
    ///         phase adds another, it is added to this test.
    ///
    ///         LIMITATION, stated so it is not over-read: this test asserts the real
    ///         preimage-derived constants, so it stays GREEN under mutant M3 (which edits the
    ///         module's constant to alias the orders region). It DOCUMENTS the invariant;
    ///         test__unit__sequentialIdsOneThenTwo is what proves a violation is OBSERVABLE.
    function test__unit__scalarSlotFarFromOrdersRegion() public pure {
        uint256 region = uint256(keccak256(abi.encode(keccak256(bytes("VolOrderManagerMod.orders")))));
        uint256 s = uint256(keccak256(bytes("VolOrderManagerMod.orderCount")));
        uint256 d = s > region ? s - region : region - s;
        assertGt(d, 1 << 64, "orderCount slot must be > 2^64 from the orders region base");
        assertTrue(s != region, "scalar slot is not the region base itself");
    }

    /// @notice The two slot constants hardcoded in the module are exactly the keccaks of their
    ///         documented preimage strings. Pins the module's literals against drift the same
    ///         way the selector test pins the interface's.
    function test__unit__slotConstantsMatchTheirPreimages() public pure {
        assertEq(
            keccak256(bytes("VolOrderManagerMod.orderCount")),
            bytes32(0x92967cb44e7866428adae18aad4bf59a10fb8d4c189b2b0e8bfe6f2a2469b5c7),
            "SLOT_ORDER_COUNT"
        );
        assertEq(
            keccak256(bytes("VolOrderManagerMod.orders")),
            bytes32(0x68fef5d6c1ef01f93bf897a4ffcaa37fbdc39061144008f6edd91f64b7b199cb),
            "SLOT_ORDERS_BASE"
        );
    }
}
