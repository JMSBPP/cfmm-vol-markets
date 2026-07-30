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
}
