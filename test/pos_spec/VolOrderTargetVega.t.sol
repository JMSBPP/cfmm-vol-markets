// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";
import {Vm} from "forge-std/Vm.sol";

// ===========================================================================================
// V2-01/02 ACCEPTANCE: targetVega (DeltaQ_v*) as a first-class VolOrder field.
// Spec: .planning/vol-order-v2-target-vega-SPEC.md (v2, two-step-reviewed).
// Units: vol-order-v2-target-vega-SPEC.md v2 -- DeltaQ_v* is RAW LIQUIDITY units (dimension (ii)),
// packed u96 at STORAGE bits 152..247; the BATCH input word carries it at bits 128..223
// (offsets differ because build_vol_order inserts TICK_SPACING at 104 in storage).
//
// ABI v2: create_order(uint88 strike, uint24 width, uint16 skew, uint96 targetVega),
// selector 0x98d950ec. The v1 3-arg selector is RETIRED (never deployed).
//
// MUTANTS this file kills:
//   - targetVega packed at a colliding offset (128/151-ish overlapping WIDTH)
//       -> the field-exactness asserts (width and targetVega both roundtrip)
//   - mask-not-revert on the range bound (the silent-mask defect class)
//       -> test__unit__dirtyTargetVegaWordReverts / batch skip test
//   - zero targetVega accepted -> test__unit__zeroTargetVegaReverts
//   - batch top-field stance broken (dirty bits >= 224 stored)
//       -> test__unit__batchDirtyHighBitsSkips + the malleability pair test
//   - E1 v2 signature drift -> solc-oracle expectEmit + topic0 constant assert
// ===========================================================================================
interface IVolOrderManagerV2 {
    function create_order(uint88 strike, uint24 width, uint16 skew, uint96 targetVega) external;
    function orderCount() external view returns (uint256);
    function getOrderPacked(uint256 id) external view returns (uint256);
}

