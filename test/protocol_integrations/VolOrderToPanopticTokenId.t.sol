// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";

// CR-I2 Layer 1, Increment 1: the floor-strike leg encoder panoptic_add_leg_from_bucket must produce
// a (strike,width) pair that Panoptic's getTicks reconstructs to EXACTLY the sub-bucket [lo,hi],
// tickSpacing-aligned, for ANY sign/parity. The negative-odd case is the one that distinguishes
// floor-strike (correct) from sdiv(low+up,2) truncation-toward-zero (off by +1, off-grid).
contract VolOrderToPanopticTokenIdTest is PlankTestBase {
    // FFI-deployed Plank harness (VolOrderToPanopticTokenIdHarness.plk):
    //   legFromBucket(int24 lo,int24 hi,int24 ts,uint256 leg) -> (int256 strike, uint256 width)
    address internal harness;

    int24 constant I24_MIN = -8388608;
    int24 constant I24_MAX = 8388607;

    function setUp() public {
        harness = deployPlank("test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk");
    }

    function _legFromBucket(int24 lo, int24 hi, int24 ts, uint256 leg)
        internal
        returns (int24 strike, uint256 width)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature("legFromBucket(int24,int24,int24,uint256)", lo, hi, ts, leg)
        );
        require(ok, "legFromBucket reverted");
        (int256 s, uint256 w) = abi.decode(r, (int256, uint256));
        strike = int24(s);
        width = w;
    }

    // Panoptic reconstruction: getRangesFromStrike (rangeDown=floor(w*ts/2), rangeUp=ceil) + getTicks.
    function _reconstruct(int24 strike, uint256 width, int24 ts)
        internal
        pure
        returns (int24 tickLower, int24 tickUpper)
    {
        int256 span = int256(width) * int256(ts); // = hi - lo, always > 0
        int256 rangeDown = span / 2; // floor (span > 0)
        int256 rangeUp = span - rangeDown; // ceil
        tickLower = int24(int256(strike) - rangeDown);
        tickUpper = int24(int256(strike) + rangeUp);
    }

    function _assertReconstructs(int24 lo, int24 hi, int24 ts) internal {
        (int24 strike, uint256 width) = _legFromBucket(lo, hi, ts, 0);
        (int24 tl, int24 tu) = _reconstruct(strike, width, ts);
        assertEq(tl, lo, "tickLower == lo");
        assertEq(tu, hi, "tickUpper == hi");
        assertEq(tl % ts, 0, "tickLower tickSpacing-aligned");
        assertEq(tu % ts, 0, "tickUpper tickSpacing-aligned");
    }

    // even span: strike is aligned, textbook case
    function test_legFromBucket_positiveEven() public {
        _assertReconstructs(100, 200, 10);
    }

    // ODD span: strike lands half-a-tickSpacing off-grid, but the reconstructed TICKS are aligned
    function test_legFromBucket_positiveOdd() public {
        _assertReconstructs(100, 130, 10);
    }

    // load-bearing: NEGATIVE odd span. sdiv(low+up,2) truncates toward zero -> strike off by +1 ->
    // reconstructs [-124,-100] (off-grid). floor-strike -> [-125,-100]. This test fails for sdiv.
    function test_legFromBucket_negativeOdd() public {
        _assertReconstructs(-125, -100, 5);
    }

    // any aligned bucket (incl. negatives) reconstructs exactly
    function testFuzz_legFromBucket_reconstructs(int256 loR, uint256 wR, int256 tsR) public {
        int24 ts = int24(bound(tsR, 1, 200));
        int256 tsI = int256(ts);
        uint256 w = bound(wR, 1, 4095);
        int256 lo = bound(loR, I24_MIN / 2, I24_MAX / 2);
        lo = lo - (lo % tsI); // align to tickSpacing (rounds toward zero)
        int256 hi = lo + int256(w) * tsI;
        vm.assume(hi <= I24_MAX);
        _assertReconstructs(int24(lo), int24(hi), ts);
    }
}
