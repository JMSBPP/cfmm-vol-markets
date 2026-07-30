// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VolOrderManagerBatchBase} from "../pos_spec/VolOrderManagerBatch.t.sol";
import {Vm} from "forge-std/Vm.sol";

// ===========================================================================================
// EV-02: E1 VolOrderCreated(uint256 indexed orderId, uint88 strike, uint24 width, uint16 skew)
// (.planning/events-subgraph-gams-SPEC.md, D4/E1 + D8).
//
// ORACLE DISCIPLINE (spec D8): the event is DECLARED HERE with the exact spec signature and
// the expectation is produced by `vm.expectEmit` + a solc-compiled `emit` with TYPED values.
// solc's own encoder therefore pins topic0, the indexed topic, the data words and their
// order -- a packing mistake made once in the Plank emit helper cannot be made twice.
// vm.recordLogs appears only as a SUPPLEMENT (emission counting), never as the byte oracle.
//
// E1 has NO poolId topic (spec D2): orders are market-agnostic at creation; the pool join
// arrives with E2 (task #14).
//
// MUTANTS this file kills (spec EV battery):
//   - missing emit on the single-call path        -> test__unit__createOrderEmitsVolOrderCreated
//   - wrong topic0 / signature-string drift       -> test__unit__topicZeroMatchesPinnedConstant
//   - field-order swap in the data section        -> byte-exact expectEmit (checkData = true)
//   - missing emit on the batch path              -> test__unit__batchEmitsPerSuccessOnly
//   - emit for a SKIPPED tuple (emit-before-validate)
//                                                 -> test__unit__batchEmitsPerSuccessOnly
//   - emit on the empty batch                     -> test__unit__emptyBatchEmitsNothing
// ===========================================================================================
contract VolOrderCreatedEventTest is VolOrderManagerBatchBase {
    /// @dev The exact spec signature. solc derives topic0 from THIS declaration.
    event VolOrderCreated(uint256 indexed orderId, uint88 strike, uint24 width, uint16 skew, uint96 targetVega);

    /// @dev Restated from the Plank emit helper (cast keccak
    ///      "VolOrderCreated(uint256,uint88,uint24,uint16,uint96)" -- the V2 signature; the v1
    ///      topic0 0x6a5dc726... is RETIRED-NEVER-LIVE). Asserted against solc's canonical
    ///      hash below so a drifting signature string is caught.
    bytes32 internal constant TOPIC0_VOL_ORDER_CREATED =
        0x18bd4d460f8957f6b903aec33a3229ee1bf02b6e303c5178c5aa49a70b9de4e6;

    uint96 internal constant TV = 1e18; // targetVega anchor, raw L units (V2)

    function test__unit__topicZeroMatchesPinnedConstant() public pure {
        assertEq(
            VolOrderCreated.selector,
            TOPIC0_VOL_ORDER_CREATED,
            "pinned cast-keccak constant == solc's canonical topic0"
        );
    }

    // The single-call path: create_order emits exactly the stored tuple with the assigned id.
    function test__unit__createOrderEmitsVolOrderCreated() public {
        vm.expectEmit(true, true, true, true, address(mgr));
        emit VolOrderCreated(1, STRIKE, WIDTH, SKEW, TV);
        mgr.create_order(STRIKE, WIDTH, SKEW, TV);
    }

    // Ids are sequential and each creation emits with ITS id (kills any emit that re-reads a
    // stale count or emits before the id assignment).
    function test__unit__secondCreateEmitsIdTwo() public {
        mgr.create_order(STRIKE, WIDTH, SKEW, TV);
        vm.expectEmit(true, true, true, true, address(mgr));
        emit VolOrderCreated(2, STRIKE, WIDTH, SKEW, TV);
        mgr.create_order(STRIKE, WIDTH, SKEW, TV);
    }

    // The batch path: per-success emit, a skipped tuple emits NOTHING, successors' events do
    // not shift (positional discipline mirrors the return-tuple discipline).
    function test__unit__batchEmitsPerSuccessOnly() public {
        uint256[] memory words = new uint256[](3);
        words[0] = packInput(STRIKE, WIDTH, SKEW) | (TV << 128);
        words[1] = packInput(STRIKE, WIDTH, 0) | (TV << 128); // skew 0: rejected -> SKIP, no event
        words[2] = packInput(STRIKE, WIDTH, SKEW) | (TV << 128);

        vm.expectEmit(true, true, true, true, address(mgr));
        emit VolOrderCreated(1, STRIKE, WIDTH, SKEW, TV);
        vm.expectEmit(true, true, true, true, address(mgr));
        emit VolOrderCreated(2, STRIKE, WIDTH, SKEW, TV);

        vm.recordLogs();
        (bool ok,) = callBatch(encodeBatch(words));
        assertTrue(ok, "mixed batch call succeeds");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 2, "exactly one event per SUCCESSFUL tuple, none for the skip");
        assertEq(logs[0].topics[0], TOPIC0_VOL_ORDER_CREATED, "log 0 is VolOrderCreated");
        assertEq(logs[1].topics[0], TOPIC0_VOL_ORDER_CREATED, "log 1 is VolOrderCreated");
        assertEq(uint256(logs[0].topics[1]), 1, "first success carries id 1");
        assertEq(uint256(logs[1].topics[1]), 2, "second success carries id 2 (unshifted by the skip)");
    }

    // N=0: a well-formed empty batch is a no-op in logs exactly as it is in state.
    function test__unit__emptyBatchEmitsNothing() public {
        uint256[] memory words = new uint256[](0);
        vm.recordLogs();
        (bool ok,) = callBatch(encodeBatch(words));
        assertTrue(ok, "empty batch call succeeds");
        assertEq(vm.getRecordedLogs().length, 0, "empty batch emits nothing");
    }

    // All-invalid batch: state does not advance and neither does the log stream.
    function test__unit__allInvalidBatchEmitsNothing() public {
        uint256[] memory words = new uint256[](2);
        words[0] = packInput(STRIKE, WIDTH, 0) | (TV << 128);
        words[1] = packInput(STRIKE, WIDTH, 65535) | (TV << 128); // the other rejected skew endpoint
        vm.recordLogs();
        (bool ok,) = callBatch(encodeBatch(words));
        assertTrue(ok, "all-invalid batch call succeeds (skips, no revert)");
        assertEq(vm.getRecordedLogs().length, 0, "no event for any skipped tuple");
        assertEq(mgr.orderCount(), 0, "state did not advance either");
    }
}