contract VolOrderTargetVegaTest is PlankTestBase {
    event VolOrderCreated(uint256 indexed orderId, uint88 strike, uint24 width, uint16 skew, uint96 targetVega);

    /// @dev cast keccak "VolOrderCreated(uint256,uint88,uint24,uint16,uint96)"
    bytes32 internal constant TOPIC0_VOL_ORDER_CREATED_V2 =
        0x18bd4d460f8957f6b903aec33a3229ee1bf02b6e303c5178c5aa49a70b9de4e6;

    bytes4 internal constant SEL_CREATE_ORDERS = bytes4(0x81357911); // unchanged selector, v2 word semantics

    uint88 internal constant STRIKE = 12345;
    uint24 internal constant WIDTH = 600;
    uint16 internal constant SKEW = 77;
    uint96 internal constant TARGET_VEGA = 1e18; // 1 whole unit of pool liquidity, raw
    uint256 internal constant TICK_SPACING = 20; // pinned by the validation lib

    IVolOrderManagerV2 internal mgr;

    function setUp() public {
        mgr = IVolOrderManagerV2(deployPlank("src/modules/pos_spec/VolOrderManagerMod.plk"));
    }

    /// @dev The v2 STORAGE layout (fields at bit offsets): skew at 0 (u16), strike at 16
    ///      (u88), tickSpacing at 104 (u24), width at 128 (u24), targetVega at 152 (u96).
    function expectedPackedV2(uint256 strike, uint256 width, uint256 skew, uint256 targetVega)
        internal
        pure
        returns (uint256)
    {
        return skew | (strike << 16) | (TICK_SPACING << 104) | (width << 128) | (targetVega << 152);
    }

    /// @dev The v2 BATCH input word: skew at 0, strike at 16, width at 104, targetVega at 128.
    function packInputV2(uint256 strike, uint256 width, uint256 skew, uint256 targetVega)
        internal
        pure
        returns (uint256)
    {
        return skew | (strike << 16) | (width << 104) | (targetVega << 128);
    }

    function _batch(uint256[] memory words) internal returns (bool ok, bytes memory ret) {
        (ok, ret) = address(mgr).call(abi.encodeWithSelector(SEL_CREATE_ORDERS, words.length, words));
    }

    // ------------------------------------------------------------------ storage layout

    function test__unit__createOrderStoresTargetVegaAt152() public {
        mgr.create_order(STRIKE, WIDTH, SKEW, TARGET_VEGA);
        uint256 w = mgr.getOrderPacked(1);
        assertEq(w, expectedPackedV2(STRIKE, WIDTH, SKEW, TARGET_VEGA), "exact v2 packed word");
        assertEq(w >> 152, TARGET_VEGA, "targetVega@152 is the top field");
        assertEq((w >> 128) & 0xFFFFFF, WIDTH, "width@128 intact (no offset collision)");
        assertEq((w >> 104) & 0xFFFFFF, TICK_SPACING, "tickSpacing@104 intact");
        assertEq((w >> 16) & 0xFFFFFFFFFFFFFFFFFFFFFF, STRIKE, "strike@16 intact");
        assertEq(w & 0xFFFF, SKEW, "skew@0 intact");
    }

    // Mask-identity (units-table rule 2, executable form): over accepted inputs the stored
    // word reproduces every submitted field exactly -- a mask that changed an accepted value
    // would fail field-exactness here.
    // forge-config: default.fuzz.runs = 256
    function test__fuzz__acceptedOrdersRoundTripExactly(uint88 s, uint24 w, uint16 k, uint96 tv) public {
        uint88 strike = uint88(bound(uint256(s), 1, type(uint88).max));
        uint24 width = uint24(bound(uint256(w), 1, type(uint24).max));
        uint16 skew = uint16(bound(uint256(k), 1, 65534));
        uint96 tv_ = uint96(bound(uint256(tv), 1, type(uint96).max));
        mgr.create_order(strike, width, skew, tv_);
        assertEq(mgr.getOrderPacked(1), expectedPackedV2(strike, width, skew, tv_), "roundtrip exact");
    }

    // ------------------------------------------------------------------ validation

    function test__unit__zeroTargetVegaReverts() public {
        vm.expectRevert();
        mgr.create_order(STRIKE, WIDTH, SKEW, 0);
        assertEq(mgr.orderCount(), 0, "no state change");
    }

    // The strict path loads the 4th word RAW; a word with dirty bits above uint96 (which the
    // typed ABI cannot express -- hence the raw call) must REVERT via the range predicate,
    // never be silently masked into a different stored value.
    function test__unit__dirtyTargetVegaWordReverts() public {
        bytes memory cd = abi.encodeWithSelector(
            IVolOrderManagerV2.create_order.selector,
            uint256(STRIKE),
            uint256(WIDTH),
            uint256(SKEW),
            (uint256(1) << 96) | uint256(TARGET_VEGA) // dirty bit 96
        );
        (bool ok,) = address(mgr).call(cd);
        assertFalse(ok, "dirty targetVega word reverts (strict)");
        assertEq(mgr.orderCount(), 0, "no state change");
    }

    // ------------------------------------------------------------------ batch semantics

    function test__unit__batchStoresTargetVega() public {
        uint256[] memory words = new uint256[](2);
        words[0] = packInputV2(STRIKE, WIDTH, SKEW, TARGET_VEGA);
        words[1] = packInputV2(999, 7, 3, 5e17);
        (bool ok,) = _batch(words);
        assertTrue(ok, "batch succeeds");
        assertEq(mgr.getOrderPacked(1), expectedPackedV2(STRIKE, WIDTH, SKEW, TARGET_VEGA), "batch word 0");
        assertEq(mgr.getOrderPacked(2), expectedPackedV2(999, 7, 3, 5e17), "batch word 1");
    }

    // targetVega is the batch word's TOP field (bits 128..223): dirty bits >= 224 make the
    // loaded top field exceed u96 -> the tuple SKIPS (false, 0), storing nothing.
    function test__unit__batchDirtyHighBitsSkips() public {
        uint256[] memory words = new uint256[](2);
        words[0] = packInputV2(STRIKE, WIDTH, SKEW, TARGET_VEGA) | (uint256(1) << 224); // dirty
        words[1] = packInputV2(999, 7, 3, 5e17); // clean -- must still land at id 1
        (bool ok, bytes memory ret) = _batch(words);
        assertTrue(ok, "batch call itself succeeds");
        (bool s0, uint256 id0, bool s1, uint256 id1) = _twoResults(ret);
        assertFalse(s0, "dirty tuple skipped");
        assertEq(id0, 0, "skipped tuple reports id 0");
        assertTrue(s1, "clean successor stored");
        assertEq(id1, 1, "successor takes the first id (unshifted accounting)");
        assertEq(mgr.orderCount(), 1, "exactly one order stored");
    }

    // THE MALLEABILITY PAIR (units-table rule 2 / spec D3): two words differing ONLY above
    // bit 223 must not BOTH store -- the dirty one is rejected, so no two distinct calldata
    // words alias one stored order.
    function test__unit__batchMalleabilityPairRejected() public {
        uint256 clean = packInputV2(STRIKE, WIDTH, SKEW, TARGET_VEGA);
        uint256[] memory words = new uint256[](2);
        words[0] = clean;
        words[1] = clean | (uint256(0xdead) << 224);
        (bool ok, bytes memory ret) = _batch(words);
        assertTrue(ok, "batch succeeds");
        (bool s0,, bool s1,) = _twoResults(ret);
        assertTrue(s0, "clean word stores");
        assertFalse(s1, "its dirty twin is REJECTED, not aliased");
        assertEq(mgr.orderCount(), 1, "one order, not two");
    }

    function test__unit__batchZeroTargetVegaSkips() public {
        uint256[] memory words = new uint256[](1);
        words[0] = packInputV2(STRIKE, WIDTH, SKEW, 0);
        (bool ok, bytes memory ret) = _batch(words);
        assertTrue(ok, "batch succeeds");
        (bool s0,,,) = _oneResultPad(ret);
        assertFalse(s0, "zero targetVega skips");
        assertEq(mgr.orderCount(), 0, "nothing stored");
    }

    // ------------------------------------------------------------------ E1 v2 event

    function test__unit__topicZeroMatchesSolc() public pure {
        assertEq(VolOrderCreated.selector, TOPIC0_VOL_ORDER_CREATED_V2, "pinned constant == solc canonical");
    }

    function test__unit__createOrderEmitsV2Event() public {
        vm.expectEmit(true, true, true, true, address(mgr));
        emit VolOrderCreated(1, STRIKE, WIDTH, SKEW, TARGET_VEGA);
        mgr.create_order(STRIKE, WIDTH, SKEW, TARGET_VEGA);
    }

    // ------------------------------------------------------------------ decode helpers

    function _twoResults(bytes memory ret) internal pure returns (bool s0, uint256 id0, bool s1, uint256 id1) {
        (uint256 off, uint256 len, uint256 a, uint256 b, uint256 c, uint256 d) =
            abi.decode(bytes.concat(ret, new bytes(0)), (uint256, uint256, uint256, uint256, uint256, uint256));
        require(off == 0x20 && len == 2, "shape");
        s0 = a == 1;
        id0 = b;
        s1 = c == 1;
        id1 = d;
    }

    function _oneResultPad(bytes memory ret) internal pure returns (bool s0, uint256 id0, bool, uint256) {
        (uint256 off, uint256 len, uint256 a, uint256 b) =
            abi.decode(ret, (uint256, uint256, uint256, uint256));
        require(off == 0x20 && len == 1, "shape");
        s0 = a == 1;
        id0 = b;
    }
}
