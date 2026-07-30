// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";

// CR-I2 Layer 2, Increment 1: geometric_cumulative_density_x96(m, iota, xi) = (1 - xi^m)/(1 - xi^iota)
// in Q96. Oracle = the existing Bunni-diff-tested per-column density geometric_liquidity_density_x96:
// the increment cum(m+1) - cum(m) equals the per-column weight at column m. Endpoints exact:
// cum(0)=0, cum(iota)=Q96. No rpow/TickMath re-implementation needed.
contract GeometricWeightsTest is PlankTestBase {
    address internal harness;
    uint256 constant Q96 = 0x1000000000000000000000000;

    function setUp() public {
        harness = deployPlank("test/lib/ldf/GeometricWeightsHarness.plk");
    }

    function _cum(uint256 m, uint256 iota, uint256 xi) internal returns (uint256) {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("cumDensity(uint256,uint256,uint256)", m, iota, xi));
        require(ok, "cumDensity reverted");
        return abi.decode(r, (uint256));
    }

    function _rpow(uint256 x, uint256 n) internal returns (uint256) {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("rpow_(uint256,uint256)", x, n));
        require(ok, "rpow_ reverted");
        return abi.decode(r, (uint256));
    }

    function _xiStar(int24 delta) internal returns (uint256) {
        (bool ok, bytes memory r) = harness.staticcall(abi.encodeWithSignature("xiStar(int24)", delta));
        require(ok, "xiStar reverted");
        return abi.decode(r, (uint256));
    }

    // exact endpoints: cum(0) = 0, cum(iota) = Q96
    function test_cum_endpoints() public {
        int24 ts = 10;
        uint256 xi = _xiStar(ts);
        uint256 iota = 100;
        assertEq(_cum(0, iota, xi), 0, "cum(0) == 0");
        assertEq(_cum(iota, iota, xi), Q96, "cum(iota) == Q96");
    }

    // monotone increasing and bounded in [0, Q96]
    function test_cum_monotone_bounded() public {
        int24 ts = 10;
        uint256 xi = _xiStar(ts);
        uint256 iota = 50;
        uint256 prev = 0;
        for (uint256 m = 0; m <= iota; m++) {
            uint256 c = _cum(m, iota, xi);
            assertLe(c, Q96, "cum <= Q96");
            assertGe(c, prev, "cum monotone non-decreasing");
            prev = c;
        }
    }

    // EXACT differential: cum(m,iota,xi) == (Q96 - xi^m)*Q96 / (Q96 - xi^iota), recomputed with the
    // SAME rpow the primitive uses. (Q96 - xi^m)*Q96 < 2^192 < 2^256, so plain u256 mul/div == mulDiv
    // (floor) exactly -- no tolerance. Verifies the primitive composes rpow + mulDiv correctly.
    function testFuzz_cum_exact_closedForm(uint256 mR, uint256 iotaR, int256 tsR) public {
        int24 ts = int24(bound(tsR, 1, 200));
        uint256 iota = bound(iotaR, 1, 500);
        uint256 m = bound(mR, 0, iota);
        uint256 xi = _xiStar(ts);

        uint256 den = Q96 - _rpow(xi, iota);
        uint256 expected = ((Q96 - _rpow(xi, m)) * Q96) / den;
        assertEq(_cum(m, iota, xi), expected, "cum == (1-xi^m)/(1-xi^iota) exactly");
    }

    // ---- Increment 2: geometric_leg_weights ----

    function _legWeights(int24 i_l, int24 i_u, int24 delta, int24 iStar)
        internal
        returns (uint256 w0, uint256 w1, uint256 w2, uint256 w3)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature("legWeights(int24,int24,int24,int24)", i_l, i_u, delta, iStar)
        );
        require(ok, "legWeights reverted");
        (w0, w1, w2, w3) = abi.decode(r, (uint256, uint256, uint256, uint256));
    }

    // sum of the 4 weights is EXACTLY Q96 (shared endpoints telescope: cum(iota)-cum(0)).
    function test_legWeights_sumExact() public {
        (uint256 w0, uint256 w1, uint256 w2, uint256 w3) = _legWeights(-500, 500, 10, 0);
        assertEq(w0 + w1 + w2 + w3, Q96, "sum == Q96 exactly");
    }

    // each weight is a real fraction in [0, Q96] (catches a wrapping-underflow 2^256 leg).
    function test_legWeights_bounds() public {
        (uint256 w0, uint256 w1, uint256 w2, uint256 w3) = _legWeights(-500, 500, 10, 0);
        assertLe(w0, Q96, "w0 <= Q96");
        assertLe(w1, Q96, "w1 <= Q96");
        assertLe(w2, Q96, "w2 <= Q96");
        assertLe(w3, Q96, "w3 <= Q96");
    }

    // Universal invariants over general bucket geometry: exact sum + each weight a real fraction.
    // (Leg-level monotonicity does NOT hold in general -- with xi* near 1 the near-flat per-column
    // weights make a leg's mass dominated by its column count, so an odd-split wider leg can outweigh
    // a narrower earlier one. Monotonicity is asserted only in the equal-width golden case below.)
    function testFuzz_legWeights_invariants(uint256 widthR, int256 starR) public {
        int24 ts = 10;
        int24 half = int24(int256(bound(widthR, 5, 4000))) * ts; // 5..4000 columns per side
        int24 i_l = -half;
        int24 i_u = half;
        int24 iStar = int24(int256(bound(starR, -int256(int24(half)) + 2 * 10, int256(int24(half)) - 2 * 10)));
        iStar = (iStar / ts) * ts; // align

        (uint256 w0, uint256 w1, uint256 w2, uint256 w3) = _legWeights(i_l, i_u, ts, iStar);
        assertEq(w0 + w1 + w2 + w3, Q96, "sum == Q96 exactly");
        assertLe(w0, Q96, "w0 <= Q96");
        assertLe(w1, Q96, "w1 <= Q96");
        assertLe(w2, Q96, "w2 <= Q96");
        assertLe(w3, Q96, "w3 <= Q96");
    }

    // EQUAL-WIDTH golden bucket ([-500,500], i*=0 => all 4 legs are 25 columns). The geometric LDF is
    // monotone-DECREASING across the whole support (mass toward low ticks, GeomProfile.geomWeight_
    // strictAnti), so with equal column counts w0 >= w1 >= w2 >= w3 (NOT symmetric about i*).
    function test_legWeights_goldenMonotone() public {
        (uint256 w0, uint256 w1, uint256 w2, uint256 w3) = _legWeights(-500, 500, 10, 0);
        assertGe(w0, w1, "w0 >= w1");
        assertGe(w1, w2, "w1 >= w2");
        assertGe(w2, w3, "w2 >= w3");
        assertEq(w0 + w1 + w2 + w3, Q96, "sum == Q96 exactly");
    }

    // alignment: the column boundaries the weights use equal Layer 1's ACTUALLY-EMITTED leg boundaries.
    // Recompute each weight from the tokenId's decoded legs via the exact cum() closed form.
    function test_legWeights_alignsWithEmittedLegs() public {
        int24 i_l = -500;
        int24 i_u = 500;
        int24 ts = 10;
        int24 iStar = 0;
        uint256 xi = _xiStar(ts);
        uint256 iota = uint256(int256((i_u - i_l) / ts)); // 100

        (uint256 w0, uint256 w1, uint256 w2, uint256 w3) = _legWeights(i_l, i_u, ts, iStar);

        // split points via the shared helper's rule (round_tick floor of midpoints)
        int24 mP = ((i_l + (iStar - i_l) / 2) / ts) * ts;
        int24 mC = ((iStar + (i_u - iStar) / 2) / ts) * ts;
        uint256 c1 = uint256(int256((mP - i_l) / ts));
        uint256 c2 = uint256(int256((iStar - i_l) / ts));
        uint256 c3 = uint256(int256((mC - i_l) / ts));

        assertEq(w0, _cum(c1, iota, xi), "w0 == cum(c1)");
        assertEq(w1, _cum(c2, iota, xi) - _cum(c1, iota, xi), "w1 == cum(c2)-cum(c1)");
        assertEq(w2, _cum(c3, iota, xi) - _cum(c2, iota, xi), "w2 == cum(c3)-cum(c2)");
        assertEq(w3, Q96 - _cum(c3, iota, xi), "w3 == Q96-cum(c3)");
    }
}
