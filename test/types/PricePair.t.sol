// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";
import {TickMath} from "univ4-core/libraries/TickMath.sol";

contract PricePairTest is PlankTestBase {
    // FFI-deployed Plank harness (PricePairHarness.plk):
    //   pricePair(uint256 tickSpacing, uint256 eta, uint256 numbRep, int24 i1, int24 i2)
    //     -> (bytes32 geometry, uint256 p1, uint256 p2)
    address internal harness;

    uint256 constant TICK_SPACING = 60;
    uint256 constant NUMB_REP     = 96;
    uint256 constant Q96          = 1 << 96;

    function setUp() public {
        harness = deployPlank("src/types/PricePairHarness.plk");
    }

    function _pair(uint256 eta, int24 i1, int24 i2)
        internal
        returns (bytes32 g, uint256 p1, uint256 p2)
    {
        (bool ok, bytes memory ret) = harness.staticcall(
            abi.encodeWithSignature(
                "pricePair(uint256,uint256,uint256,int24,int24)", TICK_SPACING, eta, NUMB_REP, i1, i2
            )
        );
        require(ok, "pricePair reverted");
        return abi.decode(ret, (bytes32, uint256, uint256));
    }

    function testFuzz_pricePair(uint256 etaRaw, int256 i1Raw, int256 i2Raw) public {
        uint256 eta = bound(etaRaw, 1, Q96 - 1);                               // η ∈ (0,1) in Q64.96
        int24 i1 = int24(bound(i1Raw, TickMath.MIN_TICK, TickMath.MAX_TICK));
        int24 i2 = int24(bound(i2Raw, TickMath.MIN_TICK, TickMath.MAX_TICK));

        (bytes32 g, uint256 p1, uint256 p2) = _pair(eta, i1, i2);

        // (1) geometry tags the exact frame that produced the points
        assertEq(g, keccak256(abi.encode(TICK_SPACING, eta, NUMB_REP)), "geometry == PriceCoordinateId");

        // (2) each point is the canonical sqrtPrice at its tick (within sqrt ULP, see EtaSplitKernel)
        assertApproxEqRel(p1, uint256(TickMath.getSqrtPriceAtTick(i1)), 1e10, "p1 == price at i1");
        assertApproxEqRel(p2, uint256(TickMath.getSqrtPriceAtTick(i2)), 1e10, "p2 == price at i2");

        // (3) unordered / order-preserving: swapping the input ticks swaps the stored points exactly
        (bytes32 g2, uint256 q1, uint256 q2) = _pair(eta, i2, i1);
        assertEq(g2, g, "geometry unchanged by order");
        assertEq(q1, p2, "swap: q1 == p2");
        assertEq(q2, p1, "swap: q2 == p1");
    }
}
