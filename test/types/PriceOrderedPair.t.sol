// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";
import {TickMath} from "univ4-core/libraries/TickMath.sol";

contract PriceOrderedPairTest is PlankTestBase {
    // FFI-deployed Plank harness (PriceOrderedPairHarness.plk):
    //   priceOrderedPair(uint256 tickSpacing, uint256 eta, uint256 numbRep, int24 i1, int24 i2)
    //     -> (bytes32 geometry, uint256 lower, uint256 upper)
    address internal harness;

    uint256 constant TICK_SPACING = 60;
    uint256 constant NUMB_REP     = 96;
    uint256 constant Q96          = 1 << 96;

    function setUp() public {
        harness = deployPlank("test/types/PriceOrderedPairHarness.plk");
    }

    function _op(uint256 eta, int24 i1, int24 i2)
        internal
        returns (bytes32 g, uint256 lower, uint256 upper)
    {
        (bool ok, bytes memory ret) = harness.staticcall(
            abi.encodeWithSignature(
                "priceOrderedPair(uint256,uint256,uint256,int24,int24)", TICK_SPACING, eta, NUMB_REP, i1, i2
            )
        );
        require(ok, "priceOrderedPair reverted");
        return abi.decode(ret, (bytes32, uint256, uint256));
    }

    function testFuzz_priceOrderedPair(uint256 etaRaw, int256 i1Raw, int256 i2Raw) public {
        uint256 eta = bound(etaRaw, 1, Q96 - 1);                               // η ∈ (0,1) in Q64.96
        int24 i1 = int24(bound(i1Raw, TickMath.MIN_TICK, TickMath.MAX_TICK));
        int24 i2 = int24(bound(i2Raw, TickMath.MIN_TICK, TickMath.MAX_TICK));

        int24 iLo = i1 < i2 ? i1 : i2;
        int24 iHi = i1 < i2 ? i2 : i1;

        (bytes32 g, uint256 lower, uint256 upper) = _op(eta, i1, i2);

        // (1) geometry tags the exact frame
        assertEq(g, keccak256(abi.encode(TICK_SPACING, eta, NUMB_REP)), "geometry == PriceCoordinateId");

        // (2) lower/upper are the canonical sqrtPrices at the sorted ticks (within sqrt ULP)
        assertApproxEqRel(lower, uint256(TickMath.getSqrtPriceAtTick(iLo)), 1e10, "lower == price at min tick");
        assertApproxEqRel(upper, uint256(TickMath.getSqrtPriceAtTick(iHi)), 1e10, "upper == price at max tick");

        // (3) order-independence: swapping the inputs yields an identical ordered pair
        (bytes32 g2, uint256 lower2, uint256 upper2) = _op(eta, i2, i1);
        assertEq(g2, g, "geometry unchanged by order");
        assertEq(lower2, lower, "lower unchanged by order");
        assertEq(upper2, upper, "upper unchanged by order");

        // (4) genuinely ordered: canonical monotonic witness lower-tick price <= upper-tick price
        assertLe(
            uint256(TickMath.getSqrtPriceAtTick(iLo)),
            uint256(TickMath.getSqrtPriceAtTick(iHi)),
            "min-tick price <= max-tick price"
        );
    }
}
