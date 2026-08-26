// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";

// PanopticVegaLens.vol_option_payoff realizes cfmm-vol-markets-spec lean/vol_markets/Panoptic.lean `volOptionPayoff`:
//   pi^sigma = dQv * max(0, sig2 - sig2K)
// proven there: nonneg (dQv>=0), and deltaQv_of_payoff (the ITM difference quotient in sig2 equals dQv).
contract PanopticVegaLensTest is PlankTestBase {
    // FFI-deployed Plank harness (PanopticVegaLensHarness.plk):
    //   volOptionPayoff(uint256 dQv, uint256 sig2, uint256 sig2K) -> uint256
    address internal harness;

    function setUp() public {
        harness = deployPlank("src/lib/exposure/PanopticVegaLensHarness.plk");
    }

    function _vop(uint256 dQv, uint256 sig2, uint256 sig2K) internal returns (uint256) {
        (bool ok, bytes memory ret) =
            harness.staticcall(abi.encodeWithSignature("volOptionPayoff(uint256,uint256,uint256)", dQv, sig2, sig2K));
        require(ok, "volOptionPayoff reverted");
        return abi.decode(ret, (uint256));
    }

    // payoff == dQv * max(0, sig2 - sig2K)
    function testFuzz_volOptionPayoff_formula(uint256 dQvR, uint256 s2R, uint256 s2kR) public {
        uint256 dQv = bound(dQvR, 0, type(uint128).max);
        uint256 sig2 = bound(s2R, 0, type(uint128).max);
        uint256 sig2K = bound(s2kR, 0, type(uint128).max);
        uint256 diff = sig2 > sig2K ? sig2 - sig2K : 0;
        assertEq(_vop(dQv, sig2, sig2K), dQv * diff, "payoff = dQv * max(0, sig2 - sig2K)");
    }

    // out of the money (sig2 <= sig2K) -> 0
    function testFuzz_volOptionPayoff_otmZero(uint256 dQvR, uint256 s2R, uint256 s2kR) public {
        uint256 dQv = bound(dQvR, 0, type(uint128).max);
        uint256 sig2 = bound(s2R, 0, type(uint128).max);
        uint256 sig2K = bound(s2kR, sig2, type(uint256).max); // sig2K >= sig2 -> OTM
        assertEq(_vop(dQv, sig2, sig2K), 0, "OTM payoff is 0");
    }

    // deltaQv_of_payoff: on the ITM region, (payoff(sig2+d) - payoff(sig2)) / d == dQv
    function testFuzz_volOptionPayoff_deltaQv(uint256 dQvR, uint256 s2R, uint256 s2kR, uint256 dR) public {
        uint256 dQv = bound(dQvR, 0, type(uint120).max);
        uint256 sig2K = bound(s2kR, 0, type(uint120).max);
        uint256 sig2 = bound(s2R, sig2K, type(uint120).max); // sig2K <= sig2 (ITM at both endpoints)
        uint256 d = bound(dR, 1, type(uint120).max);

        uint256 p1 = _vop(dQv, sig2, sig2K);
        uint256 p2 = _vop(dQv, sig2 + d, sig2K);
        assertEq((p2 - p1) / d, dQv, "deltaQv_of_payoff: ITM difference quotient == dQv");
    }

    function test_volOptionPayoff_golden() public {
        // dQv=1e18, sig2=30, sig2K=20 -> 1e18 * 10
        assertEq(_vop(1e18, 30, 20), 1e18 * 10, "golden ITM");
        // OTM: sig2 < sig2K -> 0
        assertEq(_vop(1e18, 10, 20), 0, "golden OTM");
    }
}
